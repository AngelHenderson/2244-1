import * as functions from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

// Initialize Firestore
const db = getFirestore();

// Composite score calculation constants
const BASE_SCORE = 1_000_000;
const BASE_MOVES = 1_000;
const BASE_TIME = 10_000;
const FACTOR = BigInt(BASE_SCORE) * BigInt(BASE_MOVES) * BigInt(BASE_TIME); // 10^13

/**
 * Encodes a composite score that prioritizes:
 * 1. Highest tile achieved (exponential weight)
 * 2. Speed (less time is better) 
 * 3. Efficiency (fewer moves is better)
 * 4. Raw score (tie-breaker)
 */
function encodeComposite(
  highestTile: number,
  seconds: number,
  moves: number,
  runScore: number
): bigint {
  const p = BigInt(Math.max(2, Math.floor(Math.log2(Math.max(2, highestTile)))));
  const t = BigInt(Math.max(0, Math.min(BASE_TIME - seconds, BASE_TIME)));
  const m = BigInt(Math.max(0, Math.min(BASE_MOVES - moves, BASE_MOVES)));
  const rs = BigInt(Math.max(0, Math.min(runScore, BASE_SCORE - 1)));
  
  return p * FACTOR + t * BigInt(1_000_000_000) + m * BigInt(1_000_000) + rs;
}

/**
 * Validates that the submitted score is reasonable
 * This is a basic validation - you can add more sophisticated checks
 */
function validateScore(data: {
  highestTile: number;
  secondsToHighest: number;
  movesToHighest: number;
  runScore: number;
}): boolean {
  const { highestTile, secondsToHighest, movesToHighest, runScore } = data;
  
  // Basic sanity checks
  if (highestTile < 4 || highestTile > 131072) return false; // 2^2 to 2^17
  if (secondsToHighest < 0 || secondsToHighest > 86400) return false; // 0 to 24 hours
  if (movesToHighest < 0 || movesToHighest > 10000) return false; // reasonable move count
  if (runScore < 0 || runScore > 10000000) return false; // reasonable score
  
  // Check that highest tile is a power of 2
  const log2 = Math.log2(highestTile);
  if (log2 !== Math.floor(log2)) return false;
  
  // Basic relationship check: higher tiles should generally require more moves
  const expectedMinMoves = Math.log2(highestTile) * 10; // rough estimate
  if (movesToHighest < expectedMinMoves * 0.5) return false; // too few moves for tile
  
  return true;
}

/**
 * Cloud Function to submit scores to leaderboards
 * Server-authoritative to prevent client tampering
 */
export const submitScore = functions.onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
    maxInstances: 100,
  },
  async (request) => {
    // Verify authentication
    if (!request.auth) {
      throw new functions.HttpsError(
        "unauthenticated",
        "Authentication required to submit scores"
      );
    }

    const uid = request.auth.uid;
    const data = request.data;

    // Validate required fields
    const {
      boardId,
      highestTile,
      secondsToHighest = 0,
      movesToHighest = 0,
      runScore = 0,
      displayName = "Anonymous Player",
    } = data || {};

    if (!boardId || !highestTile) {
      throw new functions.HttpsError(
        "invalid-argument",
        "Missing required fields: boardId and highestTile"
      );
    }

    // Validate board ID format
    const validBoardPattern = /^(global|daily:\d{4}-\d{2}-\d{2}|mode:\w+)$/;
    if (!validBoardPattern.test(boardId)) {
      throw new functions.HttpsError(
        "invalid-argument",
        "Invalid board ID format"
      );
    }

    // Validate score data
    const scoreData = {
      highestTile: Number(highestTile),
      secondsToHighest: Number(secondsToHighest),
      movesToHighest: Number(movesToHighest),
      runScore: Number(runScore),
    };

    if (!validateScore(scoreData)) {
      throw new functions.HttpsError(
        "invalid-argument",
        "Invalid score data"
      );
    }

    try {
      // Calculate composite score on server
      const compositeValue = encodeComposite(
        scoreData.highestTile,
        scoreData.secondsToHighest,
        scoreData.movesToHighest,
        scoreData.runScore
      );

      // Reference to user's score document
      const scoreDocRef = db
        .collection("leaderboards")
        .doc(boardId)
        .collection("scores")
        .doc(uid);

      // Use transaction to ensure consistency
      await db.runTransaction(async (transaction) => {
        const currentDoc = await transaction.get(scoreDocRef);
        
        // Check if new score is better than existing
        let shouldUpdate = true;
        if (currentDoc.exists) {
          const currentValue = currentDoc.get("value");
          const currentComposite = typeof currentValue === "string" 
            ? BigInt(currentValue) 
            : BigInt(currentValue || "0");
          
          shouldUpdate = compositeValue > currentComposite;
        }

        if (shouldUpdate) {
          // Get user info for display name fallback
          let finalDisplayName = displayName;
          if (!displayName || displayName.trim() === "") {
            try {
              const userRecord = await getAuth().getUser(uid);
              finalDisplayName = userRecord.displayName || "Anonymous Player";
            } catch {
              finalDisplayName = "Anonymous Player";
            }
          }

          // Update the score document
          transaction.set(
            scoreDocRef,
            {
              uid,
              displayName: finalDisplayName.substring(0, 50), // Limit display name length
              value: compositeValue.toString(), // Store as string to avoid int64 limits
              highestTile: scoreData.highestTile,
              movesToHighest: scoreData.movesToHighest,
              secondsToHighest: scoreData.secondsToHighest,
              runScore: scoreData.runScore,
              achievedAt: new Date(),
              updatedAt: new Date(),
            },
            { merge: true }
          );

          functions.logger.info("Score submitted successfully", {
            uid,
            boardId,
            highestTile: scoreData.highestTile,
            compositeScore: compositeValue.toString(),
          });
        } else {
          functions.logger.info("Score not submitted - not better than existing", {
            uid,
            boardId,
            newScore: compositeValue.toString(),
          });
        }
      });

      return { 
        success: true, 
        message: "Score submitted successfully",
        compositeScore: compositeValue.toString()
      };

    } catch (error) {
      functions.logger.error("Error submitting score", {
        uid,
        boardId,
        error: error instanceof Error ? error.message : String(error),
      });

      throw new functions.HttpsError(
        "internal",
        "Failed to submit score. Please try again."
      );
    }
  }
);
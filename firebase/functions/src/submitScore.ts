import * as functions from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

// The Firebase CLI imports this module during deploy analysis. Initialize the
// Admin SDK before any module-scope service access so analysis and runtime both
// see a default app.
if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

// Composite score calculation constants
const BASE_SCORE = 1_000_000;
const BASE_MOVES = 1_000;
const BASE_TIME = 10_000;
const FACTOR = BigInt(BASE_SCORE) * BigInt(BASE_MOVES) * BigInt(BASE_TIME); // 10^13

// Maximum tile step the server will accept. The Swift side uses
// `TileStepLabelFormatter` which supports alpha/infinity steps far beyond 2^62.
// We keep a generous cap to avoid pathological values while still allowing the
// alpha/infinity progression the gameplay produces in long sessions.
const MAX_TILE_STEP = 2000;
const MAX_RUN_SECONDS = 24 * 60 * 60; // 24h
const MAX_RUN_MOVES = 1_000_000;
const MAX_RUN_SCORE = 1_000_000_000_000; // 1 trillion

/**
 * Encodes a composite score that prioritizes:
 * 1. Highest tile achieved (exponential weight via step index)
 * 2. Speed (less time is better)
 * 3. Efficiency (fewer moves is better)
 * 4. Raw score (tie-breaker)
 *
 * `tileStep` should be the step index the client computed (`highestTileStep`).
 * Falling back to `Math.log2(highestTile)` produces nonsense for tiles whose
 * value overflowed to `Number.POSITIVE_INFINITY` on the wire — we no longer do
 * that.
 */
function encodeComposite(
  tileStep: number,
  seconds: number,
  moves: number,
  runScore: number
): bigint {
  const p = BigInt(Math.max(2, Math.floor(tileStep)));
  const t = BigInt(Math.max(0, Math.min(BASE_TIME - seconds, BASE_TIME)));
  const m = BigInt(Math.max(0, Math.min(BASE_MOVES - moves, BASE_MOVES)));
  const rs = BigInt(Math.max(0, Math.min(runScore, BASE_SCORE - 1)));

  return p * FACTOR + t * BigInt(1_000_000_000) + m * BigInt(1_000_000) + rs;
}

/**
 * Validates that the submitted score is reasonable. Accepts alpha/infinity
 * progression by reading `highestTileStep` rather than re-deriving it from
 * a numeric tile value (which overflows in JS for very large steps).
 */
function validateScore(data: {
  highestTile: number;
  highestTileStep: number;
  secondsToHighest: number;
  movesToHighest: number;
  runScore: number;
}): boolean {
  const { highestTile, highestTileStep, secondsToHighest, movesToHighest, runScore } = data;

  if (!Number.isFinite(highestTileStep) || highestTileStep < 1 || highestTileStep > MAX_TILE_STEP) return false;
  if (highestTile < 4 && highestTileStep < 2) return false;
  if (secondsToHighest < 0 || secondsToHighest > MAX_RUN_SECONDS) return false;
  if (movesToHighest < 0 || movesToHighest > MAX_RUN_MOVES) return false;
  if (runScore < 0 || runScore > MAX_RUN_SCORE) return false;

  // Loose minimum-move sanity check. The 0.5x factor leaves headroom for the
  // 8-direction merge gameplay where one chain can collapse many tiles at once.
  const expectedMinMoves = highestTileStep * 5;
  if (movesToHighest < expectedMinMoves * 0.5) return false;

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
    invoker: "public",
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
      highestTileStep,
      secondsToHighest = 0,
      movesToHighest = 0,
      runScore = 0,
      displayName = "Anonymous Player",
    } = data || {};

    if (!boardId || (!highestTile && !highestTileStep)) {
      throw new functions.HttpsError(
        "invalid-argument",
        "Missing required fields: boardId and either highestTile or highestTileStep"
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

    const numericTile = Number(highestTile ?? 0);
    const stepFromValue = numericTile > 0 && Number.isFinite(numericTile)
      ? Math.floor(Math.log2(Math.max(2, numericTile)))
      : 0;
    const tileStep = Number(highestTileStep ?? stepFromValue);

    // Validate score data
    const scoreData = {
      highestTile: numericTile,
      highestTileStep: tileStep,
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
        scoreData.highestTileStep,
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
              highestTileStep: scoreData.highestTileStep,
              movesToHighest: scoreData.movesToHighest,
              secondsToHighest: scoreData.secondsToHighest,
              runScore: scoreData.runScore,
              achievedAt: new Date(),
              updatedAt: new Date(),
            },
            { merge: true }
          );

          logger.info("Score submitted successfully", {
            uid,
            boardId,
            highestTile: scoreData.highestTile,
            compositeScore: compositeValue.toString(),
          });
        } else {
          logger.info("Score not submitted - not better than existing", {
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
      logger.error("Error submitting score", {
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

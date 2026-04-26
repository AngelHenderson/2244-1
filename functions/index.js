/**
 * Cloud Functions for the 2244 puzzle game.
 *
 * Setup (one time):
 *   1. Install Firebase CLI: `npm install -g firebase-tools`
 *   2. From repo root: `firebase login` then `firebase use --add` and pick your project.
 *   3. `cd functions && npm install`
 *   4. Deploy: `firebase deploy --only functions`
 *
 * Local emulator: `cd functions && npm run serve`
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// ----------------------------------------------------------------------
// Tunables — adjust to taste once you have real telemetry.
// ----------------------------------------------------------------------
const REPORT_COOLDOWN_HOURS = 24;          // Same reporter → same target rate-limit
const ABUSE_POINTS_FOR_BAN = 5;            // Threshold to escalate to ban
const FIRST_BAN_HOURS = 24;                // First offense
const SECOND_BAN_HOURS = 72;               // Repeat
const PERMABAN_AFTER_TEMP_BANS = 2;        // After N temp bans → permaban

// ----------------------------------------------------------------------
// onReportCreated: triggered when the iOS app writes /reports/{id}
// (FirestoreReportService.submit). De-dupes, accumulates abuse points
// against the reported player, and escalates to a ban when the threshold
// is hit.
// ----------------------------------------------------------------------
exports.onReportCreated = onDocumentCreated("reports/{reportId}", async (event) => {
  const data = event.data?.data();
  if (!data) {
    console.warn("Report document had no data");
    return;
  }

  const reportedName = data.reportedPlayerName;
  const reportedId = data.reportedPlayerId || null;
  const reporterId = data.reporterId;

  if (!reportedName || !reporterId) {
    console.warn("Report missing required fields", { reportedName, reporterId });
    return;
  }

  // Self-reports are dropped.
  if (reportedId && reportedId === reporterId) {
    console.info("Dropping self-report", { reporterId });
    return;
  }

  // Resolve the reported player document. Prefer ID, fall back to name lookup.
  const playerRef = reportedId
    ? db.collection("players").doc(reportedId)
    : await findPlayerByName(reportedName);

  if (!playerRef) {
    console.info("No matching player document for report", { reportedName });
    return;
  }

  // De-dupe within cooldown window.
  const cooldownAgo = Timestamp.fromMillis(
    Date.now() - REPORT_COOLDOWN_HOURS * 60 * 60 * 1000
  );
  const recent = await db
    .collection("reports")
    .where("reporterId", "==", reporterId)
    .where("reportedPlayerName", "==", reportedName)
    .where("clientTimestamp", ">=", cooldownAgo)
    .limit(2)
    .get();
  if (recent.size > 1) {
    console.info("Duplicate report within cooldown — skipping abuse-point increment", {
      reporterId,
      reportedName,
    });
    return;
  }

  // Atomically increment abuse points + maybe issue a ban.
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(playerRef);
    const current = snap.exists ? snap.data() : {};
    const points = (current.abuse_points || 0) + 1;
    const tempBanCount = current.temp_ban_count || 0;

    const update = {
      abuse_points: points,
      last_reported_at: FieldValue.serverTimestamp(),
    };

    if (points >= ABUSE_POINTS_FOR_BAN) {
      update.abuse_points = 0; // reset after escalation
      const newTempBanCount = tempBanCount + 1;
      update.temp_ban_count = newTempBanCount;
      if (newTempBanCount > PERMABAN_AFTER_TEMP_BANS) {
        update.banned_until = "permanent";
        update.ban_reason = "Repeat abuse";
      } else {
        const banHours = newTempBanCount === 1 ? FIRST_BAN_HOURS : SECOND_BAN_HOURS;
        update.banned_until = Timestamp.fromMillis(
          Date.now() + banHours * 60 * 60 * 1000
        );
        update.ban_reason = `Reported ${ABUSE_POINTS_FOR_BAN}+ times`;
      }
    }

    tx.set(playerRef, update, { merge: true });
  });
});

// ----------------------------------------------------------------------
// onPurchaseCreated: optional — validate StoreKit JWS server-side once
// PurchaseService.onVerifiedPurchase is wired to forward the JWS here.
// Currently a stub: accepts the receipt and writes a confirmation doc.
// ----------------------------------------------------------------------
// exports.onPurchaseCreated = onDocumentCreated(
//   "players/{uid}/purchases/{txnId}",
//   async (event) => {
//     // TODO: verify the transaction's JWS signature using App Store Server API.
//     console.info("Purchase received", event.params);
//   }
// );

// ----------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------
async function findPlayerByName(name) {
  const lookup = await db
    .collection("players")
    .where("displayName", "==", name)
    .limit(1)
    .get();
  return lookup.empty ? null : lookup.docs[0].ref;
}

import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import {
  DocumentReference,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

const REPORT_COOLDOWN_HOURS = 24;
const ABUSE_POINTS_FOR_BAN = 5;
const FIRST_BAN_HOURS = 24;
const SECOND_BAN_HOURS = 72;
const PERMABAN_AFTER_TEMP_BANS = 2;

interface ReportDocument {
  reportedPlayerName?: string;
  reportedPlayerId?: string;
  reporterId?: string;
  clientTimestamp?: Timestamp;
}

interface PlayerModerationState {
  abuse_points?: number;
  temp_ban_count?: number;
}

type ModerationUpdate = {
  abuse_points: number;
  last_reported_at: FieldValue;
  temp_ban_count?: number;
  banned_until?: Timestamp | "permanent";
  ban_reason?: string;
};

export const onReportCreated = onDocumentCreated("reports/{reportId}", async (event) => {
  const data = event.data?.data() as ReportDocument | undefined;
  if (!data) {
    logger.warn("Report document had no data", event.params);
    return;
  }

  const reportedName = data.reportedPlayerName?.trim();
  const reportedId = data.reportedPlayerId?.trim() || null;
  const reporterId = data.reporterId?.trim();

  if (!reportedName || !reporterId) {
    logger.warn("Report missing required fields", {
      reportId: event.params.reportId,
      hasReportedName: Boolean(reportedName),
      hasReporterId: Boolean(reporterId),
    });
    return;
  }

  if (reportedId && reportedId === reporterId) {
    logger.info("Dropping self-report", { reporterId });
    return;
  }

  const playerRef = reportedId
    ? db.collection("players").doc(reportedId)
    : await findPlayerByName(reportedName);

  if (!playerRef) {
    logger.info("No matching player document for report", { reportedName });
    return;
  }

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
    logger.info("Duplicate report within cooldown; skipping abuse increment", {
      reporterId,
      reportedName,
    });
    return;
  }

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(playerRef);
    const current = (snapshot.exists ? snapshot.data() : {}) as PlayerModerationState;
    const points = Number(current.abuse_points ?? 0) + 1;
    const tempBanCount = Number(current.temp_ban_count ?? 0);

    const update: ModerationUpdate = {
      abuse_points: points,
      last_reported_at: FieldValue.serverTimestamp(),
    };

    if (points >= ABUSE_POINTS_FOR_BAN) {
      update.abuse_points = 0;
      const newTempBanCount = tempBanCount + 1;
      update.temp_ban_count = newTempBanCount;

      if (newTempBanCount > PERMABAN_AFTER_TEMP_BANS) {
        update.banned_until = "permanent";
        update.ban_reason = "Repeat abuse";
      } else {
        const banHours = newTempBanCount === 1 ? FIRST_BAN_HOURS : SECOND_BAN_HOURS;
        update.banned_until = Timestamp.fromMillis(Date.now() + banHours * 60 * 60 * 1000);
        update.ban_reason = `Reported ${ABUSE_POINTS_FOR_BAN}+ times`;
      }
    }

    transaction.set(playerRef, update, { merge: true });
  });
});

async function findPlayerByName(name: string): Promise<DocumentReference | null> {
  const lookup = await db
    .collection("players")
    .where("displayName", "==", name)
    .limit(1)
    .get();

  return lookup.empty ? null : lookup.docs[0].ref;
}

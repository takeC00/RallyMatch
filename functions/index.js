const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");

admin.initializeApp();

/**
 * Deletes expired sessions daily at 04:00 JST.
 * - sessions/{sessionId}
 *   - matches/*
 *   - sessionPlayers/*
 */
exports.deleteExpiredSessions = onSchedule(
  {
    schedule: "0 4 * * *",
    timeZone: "Asia/Tokyo",
    retryCount: 3,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    let totalDeleted = 0;
    while (true) {
      const expiredSnap = await db
        .collection("sessions")
        .where("expiresAt", "<=", now)
        .orderBy("expiresAt", "asc")
        .limit(200)
        .get();

      if (expiredSnap.empty) {
        if (totalDeleted === 0) {
          logger.info("No expired sessions to delete.");
        } else {
          logger.info(`Deleted ${totalDeleted} expired sessions in total.`);
        }
        return;
      }

      logger.info(`Deleting batch of ${expiredSnap.size} expired sessions...`);

      for (const doc of expiredSnap.docs) {
        try {
          await deleteSessionTree(db, doc.ref);
          totalDeleted += 1;
          logger.info(`Deleted session: ${doc.id}`);
        } catch (e) {
          logger.error(`Failed deleting session: ${doc.id}`, e);
        }
      }
    }
  }
);

async function deleteSessionTree(db, sessionRef) {
  // Prefer native recursiveDelete if available (admin SDK version dependent).
  if (typeof db.recursiveDelete === "function") {
    await db.recursiveDelete(sessionRef);
    return;
  }

  // Fallback: delete subcollections then session doc.
  await deleteCollection(db, sessionRef.collection("matches"), 300);
  await deleteCollection(db, sessionRef.collection("sessionPlayers"), 300);
  await sessionRef.delete();
}

async function deleteCollection(db, colRef, batchSize) {
  let lastDoc = null;
  while (true) {
    let q = colRef.orderBy(admin.firestore.FieldPath.documentId()).limit(batchSize);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) return;

    const batch = db.batch();
    for (const d of snap.docs) batch.delete(d.ref);
    await batch.commit();

    lastDoc = snap.docs[snap.docs.length - 1];
  }
}


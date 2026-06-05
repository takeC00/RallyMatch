import Foundation
import FirebaseFirestore

/// サークル削除時の関連 Firestore データ一括削除（Hub / Mate / Match 共通スキーマ）
@MainActor
enum CircleDeletionService {
    private static var db: Firestore { Firestore.firestore() }

    static func deleteCircle(circleId: String, ownerId: String) async throws {
        try await deleteQuery(
            db.collection("eventParticipants").whereField("circleId", isEqualTo: circleId)
        )
        try await deleteQuery(
            db.collection("eventVisitors").whereField("circleId", isEqualTo: circleId)
        )
        try await deleteQuery(
            db.collection("events").whereField("circleId", isEqualTo: circleId)
        )
        try await deleteQuery(
            db.collection("announcements").whereField("circleId", isEqualTo: circleId)
        )
        try await deleteQuery(
            db.collection("circleRoster").whereField("circleId", isEqualTo: circleId)
        )
        try await deleteQuery(
            db.collection("matches").whereField("circleId", isEqualTo: circleId)
        )

        let sessions = try await db.collection("sessions")
            .whereField("circleId", isEqualTo: circleId)
            .getDocuments()
        for document in sessions.documents {
            try await SessionSyncService.shared.deleteSession(sessionId: document.documentID)
        }

        let stableSessionId = AppConfig.stableSessionId(for: circleId)
        let stableRef = db.collection("sessions").document(stableSessionId)
        if (try await stableRef.getDocument()).exists {
            try await SessionSyncService.shared.deleteSession(sessionId: stableSessionId)
        }

        try await deleteQuery(
            db.collection("circleMembers").whereField("circleId", isEqualTo: circleId)
        )

        try await db.collection("circles").document(circleId).delete()

        let userRef = db.collection("users").document(ownerId)
        let userDoc = try await userRef.getDocument()
        if userDoc.data()?["currentCircleId"] as? String == circleId {
            try await userRef.updateData([
                "currentCircleId": FieldValue.delete(),
                "updatedAt": Timestamp(date: .now),
            ])
        }
    }

    private static func deleteQuery(_ query: Query) async throws {
        while true {
            let snapshot = try await query.limit(to: 300).getDocuments()
            if snapshot.isEmpty { return }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
    }
}

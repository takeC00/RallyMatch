import Foundation
import FirebaseFirestore

@MainActor
final class SessionSyncService {
    static let shared = SessionSyncService()
    private let db = Firestore.firestore()

    private init() {}

    func createSession(
        sessionId: String,
        circleId: UUID,
        mode: GenerationMode,
        courtCount: Int,
        matchPerPlayer: Int,
        ownerUid: String,
        players: [SessionPlayer],
        matches: [GeneratedMatch]
    ) async throws {
        let sessionRef = db.collection("sessions").document(sessionId)
        let now = Timestamp(date: .now)
        let expiresAt = Timestamp(date: AppConfig.defaultExpiresAt())

        try await sessionRef.setData([
            "circleId": circleId.uuidString,
            "mode": mode.rawValue,
            "courtCount": courtCount,
            "matchPerPlayer": matchPerPlayer,
            "ownerUid": ownerUid,
            "expiresAt": expiresAt,
            "createdAt": now,
            "updatedAt": now,
        ])

        try await uploadPlayers(players, sessionId: sessionId)
        try await replaceMatches(matches, sessionId: sessionId, onlyScheduled: false)
    }

    func uploadPlayers(_ players: [SessionPlayer], sessionId: String) async throws {
        let col = db.collection("sessions").document(sessionId).collection("sessionPlayers")
        let batch = db.batch()
        for p in players {
            let ref = col.document(p.id.uuidString)
            batch.setData([
                "name": p.name,
                "level": p.level.rawValue,
            ], forDocument: ref)
        }
        try await batch.commit()
    }

    func replaceMatches(
        _ matches: [GeneratedMatch],
        sessionId: String,
        onlyScheduled: Bool
    ) async throws {
        let col = db.collection("sessions").document(sessionId).collection("matches")

        if onlyScheduled {
            let snap = try await col.whereField("status", isEqualTo: MatchStatus.scheduled.rawValue).getDocuments()
            let batch = db.batch()
            for doc in snap.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }

        let batch = db.batch()
        let now = Timestamp(date: .now)
        for m in matches where !onlyScheduled || m.status == .scheduled {
            let ref = col.document(m.id.uuidString)
            batch.setData([
                "matchNo": m.matchNo,
                "courtNo": m.courtNo,
                "team1": m.team1.map(\.uuidString),
                "team2": m.team2.map(\.uuidString),
                "playerIds": m.playerIds.map(\.uuidString),
                "status": m.status.rawValue,
                "createdAt": now,
                "updatedAt": now,
            ], forDocument: ref)
        }
        try await batch.commit()

        try await db.collection("sessions").document(sessionId).updateData([
            "updatedAt": now,
        ])
    }

    func updateMatch(_ match: GeneratedMatch, sessionId: String) async throws {
        let ref = db.collection("sessions").document(sessionId)
            .collection("matches").document(match.id.uuidString)
        try await ref.updateData([
            "matchNo": match.matchNo,
            "courtNo": match.courtNo,
            "team1": match.team1.map(\.uuidString),
            "team2": match.team2.map(\.uuidString),
            "playerIds": match.playerIds.map(\.uuidString),
            "status": match.status.rawValue,
            "updatedAt": Timestamp(date: .now),
        ])
    }

    func deleteMatch(_ matchId: UUID, sessionId: String) async throws {
        try await db.collection("sessions").document(sessionId)
            .collection("matches").document(matchId.uuidString).delete()
    }

    func markMatchesDone(upTo matchNo: Int, sessionId: String, matches: [GeneratedMatch]) async throws {
        let batch = db.batch()
        let now = Timestamp(date: .now)
        let col = db.collection("sessions").document(sessionId).collection("matches")

        for m in matches where m.matchNo <= matchNo && m.status == .scheduled {
            let ref = col.document(m.id.uuidString)
            batch.updateData([
                "status": MatchStatus.done.rawValue,
                "updatedAt": now,
            ], forDocument: ref)
        }
        try await batch.commit()
    }
}

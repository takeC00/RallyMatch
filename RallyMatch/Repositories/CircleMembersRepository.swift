import Foundation
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class CircleMembersRepository {
    static let shared = CircleMembersRepository()

    private(set) var membersByCircle: [String: [CloudCircleMember]] = [:]
    private(set) var isLoadingCircleIds: Set<String> = []
    var lastError: String?

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func members(for circleId: String) -> [CloudCircleMember] {
        membersByCircle[circleId] ?? []
    }

    func refresh(circleId: String) async {
        isLoadingCircleIds.insert(circleId)
        defer { isLoadingCircleIds.remove(circleId) }

        do {
            let snapshot = try await db.collection("circleMembers")
                .whereField("circleId", isEqualTo: circleId)
                .getDocuments()

            let members = snapshot.documents
                .compactMap { CloudCircleMember.from($0) }
                .sorted { $0.userName.localizedCaseInsensitiveCompare($1.userName) == .orderedAscending }

            membersByCircle[circleId] = members
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshAll(circleIds: [String]) async {
        for circleId in circleIds {
            await refresh(circleId: circleId)
        }
    }

    /// `circleMembers` を `circleRoster` に同期（Mate / Hub で参加したメンバーを Match 試合生成に使えるようにする）
    func syncMembersToRoster(circleId: String) async throws {
        if membersByCircle[circleId] == nil {
            await refresh(circleId: circleId)
        }

        let members = members(for: circleId)
        let now = Timestamp(date: .now)

        for member in members {
            let playerId = PlayerIdentity.stablePlayerId(userId: member.userId)
            let documentId = PlayerIdentity.linkedRosterDocumentId(
                circleId: circleId,
                userId: member.userId
            )

            try await db.collection("circleRoster")
                .document(documentId)
                .setData([
                    "circleId": circleId,
                    "playerId": playerId.uuidString.lowercased(),
                    "name": member.userName,
                    "level": PlayerLevel.experienced.rawValue,
                    "userId": member.userId,
                    "createdAt": Timestamp(date: member.joinedAt),
                    "updatedAt": now,
                ], merge: true)
        }

        await CircleRosterRepository.shared.refresh(circleId: circleId)
    }

    func syncAllJoinedCircles(_ circleIds: [String]) async {
        for circleId in circleIds {
            do {
                try await syncMembersToRoster(circleId: circleId)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}

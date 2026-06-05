import Foundation

enum PlayerIdentity {
    /// Firebase `userId` から安定した UUID を生成（サークル間で一貫した参加者 ID）
    static func stablePlayerId(userId: String) -> UUID {
        stablePlayerId(from: userId)
    }

    /// circleMembers ドキュメント ID から安定した UUID を生成（手動登録メンバー用）
    static func stablePlayerId(circleMemberDocumentId: String) -> UUID {
        stablePlayerId(from: circleMemberDocumentId)
    }

    private static func stablePlayerId(from seed: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in seed.utf8.enumerated() {
            bytes[index % 16] = bytes[index % 16] &+ byte
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    static func linkedRosterDocumentId(circleId: String, userId: String) -> String {
        CloudCircleMember.documentId(circleId: circleId, userId: userId)
    }

    static func manualRosterDocumentId(circleMemberDocumentId: String) -> String {
        circleMemberDocumentId
    }
}

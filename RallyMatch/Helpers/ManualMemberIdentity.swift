import Foundation

/// 手動登録メンバーを Mate 試合・レーティングで識別する ID 形式
enum ManualMemberIdentity {
    static let prefix = "manual:"

    static func playerId(circleMemberDocumentId: String) -> String {
        prefix + circleMemberDocumentId
    }

    static func isManual(_ playerId: String) -> Bool {
        playerId.hasPrefix(prefix)
    }

    static func circleMemberDocumentId(from playerId: String) -> String? {
        guard isManual(playerId) else { return nil }
        return String(playerId.dropFirst(prefix.count))
    }
}

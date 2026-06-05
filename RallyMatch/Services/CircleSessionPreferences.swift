import Foundation

/// サークルごとの進行中セッション ID（端末ローカル。Phase D で Firestore 移行可）
enum CircleSessionPreferences {
    private static let keyPrefix = "match.activeSessionId."

    static func activeSessionId(for circleId: String) -> String? {
        UserDefaults.standard.string(forKey: keyPrefix + circleId)
    }

    static func setActiveSessionId(_ sessionId: String?, for circleId: String) {
        let key = keyPrefix + circleId
        if let sessionId {
            UserDefaults.standard.set(sessionId, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

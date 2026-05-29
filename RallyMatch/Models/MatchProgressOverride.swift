import Foundation

/// 試合中スロットの手動指定（未設定は自動キューに従う）
enum MatchProgressOverride: String, Codable, Hashable {
    case forcedIn = "in"
    /// 主催者が試合中バッジをタップして解除
    case forcedOut = "out"
    /// 後の試合を先に開始したため一時的に外した（スロットが空くと自動キューに戻る）
    case deferredOut = "deferred"
}

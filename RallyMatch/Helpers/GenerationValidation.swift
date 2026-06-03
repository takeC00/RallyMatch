import Foundation

/// 試合生成前の参加者構成チェック
enum GenerationValidation {
    enum Severity {
        case warning
        case blocking
    }

    struct Issue: Identifiable {
        let id = UUID()
        let message: String
        let severity: Severity
    }

    static func validate(
        players: [SessionPlayer],
        mode: GenerationMode,
        matchPerPlayer: Int = 1,
        courtCount: Int = 1
    ) -> [Issue] {
        var issues: [Issue] = []

        if players.count < 4 {
            issues.append(
                Issue(
                    message: "参加者が\(players.count)名です。試合生成には4名以上必要です。",
                    severity: .blocking
                )
            )
            return issues
        }

        switch mode {
        case .separated:
            issues.append(contentsOf: separatedModeIssues(players: players))
        case .mix:
            break
        }

        _ = matchPerPlayer
        _ = courtCount
        return issues
    }

    private static func separatedModeIssues(players: [SessionPlayer]) -> [Issue] {
        let beginnerCount = players.filter { $0.level == .beginner }.count
        let experiencedCount = players.filter { $0.level == .experienced }.count
        let canFormBeginnerMatch = beginnerCount >= 4
        let canFormExperiencedMatch = experiencedCount >= 4

        var issues: [Issue] = []

        if beginnerCount > 0 && beginnerCount < 4 {
            issues.append(
                Issue(
                    message: "初心者が\(beginnerCount)名のため、モードBでは初心者同士の試合を組めません。初心者は試合に参加できません。",
                    severity: .warning
                )
            )
        }

        if experiencedCount > 0 && experiencedCount < 4 {
            issues.append(
                Issue(
                    message: "経験者が\(experiencedCount)名のため、モードBでは経験者同士の試合を組めません。経験者は試合に参加できません。",
                    severity: .warning
                )
            )
        }

        if !canFormBeginnerMatch && !canFormExperiencedMatch {
            issues.append(
                Issue(
                    message: "モードBでは同一レベル4名以上が必要です。現在の構成（初心者\(beginnerCount)名・経験者\(experiencedCount)名）では試合を1つも生成できません。",
                    severity: .blocking
                )
            )
        }

        return issues
    }
}

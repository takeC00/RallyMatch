import Foundation

enum MatchRoundHelper {
    /// コート数に基づく巡（1巡 = 全コートが1試合ずつ）
    static func roundNumber(matchNo: Int, courtCount: Int) -> Int {
        (matchNo - 1) / max(1, courtCount) + 1
    }

    static func groups(
        from matches: [GeneratedMatch],
        courtCount: Int
    ) -> [(round: Int, matches: [GeneratedMatch])] {
        let active = matches
            .filter { $0.status != .cancelled }
            .sorted { $0.matchNo < $1.matchNo }

        var dict: [Int: [GeneratedMatch]] = [:]
        for match in active {
            let round = roundNumber(matchNo: match.matchNo, courtCount: courtCount)
            dict[round, default: []].append(match)
        }

        return dict.keys.sorted().map { round in
            (round: round, matches: dict[round] ?? [])
        }
    }
}

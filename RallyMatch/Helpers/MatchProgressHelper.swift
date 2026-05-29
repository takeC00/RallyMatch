import Foundation

/// 未実施試合の先頭（コート数ぶん）を「試合中」、それ以降の待ち人数を「次の試合まで N」とする。
enum MatchProgressHelper {
    static func orderedScheduled(_ matches: [GeneratedMatch]) -> [GeneratedMatch] {
        matches
            .filter { $0.status == .scheduled }
            .sorted { $0.matchNo < $1.matchNo }
    }

    static func inProgressMatches(
        scheduled: [GeneratedMatch],
        courtCount: Int
    ) -> [GeneratedMatch] {
        let n = max(1, courtCount)
        return Array(orderedScheduled(scheduled).prefix(n))
    }

    static func inProgressMatchIds(
        scheduled: [GeneratedMatch],
        courtCount: Int
    ) -> Set<UUID> {
        Set(inProgressMatches(scheduled: scheduled, courtCount: courtCount).map(\.id))
    }

    static func isPlayerInProgress(
        playerId: UUID,
        scheduled: [GeneratedMatch],
        courtCount: Int
    ) -> Bool {
        inProgressMatches(scheduled: scheduled, courtCount: courtCount)
            .contains { $0.playerIds.contains(playerId) }
    }

    /// 試合中でなければ「次の試合まで」の数（1 始まり）。未実施に出場予定がなければ `nil`。
    static func waitUntilNext(
        playerId: UUID,
        scheduled: [GeneratedMatch],
        courtCount: Int
    ) -> Int? {
        let ordered = orderedScheduled(scheduled)
        let n = max(1, courtCount)
        guard let index = ordered.firstIndex(where: { $0.playerIds.contains(playerId) }) else {
            return nil
        }
        if index < n { return nil }
        return index - n + 1
    }
}

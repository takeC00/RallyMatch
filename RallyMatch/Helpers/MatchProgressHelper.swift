import Foundation

/// 未実施試合の「試合中」スロット（最大コート数）。手動指定と自動キューを組み合わせる。
enum MatchProgressHelper {
    static func orderedScheduled(_ matches: [GeneratedMatch]) -> [GeneratedMatch] {
        matches
            .filter { $0.status == .scheduled }
            .sorted { $0.matchNo < $1.matchNo }
    }

    static func effectiveInProgressMatches(
        scheduled: [GeneratedMatch],
        courtCount: Int
    ) -> [GeneratedMatch] {
        let n = max(1, courtCount)
        let ordered = orderedScheduled(scheduled)

        var forcedIn = ordered.filter { $0.progressOverride == .forcedIn }
        let excludedFromAutoIds = Set(
            ordered.filter {
                $0.progressOverride == .forcedOut || $0.progressOverride == .deferredOut
            }.map(\.id)
        )

        while forcedIn.count > n {
            forcedIn.removeFirst()
        }

        var result = forcedIn
        var resultIds = Set(result.map(\.id))

        if result.count < n {
            for match in ordered {
                if result.count >= n { break }
                if excludedFromAutoIds.contains(match.id) { continue }
                if resultIds.contains(match.id) { continue }
                result.append(match)
                resultIds.insert(match.id)
            }
        }

        return Array(result.prefix(n))
    }

    static func inProgressMatches(
        scheduled: [GeneratedMatch],
        courtCount: Int
    ) -> [GeneratedMatch] {
        effectiveInProgressMatches(scheduled: scheduled, courtCount: courtCount)
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
        let inProgress = effectiveInProgressMatches(scheduled: scheduled, courtCount: courtCount)
        let inProgressIds = Set(inProgress.map(\.id))

        guard let index = ordered.firstIndex(where: { $0.playerIds.contains(playerId) }) else {
            return nil
        }
        if inProgressIds.contains(ordered[index].id) { return nil }

        let waiting = ordered.filter { !inProgressIds.contains($0.id) }
        guard let waitIndex = waiting.firstIndex(where: { $0.playerIds.contains(playerId) }) else {
            return nil
        }
        return waitIndex + 1
    }
}

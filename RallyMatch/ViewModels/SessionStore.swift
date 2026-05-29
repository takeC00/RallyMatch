import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    var sessionId: String?
    var circleId: UUID?
    var players: [SessionPlayer] = []
    var matches: [GeneratedMatch] = []
    var mode: GenerationMode = .mix
    var courtCount: Int = 2
    var matchPerPlayer: Int = 3
    var isSyncing = false
    var errorMessage: String?
    var isQuotaLimited = false
    var showParticipationSummary = false

    var participationRows: [PlayerParticipation] {
        ParticipationStats.counts(players: players, matches: matches)
    }

    var scheduledMatches: [GeneratedMatch] {
        matches.filter { $0.status == .scheduled }.sorted { $0.matchNo < $1.matchNo }
    }

    var doneMatches: [GeneratedMatch] {
        matches.filter { $0.status == .done }.sorted { $0.matchNo < $1.matchNo }
    }

    func reset() {
        sessionId = nil
        circleId = nil
        players = []
        matches = []
        errorMessage = nil
        isQuotaLimited = false
        showParticipationSummary = false
    }

    func reportSyncError(_ error: Error, context: String? = nil) {
        isQuotaLimited = FirebaseUsageError.isQuotaExceeded(error)
        errorMessage = FirebaseUsageError.userFacingMessage(for: error, context: context)
    }

    func clearSyncError() {
        errorMessage = nil
        isQuotaLimited = false
    }

    func generateMatches() {
        matches = MatchGenerator.generate(
            players: players,
            mode: mode,
            matchPerPlayer: matchPerPlayer,
            courtCount: courtCount
        )
        ensureRoundNumbers()
    }

    /// 旧データなど roundNo 未設定のときに全試合から巡を再計算
    func ensureRoundNumbers() {
        guard matches.contains(where: { $0.roundNo < 1 }) else { return }
        matches = MatchRoundHelper.assignRounds(
            to: matches,
            playerIds: players.map(\.id)
        )
    }

    func regenerateScheduled() {
        let done = doneMatches
        matches = MatchGenerator.regenerateScheduled(
            players: players,
            mode: mode,
            matchPerPlayer: matchPerPlayer,
            courtCount: courtCount,
            doneMatches: done
        )
    }

    func markDone(upTo matchNo: Int) {
        for i in matches.indices where matches[i].matchNo <= matchNo && matches[i].status == .scheduled {
            matches[i].status = .done
        }
    }

    func markMatchDone(_ matchId: UUID) {
        guard let idx = matches.firstIndex(where: { $0.id == matchId }) else { return }
        matches[idx].status = .done
    }

    func swapPlayer(matchId: UUID, from playerId: UUID, to newPlayerId: UUID) {
        guard let idx = matches.firstIndex(where: { $0.id == matchId }) else { return }
        var m = matches[idx]

        if let i = m.team1.firstIndex(of: playerId) {
            m.team1[i] = newPlayerId
        } else if let i = m.team2.firstIndex(of: playerId) {
            m.team2[i] = newPlayerId
        }
        matches[idx] = m
    }

    func deleteMatch(_ matchId: UUID) {
        matches.removeAll { $0.id == matchId }
        renumberMatches()
    }

    func addPlayers(_ newPlayers: [SessionPlayer]) {
        for p in newPlayers where !players.contains(where: { $0.id == p.id }) {
            players.append(p)
        }
    }

    func moveMatch(from source: IndexSet, to destination: Int) {
        var ordered = scheduledMatches
        reorder(&ordered, fromOffsets: source, toOffset: destination)
        var no = (doneMatches.map(\.matchNo).max() ?? 0) + 1
        for i in ordered.indices {
            if let idx = matches.firstIndex(where: { $0.id == ordered[i].id }) {
                matches[idx].matchNo = no
                no += 1
            }
        }
        reassignCourts()
    }

    private func renumberMatches() {
        let done = doneMatches
        var scheduled = scheduledMatches
        var no = 1
        for i in done.indices {
            matches[matches.firstIndex(where: { $0.id == done[i].id })!].matchNo = no
            no += 1
        }
        for i in scheduled.indices {
            matches[matches.firstIndex(where: { $0.id == scheduled[i].id })!].matchNo = no
            no += 1
        }
        reassignCourts()
    }

    private func reassignCourts() {
        let courtCount = max(1, self.courtCount)
        for i in matches.indices where matches[i].status == .scheduled {
            let no = matches[i].matchNo
            matches[i].courtNo = ((no - 1) % courtCount) + 1
        }
    }

    func playerName(for id: UUID) -> String {
        players.first { $0.id == id }?.name ?? "不明"
    }

    func playerLevel(for id: UUID) -> PlayerLevel {
        players.first { $0.id == id }?.level ?? .beginner
    }

    func syncCreate(ownerUid: String) async throws {
        guard let circleId, !players.isEmpty else { return }
        isSyncing = true
        defer { isSyncing = false }

        let id = sessionId ?? UUID().uuidString.lowercased()
        sessionId = id

        try await SessionSyncService.shared.createSession(
            sessionId: id,
            circleId: circleId,
            mode: mode,
            courtCount: courtCount,
            matchPerPlayer: matchPerPlayer,
            ownerUid: ownerUid,
            players: players,
            matches: matches
        )
    }

    func syncMatches() async throws {
        guard let sessionId else { return }
        isSyncing = true
        defer { isSyncing = false }
        try await SessionSyncService.shared.replaceMatches(
            matches,
            sessionId: sessionId,
            onlyScheduled: true
        )
    }

    func syncAllMatches() async throws {
        guard let sessionId else { return }
        isSyncing = true
        defer { isSyncing = false }
        try await SessionSyncService.shared.replaceMatches(
            matches,
            sessionId: sessionId,
            onlyScheduled: false
        )
    }

    func syncSingleMatch(_ match: GeneratedMatch) async throws {
        guard let sessionId else { return }
        try await SessionSyncService.shared.updateMatch(match, sessionId: sessionId)
    }

    func syncMarkMatchDone(_ matchId: UUID) async throws {
        guard let sessionId else { return }
        markMatchDone(matchId)
        guard let match = matches.first(where: { $0.id == matchId }) else { return }
        try await SessionSyncService.shared.updateMatch(match, sessionId: sessionId)
    }

    func syncMarkDone(upTo matchNo: Int) async throws {
        guard let sessionId else { return }
        markDone(upTo: matchNo)
        try await SessionSyncService.shared.markMatchesDone(
            upTo: matchNo,
            sessionId: sessionId,
            matches: matches
        )
    }

    /// SwiftUI の `move(fromOffsets:toOffset:)` と同等（SwiftUI 非依存）
    private func reorder<T>(_ array: inout [T], fromOffsets: IndexSet, toOffset: Int) {
        let moving = fromOffsets.map { array[$0] }
        for index in fromOffsets.sorted(by: >) {
            array.remove(at: index)
        }
        var insertAt = toOffset
        for index in fromOffsets where index < toOffset {
            insertAt -= 1
        }
        array.insert(contentsOf: moving, at: insertAt)
    }
}

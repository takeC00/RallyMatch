import SwiftUI

struct MatchListView: View {
    @Bindable var sessionStore: SessionStore
    @State private var firebase = FirebaseManager.shared
    @State private var editingMatch: GeneratedMatch?
    @State private var editingPlayerId: UUID?
    @State private var showQR = false
    @State private var showAttendanceAdjust = false

    private var scheduledRoundGroups: [(round: Int, matches: [GeneratedMatch])] {
        MatchRoundHelper.groupsByStoredRound(from: sessionStore.scheduledMatches)
    }

    var body: some View {
        List {
            if let err = sessionStore.errorMessage {
                Section {
                    Label {
                        Text(err)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: sessionStore.isQuotaLimited
                            ? "exclamationmark.triangle.fill"
                            : "xmark.circle.fill")
                    }
                    .foregroundStyle(sessionStore.isQuotaLimited ? .orange : .red)
                } header: {
                    Text(sessionStore.isQuotaLimited ? "クラウド連携を一時停止中" : "エラー")
                }
            }

            if !sessionStore.doneMatches.isEmpty {
                Section {
                    ForEach(sessionStore.doneMatches) { match in
                        MatchRowView(match: match, sessionStore: sessionStore) { _ in }
                    }
                } header: {
                    Text("試合済")
                }
            }

            ForEach(scheduledRoundGroups, id: \.round) { group in
                Section {
                    ForEach(group.matches) { match in
                        matchRow(for: match)
                    }
                } header: {
                    RoundSectionHeader(round: group.round)
                }
            }
        }
        .navigationTitle("試合一覧")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sessionStore.ensureRoundNumbers()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQR = true
                } label: {
                    Image(systemName: "qrcode")
                }
                .disabled(sessionStore.sessionId == nil)
                .accessibilityLabel("QRコード")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("遅刻 / 早退") { showAttendanceAdjust = true }
                    Button("再生成") { regenerate() }
                    Button("クラウドに同期") { syncAll() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showQR) {
            if let id = sessionStore.sessionId {
                QRDisplayView(sessionId: id)
            }
        }
        .sheet(isPresented: Binding(
            get: { editingMatch != nil && editingPlayerId != nil },
            set: { if !$0 { editingMatch = nil; editingPlayerId = nil } }
        )) {
            if let match = editingMatch, let playerId = editingPlayerId {
                MatchSwapSheet(
                    match: match,
                    playerId: playerId,
                    sessionStore: sessionStore
                ) {
                    editingMatch = nil
                    editingPlayerId = nil
                }
            }
        }
        .sheet(isPresented: $showAttendanceAdjust) {
            AttendanceAdjustSheet(sessionStore: sessionStore)
        }
        .overlay {
            if sessionStore.isSyncing {
                ProgressView("同期中…")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private func matchRow(for match: GeneratedMatch) -> some View {
        MatchRowView(match: match, sessionStore: sessionStore) { playerId in
            editingMatch = match
            editingPlayerId = playerId
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                markMatchDone(match)
            } label: {
                Label("試合済", systemImage: "checkmark.circle")
            }
            .tint(.green)
        }
    }

    private func regenerate() {
        sessionStore.regenerateScheduled()
        Task {
            do {
                try await sessionStore.syncMatches()
                sessionStore.clearSyncError()
            } catch {
                sessionStore.reportSyncError(error)
            }
        }
    }

    private func markMatchDone(_ match: GeneratedMatch) {
        Task {
            do {
                try await sessionStore.syncMarkMatchDone(match.id)
                sessionStore.clearSyncError()
            } catch {
                sessionStore.reportSyncError(error)
            }
        }
    }

    private func syncAll() {
        Task {
            do {
                try await sessionStore.syncAllMatches()
                sessionStore.clearSyncError()
            } catch {
                sessionStore.reportSyncError(error)
            }
        }
    }
}

private struct RoundSectionHeader: View {
    let round: Int

    var body: some View {
        VStack(spacing: 0) {
            if round > 1 {
                Divider()
                    .padding(.bottom, 6)
            }
            Text("\(round)巡目")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets())
    }
}

struct MatchRowView: View {
    let match: GeneratedMatch
    @Bindable var sessionStore: SessionStore
    let onTapPlayer: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("第\(match.matchNo)試合")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            VStack(spacing: 6) {
                teamBlock(ids: match.team1)
                Text("VS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                teamBlock(ids: match.team2)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
        .opacity(match.status == .cancelled ? 0.4 : 1)
    }

    @ViewBuilder
    private func teamBlock(ids: [UUID]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                if index > 0 {
                    Text("・")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Button {
                    if match.status == .scheduled { onTapPlayer(id) }
                } label: {
                    Text(sessionStore.playerName(for: id))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color(for: id))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }

    private func color(for id: UUID) -> Color {
        sessionStore.playerLevel(for: id) == .experienced ? .red : .blue
    }

    @ViewBuilder
    private var statusBadge: some View {
        if match.status == .done {
            Text("済")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
        } else if sessionStore.inProgressMatchIds.contains(match.id) {
            HStack(spacing: 4) {
                Image(systemName: "sportscourt.fill")
                Text("試合中")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())
        } else {
            Text("\(match.courtNo)コート")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.teal.opacity(0.15))
                .foregroundStyle(Color.teal)
                .clipShape(Capsule())
        }
    }
}

// MARK: - 確認画面用の統計

struct TeammatePair: Identifiable {
    let player1: SessionPlayer
    let player2: SessionPlayer
    let count: Int

    var id: String {
        MatchListPairStats.pairKey(player1.id, player2.id)
    }
}

private enum MatchListPairStats {
    static func pairKey(_ x: UUID, _ y: UUID) -> String {
        if x.uuidString < y.uuidString {
            return "\(x.uuidString)|\(y.uuidString)"
        }
        return "\(y.uuidString)|\(x.uuidString)"
    }

    static func teammatePairCounts(
        players: [SessionPlayer],
        matches: [GeneratedMatch]
    ) -> [TeammatePair] {
        var counts: [String: Int] = [:]
        let active = matches.filter { $0.status != .cancelled }

        for match in active {
            recordTeam(match.team1, into: &counts)
            recordTeam(match.team2, into: &counts)
        }

        var result: [TeammatePair] = []
        for i in 0 ..< players.count {
            for j in (i + 1) ..< players.count {
                let key = pairKey(players[i].id, players[j].id)
                let count = counts[key, default: 0]
                guard count > 0 else { continue }
                result.append(
                    TeammatePair(
                        player1: players[i],
                        player2: players[j],
                        count: count
                    )
                )
            }
        }

        return result.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count < rhs.count }
            if lhs.player1.name != rhs.player1.name { return lhs.player1.name < rhs.player1.name }
            return lhs.player2.name < rhs.player2.name
        }
    }

    private static func recordTeam(_ team: [UUID], into counts: inout [String: Int]) {
        guard team.count == 2 else { return }
        counts[pairKey(team[0], team[1]), default: 0] += 1
    }
}

struct PlayerNextMatchWait: Identifiable {
    let player: SessionPlayer
    let isPlayingNow: Bool
    /// 試合中でないときの「次の試合まで」数（1 始まり）
    let waitUntilNext: Int?
    let nextMatchNo: Int?

    var id: UUID { player.id }
}

private enum MatchListNextMatchStats {
    static func waits(
        players: [SessionPlayer],
        scheduledMatches: [GeneratedMatch],
        courtCount: Int
    ) -> [PlayerNextMatchWait] {
        let ordered = MatchProgressHelper.orderedScheduled(scheduledMatches)

        return players
            .map { player in
                let playing = MatchProgressHelper.isPlayerInProgress(
                    playerId: player.id,
                    scheduled: scheduledMatches,
                    courtCount: courtCount
                )
                let index = ordered.firstIndex(where: { $0.playerIds.contains(player.id) })
                return PlayerNextMatchWait(
                    player: player,
                    isPlayingNow: playing,
                    waitUntilNext: playing
                        ? nil
                        : MatchProgressHelper.waitUntilNext(
                            playerId: player.id,
                            scheduled: scheduledMatches,
                            courtCount: courtCount
                        ),
                    nextMatchNo: index.map { ordered[$0].matchNo }
                )
            }
            .sorted { lhs, rhs in
                if lhs.isPlayingNow != rhs.isPlayingNow {
                    return lhs.isPlayingNow && !rhs.isPlayingNow
                }
                switch (lhs.waitUntilNext, rhs.waitUntilNext) {
                case let (l?, r?):
                    if l != r { return l < r }
                    return lhs.player.name < rhs.player.name
                case (nil, nil):
                    return lhs.player.name < rhs.player.name
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                }
            }
    }
}

// MARK: - 確認画面

struct PairCombinationView: View {
    @Bindable var sessionStore: SessionStore

    private var rows: [TeammatePair] {
        MatchListPairStats.teammatePairCounts(
            players: sessionStore.allKnownPlayers,
            matches: sessionStore.matches
        )
    }

    private var maxCount: Int {
        rows.map(\.count).max() ?? 0
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("参加者")
                    Spacer()
                    Text("\(sessionStore.players.count) 名")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("組み合わせ数")
                    Spacer()
                    Text("\(rows.count) 通り")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(rows) { row in
                    pairRow(row)
                }
            } header: {
                Text("ペアの組み合わせ")
            } footer: {
                Text("同じチーム（ペア）として出た組み合わせのみ表示しています。回数が少ない順です。")
            }
        }
        .navigationTitle("ペア組み合わせ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pairRow(_ row: TeammatePair) -> some View {
        HStack(spacing: 12) {
            pairNames(row)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(row.count) 回")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(row.count == maxCount && maxCount > 1 ? Color.orange : Color.primary)
            }
        }
        .padding(.vertical, 2)
    }

    private func pairNames(_ row: TeammatePair) -> some View {
        HStack(spacing: 2) {
            Text(row.player1.name)
                .font(.headline)
                .foregroundStyle(levelColor(row.player1.level))
            Text("・")
                .foregroundStyle(.secondary)
            Text(row.player2.name)
                .font(.headline)
                .foregroundStyle(levelColor(row.player2.level))
        }
    }

    private func levelColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }
}

struct PlayerNextMatchWaitView: View {
    @Bindable var sessionStore: SessionStore

    private var rows: [PlayerNextMatchWait] {
        MatchListNextMatchStats.waits(
            players: sessionStore.players,
            scheduledMatches: sessionStore.scheduledMatches,
            courtCount: sessionStore.courtCount
        )
    }

    private var inProgressCount: Int {
        sessionStore.inProgressMatchIds.count
    }

    private var scheduledCount: Int {
        sessionStore.scheduledMatches.count
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("試合中")
                    Spacer()
                    Text("\(inProgressCount) 試合")
                        .foregroundStyle(.orange)
                }
                HStack {
                    Text("未実施の試合")
                    Spacer()
                    Text("\(scheduledCount) 試合")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(rows) { row in
                    waitRow(row)
                }
            } header: {
                Text("次の試合まで")
            } footer: {
                Text("先頭のコート数ぶんが試合中です。それ以外は「次の試合まで 1、2、3…」と表示します。")
            }
        }
        .navigationTitle("次の試合まで")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func waitRow(_ row: PlayerNextMatchWait) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.player.name)
                    .font(.headline)
                    .foregroundStyle(levelColor(row.player.level))
                Text(row.player.level.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    if row.isPlayingNow {
                        Image(systemName: "sportscourt.fill")
                            .foregroundStyle(.orange)
                    }
                    Text(waitLabel(for: row))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(waitColor(for: row))
                }
                if let matchNo = row.nextMatchNo {
                    Text("第\(matchNo)試合")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func waitLabel(for row: PlayerNextMatchWait) -> String {
        if row.isPlayingNow { return "試合中" }
        guard let wait = row.waitUntilNext else { return "予定なし" }
        return "次の試合まで\(wait)"
    }

    private func waitColor(for row: PlayerNextMatchWait) -> Color {
        if row.isPlayingNow { return .orange }
        guard let wait = row.waitUntilNext else { return .secondary }
        if wait >= 3 { return .orange }
        return .primary
    }

    private func levelColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }
}

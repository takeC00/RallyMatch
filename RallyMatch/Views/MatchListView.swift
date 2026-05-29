import SwiftUI

struct MatchListView: View {
    @Bindable var sessionStore: SessionStore
    @State private var firebase = FirebaseManager.shared
    @State private var editingMatch: GeneratedMatch?
    @State private var editingPlayerId: UUID?
    @State private var showQR = false
    @State private var showAddPlayers = false

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

            Section {
                NavigationLink {
                    PlayerParticipationView(sessionStore: sessionStore)
                } label: {
                    Label("出場回数", systemImage: "person.3.sequence")
                }
                NavigationLink {
                    PairCombinationView(sessionStore: sessionStore)
                } label: {
                    Label("ペア組み合わせ", systemImage: "person.2.circle")
                }
                NavigationLink {
                    PlayerNextMatchWaitView(sessionStore: sessionStore)
                } label: {
                    Label("次の試合まで", systemImage: "clock.arrow.circlepath")
                }
            } header: {
                Text("確認")
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
                    Button("参加者を追加") { showAddPlayers = true }
                    Button("未実施のみ再生成") { regenerate() }
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
        .sheet(isPresented: $showAddPlayers) {
            AddSessionPlayersSheet(sessionStore: sessionStore)
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
                Text(match.status == .done ? "済" : "\(match.courtNo)コート")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(match.status == .done ? Color.gray.opacity(0.2) : Color.teal.opacity(0.15))
                    .clipShape(Capsule())
            }

            HStack(alignment: .center, spacing: 10) {
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
        .frame(maxWidth: .infinity)
    }

    private func color(for id: UUID) -> Color {
        sessionStore.playerLevel(for: id) == .experienced ? .red : .blue
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
    let matchesUntilNext: Int?
    let nextMatchNo: Int?

    var id: UUID { player.id }
}

private enum MatchListNextMatchStats {
    static func waits(
        players: [SessionPlayer],
        scheduledMatches: [GeneratedMatch]
    ) -> [PlayerNextMatchWait] {
        let ordered = scheduledMatches
            .filter { $0.status == .scheduled }
            .sorted { $0.matchNo < $1.matchNo }

        return players
            .map { player in
                if let index = ordered.firstIndex(where: { $0.playerIds.contains(player.id) }) {
                    return PlayerNextMatchWait(
                        player: player,
                        matchesUntilNext: index,
                        nextMatchNo: ordered[index].matchNo
                    )
                }
                return PlayerNextMatchWait(
                    player: player,
                    matchesUntilNext: nil,
                    nextMatchNo: nil
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.matchesUntilNext, rhs.matchesUntilNext) {
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
            players: sessionStore.players,
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
            scheduledMatches: sessionStore.scheduledMatches
        )
    }

    private var scheduledCount: Int {
        sessionStore.scheduledMatches.count
    }

    var body: some View {
        List {
            Section {
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
                Text("未実施の試合を上から順に数え、次に出場する試合の直前までの試合数です。0 は次の試合に出場します。")
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
                Text(waitLabel(for: row))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(waitColor(for: row))
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
        guard let wait = row.matchesUntilNext else { return "予定なし" }
        if wait == 0 { return "次の試合" }
        return "あと \(wait) 試合"
    }

    private func waitColor(for row: PlayerNextMatchWait) -> Color {
        guard let wait = row.matchesUntilNext else { return .secondary }
        if wait == 0 { return .green }
        if wait >= 3 { return .orange }
        return .primary
    }

    private func levelColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }
}

import SwiftUI

struct MatchListView: View {
    @Bindable var sessionStore: SessionStore
    @State private var firebase = FirebaseManager.shared
    @State private var editingMatch: GeneratedMatch?
    @State private var editingPlayerId: UUID?
    @State private var showQR = false
    @State private var showAddPlayers = false

    private var roundGroups: [(round: Int, matches: [GeneratedMatch])] {
        MatchRoundHelper.groups(
            from: sessionStore.matches,
            playerIds: sessionStore.players.map(\.id)
        )
    }

    var body: some View {
        List {
            if let err = sessionStore.errorMessage {
                Text(err).foregroundStyle(.red)
            }

            ForEach(roundGroups, id: \.round) { group in
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
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("QR") { showQR = true }
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
        let row = MatchRowView(match: match, sessionStore: sessionStore) { playerId in
            editingMatch = match
            editingPlayerId = playerId
        }

        if match.status == .scheduled {
            row
                .swipeActions(edge: .leading) {
                    Button {
                        markDoneUpTo(match)
                    } label: {
                        Label("実施済み", systemImage: "checkmark.circle")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteMatch(match)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
        } else {
            row
        }
    }

    private func regenerate() {
        sessionStore.regenerateScheduled()
        Task {
            try? await sessionStore.syncMatches()
        }
    }

    private func deleteMatch(_ match: GeneratedMatch) {
        sessionStore.deleteMatch(match.id)
        Task {
            if let sessionId = sessionStore.sessionId {
                try? await SessionSyncService.shared.deleteMatch(match.id, sessionId: sessionId)
            }
        }
    }

    private func markDoneUpTo(_ match: GeneratedMatch) {
        Task {
            try? await sessionStore.syncMarkDone(upTo: match.matchNo)
        }
    }

    private func syncAll() {
        Task {
            try? await sessionStore.syncAllMatches()
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

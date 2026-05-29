import SwiftUI

struct MatchListView: View {
    @Bindable var sessionStore: SessionStore
    @State private var firebase = FirebaseManager.shared
    @State private var editingMatch: GeneratedMatch?
    @State private var editingPlayerId: UUID?
    @State private var showQR = false
    @State private var doneUpToText = ""
    @State private var showDoneSheet = false
    @State private var showAddPlayers = false

    var body: some View {
        List {
            if let err = sessionStore.errorMessage {
                Text(err).foregroundStyle(.red)
            }

            if !sessionStore.doneMatches.isEmpty {
                Section("実施済み") {
                    ForEach(sessionStore.doneMatches) { match in
                        MatchRowView(match: match, sessionStore: sessionStore) { _ in }
                    }
                }
            }

            Section("予定") {
                ForEach(sessionStore.scheduledMatches) { match in
                    MatchRowView(match: match, sessionStore: sessionStore) { playerId in
                        editingMatch = match
                        editingPlayerId = playerId
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteMatch(match)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: moveMatches)
            }
        }
        .navigationTitle("試合一覧")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("QR") { showQR = true }
                Menu {
                    Button("参加者を追加") { showAddPlayers = true }
                    Button("未実施のみ再生成") { regenerate() }
                    Button("実施済みを確定…") { showDoneSheet = true }
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
        .alert("実施済み試合番号", isPresented: $showDoneSheet) {
            TextField("例: 5", text: $doneUpToText)
                .keyboardType(.numberPad)
            Button("確定") { markDone() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("第N試合までを実施済みにします")
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

    private func moveMatches(from source: IndexSet, to destination: Int) {
        sessionStore.moveMatch(from: source, to: destination)
        syncAll()
    }

    private func deleteMatch(_ match: GeneratedMatch) {
        sessionStore.deleteMatch(match.id)
        Task {
            if let sessionId = sessionStore.sessionId {
                try? await SessionSyncService.shared.deleteMatch(match.id, sessionId: sessionId)
            }
        }
    }

    private func regenerate() {
        sessionStore.regenerateScheduled()
        Task {
            try? await sessionStore.syncMatches()
        }
    }

    private func markDone() {
        guard let n = Int(doneUpToText) else { return }
        Task {
            try? await sessionStore.syncMarkDone(upTo: n)
        }
    }

    private func syncAll() {
        Task {
            try? await sessionStore.syncAllMatches()
        }
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

import SwiftUI
import SwiftData

struct SessionSetupView: View {
    let circle: Circle
    var sessionStore: SessionStore

    @Environment(\.modelContext) private var modelContext
    @Query private var allPlayers: [Player]
    @Bindable private var firebase = FirebaseManager.shared
    @State private var selectedIds: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss
    @State private var showAddPlayer = false
    @State private var isGenerating = false
    @State private var showGenerationHelp = false

    private var circlePlayers: [Player] {
        allPlayers.filter { $0.circleId == circle.id }.sorted { $0.name < $1.name }
    }

    private var selectedPlayers: [SessionPlayer] {
        circlePlayers
            .filter { selectedIds.contains($0.id) }
            .map(SessionPlayer.init(from:))
    }

    private var generationIssues: [GenerationValidation.Issue] {
        GenerationValidation.validate(
            players: selectedPlayers,
            mode: sessionStore.mode,
            matchPerPlayer: sessionStore.matchPerPlayer,
            courtCount: sessionStore.courtCount
        )
    }

    private var hasBlockingGenerationIssue: Bool {
        generationIssues.contains { $0.severity == .blocking }
    }

    private var canGenerate: Bool {
        selectedIds.count >= 4
            && !isGenerating
            && !hasBlockingGenerationIssue
            && firebase.isPlistConfigured
            && firebase.isLoggedIn
    }

    private var statusMessage: String {
        if selectedIds.count < 4 {
            return "当日参加者を4名以上選択してください（現在 \(selectedIds.count) 名）"
        }
        if let blocking = generationIssues.first(where: { $0.severity == .blocking }) {
            return blocking.message
        }
        if !firebase.isPlistConfigured {
            return "GoogleService-Info.plist が未設定です（Firebase の設定を確認）"
        }
        if !firebase.isLoggedIn {
            return "ログインしてください（RallyMate と同じアカウントで利用できます）"
        }
        return "試合を生成してクラウドに保存します"
    }

    var body: some View {
        @Bindable var store = sessionStore

        Form {
            Section {
                ForEach(circlePlayers) { player in
                    Toggle(isOn: binding(for: player.id)) {
                        HStack {
                            Text(player.name)
                            Spacer()
                            Text(player.level.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("参加者を追加") { showAddPlayer = true }
            } header: {
                Text("当日参加者")
            }

            Section {
                Picker("生成モード", selection: $store.mode) {
                    ForEach(GenerationMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                BlueValueStepperRow(
                    title: "1人あたり試合数",
                    value: $store.matchPerPlayer,
                    range: 1...20
                )
                BlueValueStepperRow(
                    title: "コート数",
                    value: $store.courtCount,
                    range: 1...20
                )
            } header: {
                GenerationConditionsSectionHeader(showHelp: $showGenerationHelp)
            }

            if !generationIssues.isEmpty {
                Section {
                    ForEach(generationIssues) { issue in
                        Label {
                            Text(issue.message)
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: issue.severity == .blocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(issue.severity == .blocking ? .red : .orange)
                    }
                } header: {
                    Text("生成前の確認")
                }
            }

            if let err = sessionStore.errorMessage {
                Section {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(sessionStore.isQuotaLimited ? .orange : .red)
                } header: {
                    Text(sessionStore.isQuotaLimited ? "クラウド連携を一時停止中" : "エラー")
                }
            }

            Section {
                Button {
                    Task { await prepareAndGenerate() }
                } label: {
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("生成・同期中…")
                        }
                    } else {
                        Text("試合を生成")
                    }
                }
                .disabled(!canGenerate)
            } footer: {
                Text(statusMessage)
                    .foregroundStyle(
                        canGenerate
                        ? Color.secondary
                        : (hasBlockingGenerationIssue ? Color.red : Color.orange)
                    )
            }
        }
        .navigationTitle("試合設定")
        .navigationDestination(isPresented: $showGenerationHelp) {
            GenerationSettingsHelpView()
        }
        .sheet(isPresented: $showAddPlayer) {
            NavigationStack {
                PlayerFormView(circle: circle, player: nil)
            }
        }
        .onAppear {
            sessionStore.circleId = circle.id
            if sessionStore.matches.isEmpty {
                _ = sessionStore.expireIfNeeded()
            }
            if selectedIds.isEmpty {
                selectedIds = Set(circlePlayers.map(\.id))
            }
        }
        .onChange(of: circlePlayers.count) { _, _ in
            if selectedIds.isEmpty, !circlePlayers.isEmpty {
                selectedIds = Set(circlePlayers.map(\.id))
            }
        }
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedIds.contains(id) },
            set: { on in
                if on { selectedIds.insert(id) } else { selectedIds.remove(id) }
            }
        )
    }

    private func prepareAndGenerate() async {
        isGenerating = true
        sessionStore.isCreatingSession = true
        defer {
            isGenerating = false
            sessionStore.isCreatingSession = false
        }

        guard firebase.isLoggedIn, firebase.uid != nil else {
            sessionStore.errorMessage = "ログインしてください。"
            return
        }

        sessionStore.clearSyncError()
        sessionStore.players = circlePlayers
            .filter { selectedIds.contains($0.id) }
            .map(SessionPlayer.init(from:))
        sessionStore.circleId = circle.id
        sessionStore.sessionId = AppConfig.stableSessionId(for: circle.id)
        sessionStore.expiresAt = AppConfig.defaultExpiresAt()
        sessionStore.generateMatches()

        guard !sessionStore.matches.isEmpty else {
            sessionStore.errorMessage = "試合を生成できませんでした。参加者が4名以上いるか確認してください。"
            return
        }

        guard let uid = firebase.uid else { return }
        do {
            // 旧仕様（主催者 UID を sessionId にしていた時代）の孤立セッションを掃除
            if let previousId = circle.activeSessionId,
               previousId != sessionStore.sessionId {
                do {
                    try await SessionSyncService.shared.deleteSession(sessionId: previousId)
                } catch {
                    // 自動削除済み・権限なしなどは新規作成を妨げない
                }
            }
            try await sessionStore.syncCreate(ownerUid: uid)
            circle.activeSessionId = sessionStore.sessionId
            try modelContext.save()
            sessionStore.errorMessage = nil
            dismiss()
        } catch {
            sessionStore.reportSyncError(error)
        }
    }
}

private struct GenerationConditionsSectionHeader: View {
    @Binding var showHelp: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("生成条件")
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.body)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
        .textCase(nil)
    }
}

private struct BlueValueStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title)
            Text("\(value)")
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
            Spacer()
            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
    }
}

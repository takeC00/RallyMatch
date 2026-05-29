import SwiftUI
import SwiftData

struct SessionSetupView: View {
    let circle: Circle
    @Bindable var sessionStore: SessionStore

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

    private var canGenerate: Bool {
        selectedIds.count >= 4 && !isGenerating
    }

    private var statusMessage: String {
        if selectedIds.count < 4 {
            return "当日参加者を4名以上選択してください（現在 \(selectedIds.count) 名）"
        }
        if !firebase.isPlistConfigured {
            return "GoogleService-Info.plist が未設定です（Firebase の設定を確認）"
        }
        if firebase.uid == nil {
            if let err = firebase.lastError {
                return "Firebase 未接続: \(err)"
            }
            return "Firebase に接続中…"
        }
        return "試合を生成してクラウドに保存します"
    }

    var body: some View {
        Form {
            Section {
                Text("当日に参加する方は、スイッチをオンにしてください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20))

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
                Picker("生成モード", selection: $sessionStore.mode) {
                    ForEach(GenerationMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                BlueValueStepperRow(
                    title: "1人あたり試合数",
                    value: $sessionStore.matchPerPlayer,
                    range: 1...20
                )
                BlueValueStepperRow(
                    title: "コート数",
                    value: $sessionStore.courtCount,
                    range: 1...20
                )
            } header: {
                GenerationConditionsSectionHeader(showHelp: $showGenerationHelp)
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
                    .foregroundStyle(canGenerate ? Color.secondary : Color.orange)
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
            if selectedIds.isEmpty {
                selectedIds = Set(circlePlayers.map(\.id))
            }
        }
        .onChange(of: circlePlayers.count) { _, _ in
            if selectedIds.isEmpty, !circlePlayers.isEmpty {
                selectedIds = Set(circlePlayers.map(\.id))
            }
        }
        .task {
            await firebase.signInAnonymouslyIfNeeded()
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
        defer { isGenerating = false }

        await firebase.signInAnonymouslyIfNeeded()
        guard firebase.uid != nil else {
            sessionStore.errorMessage = firebase.lastError ?? "Firebase に接続できません。匿名ログインが有効か確認してください。"
            return
        }

        sessionStore.players = circlePlayers
            .filter { selectedIds.contains($0.id) }
            .map(SessionPlayer.init(from:))
        sessionStore.circleId = circle.id
        sessionStore.sessionId = UUID().uuidString.lowercased()
        sessionStore.generateMatches()

        guard let uid = firebase.uid else { return }
        do {
            if let previousId = circle.activeSessionId, previousId != sessionStore.sessionId {
                try await SessionSyncService.shared.deleteSession(sessionId: previousId)
            }
            try await sessionStore.syncCreate(ownerUid: uid)
            circle.activeSessionId = sessionStore.sessionId
            try modelContext.save()
            sessionStore.errorMessage = nil
            sessionStore.showParticipationSummary = true
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

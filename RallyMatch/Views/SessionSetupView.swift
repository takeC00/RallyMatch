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
            return "GoogleService-Info.plist が未設定です（設定画面を確認）"
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
            Section("当日参加者") {
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
            }

            Section("生成条件") {
                Picker("生成モード", selection: $sessionStore.mode) {
                    ForEach(GenerationMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                Stepper("1人あたり試合数: \(sessionStore.matchPerPlayer)", value: $sessionStore.matchPerPlayer, in: 1...20)
                Stepper("コート数: \(sessionStore.courtCount)", value: $sessionStore.courtCount, in: 1...20)
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
        sessionStore.sessionId = UUID().uuidString.lowercased()
        sessionStore.generateMatches()

        guard let uid = firebase.uid else { return }
        do {
            try await sessionStore.syncCreate(ownerUid: uid)
            sessionStore.errorMessage = nil
            dismiss()
        } catch {
            sessionStore.errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI
import SwiftData

struct MatchGenerationTabView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Circle.createdAt) private var circles: [Circle]
    @Query private var allPlayers: [Player]
    @State private var showNewSessionConfirm = false
    @State private var isEndingSession = false

    private var hasActiveSession: Bool {
        sessionStore.sessionId != nil && !sessionStore.matches.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasActiveSession {
                    MatchListView(
                        sessionStore: sessionStore,
                        onRequestNewSession: { showNewSessionConfirm = true },
                        isEndingSession: isEndingSession
                    )
                } else if circles.isEmpty {
                    ContentUnavailableView(
                        "サークルがありません",
                        systemImage: "sportscourt",
                        description: Text("メンバー登録タブでサークルを作成してください")
                    )
                } else {
                    List(circles) { circle in
                        NavigationLink {
                            SessionSetupView(circle: circle, sessionStore: sessionStore)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(circle.name)
                                        .font(.headline)
                                    Text("\(playerCount(for: circle)) 名登録")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if playerCount(for: circle) < 4 {
                                    Text("4名以上必要")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .disabled(playerCount(for: circle) < 4)
                    }
                }
            }
            .navigationTitle(hasActiveSession ? "試合一覧" : "試合生成")
            .confirmationDialog(
                "新しい試合を作成しますか？",
                isPresented: $showNewSessionConfirm,
                titleVisibility: .visible
            ) {
                Button("破棄して新規作成", role: .destructive) {
                    Task { await endCurrentSessionAndReset() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("進行中の試合はクラウドからも削除され、元に戻せません。他サークルの QR や試合データには影響しません。")
            }
            .onAppear {
                clearExpiredSessionIfNeeded()
            }
        }
    }

    private func clearExpiredSessionIfNeeded() {
        guard let circleId = sessionStore.expireIfNeeded() else { return }
        if let circle = circles.first(where: { $0.id == circleId }),
           circle.activeSessionId != nil {
            circle.activeSessionId = nil
            try? modelContext.save()
        }
    }

    private func playerCount(for circle: Circle) -> Int {
        allPlayers.filter { $0.circleId == circle.id }.count
    }

    private func endCurrentSessionAndReset() async {
        isEndingSession = true
        defer { isEndingSession = false }

        let sessionId = sessionStore.sessionId
        let circleId = sessionStore.circleId

        if let sessionId {
            do {
                try await SessionSyncService.shared.deleteSession(sessionId: sessionId)
            } catch {
                sessionStore.reportSyncError(error, context: "クラウドの試合削除に失敗しました")
                return
            }
        }

        if let circleId,
           let circle = circles.first(where: { $0.id == circleId }),
           circle.activeSessionId == sessionId {
            circle.activeSessionId = nil
            try? modelContext.save()
        }

        sessionStore.reset()
    }
}

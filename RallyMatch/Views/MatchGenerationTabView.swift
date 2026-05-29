import SwiftUI
import SwiftData

struct MatchGenerationTabView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Query(sort: \Circle.createdAt) private var circles: [Circle]
    @Query private var allPlayers: [Player]

    private var hasActiveSession: Bool {
        sessionStore.sessionId != nil && !sessionStore.matches.isEmpty
    }

    var body: some View {
        @Bindable var store = sessionStore

        NavigationStack {
            Group {
                if hasActiveSession {
                    MatchListView(sessionStore: sessionStore)
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
            .toolbar {
                if hasActiveSession {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("新規") {
                            sessionStore.reset()
                        }
                    }
                }
            }
            .sheet(isPresented: $store.showParticipationSummary) {
                NavigationStack {
                    PlayerParticipationView(sessionStore: sessionStore)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("閉じる") {
                                    store.showParticipationSummary = false
                                }
                            }
                        }
                }
            }
        }
    }

    private func playerCount(for circle: Circle) -> Int {
        allPlayers.filter { $0.circleId == circle.id }.count
    }
}

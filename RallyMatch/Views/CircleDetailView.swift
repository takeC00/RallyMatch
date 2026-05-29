import SwiftUI
import SwiftData

struct CircleDetailView: View {
    @Bindable var circle: Circle
    @Bindable var sessionStore: SessionStore

    @Environment(\.modelContext) private var modelContext
    @Query private var allPlayers: [Player]

    private var players: [Player] {
        allPlayers.filter { $0.circleId == circle.id }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section("参加者") {
                if players.isEmpty {
                    Text("参加者を追加してください")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(players) { player in
                        NavigationLink {
                            PlayerFormView(circle: circle, player: player)
                        } label: {
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text(player.level.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deletePlayers)
                }
            }

            Section {
                NavigationLink {
                    SessionSetupView(circle: circle, sessionStore: sessionStore)
                } label: {
                    Label("今日の試合", systemImage: "sportscourt")
                }
                .disabled(players.count < 4)
            } footer: {
                if players.count < 4 {
                    Text("試合生成には4名以上必要です")
                }
            }
        }
        .navigationTitle(circle.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PlayerFormView(circle: circle, player: nil)
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
    }

    private func deletePlayers(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(players[index])
        }
        try? modelContext.save()
    }
}

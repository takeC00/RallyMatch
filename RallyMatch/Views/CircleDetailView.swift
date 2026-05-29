import SwiftUI
import SwiftData

struct CircleDetailView: View {
    @Bindable var circle: Circle

    @Environment(\.modelContext) private var modelContext
    @Query private var allPlayers: [Player]

    private var players: [Player] {
        allPlayers.filter { $0.circleId == circle.id }.sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if players.isEmpty {
                ContentUnavailableView(
                    "参加者がいません",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("右上の＋から参加者を追加してください")
                )
            } else {
                List {
                    Section("参加者") {
                        ForEach(players) { player in
                            NavigationLink {
                                PlayerFormView(circle: circle, player: player)
                            } label: {
                                HStack {
                                    Text(player.name)
                                        .foregroundStyle(levelColor(player.level))
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

    private func levelColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }

    private func deletePlayers(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(players[index])
        }
        try? modelContext.save()
    }
}

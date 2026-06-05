import SwiftUI

struct CircleDetailView: View {
    let circle: CloudCircle

    @Bindable private var roster = CircleRosterRepository.shared

    private var players: [RosterPlayer] {
        roster.players(for: circle.id)
    }

    var body: some View {
        Group {
            if roster.isLoadingCircleIds.contains(circle.id) && players.isEmpty {
                ProgressView("読み込み中...")
            } else if players.isEmpty {
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

                    Section("サークル情報") {
                        LabeledContent("競技", value: circle.sportName)
                        if !circle.location.isEmpty {
                            LabeledContent("活動場所", value: circle.location)
                        }
                        LabeledContent("招待コード", value: circle.circleCode)
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
        .refreshable {
            await roster.refresh(circleId: circle.id)
        }
        .task {
            await roster.refresh(circleId: circle.id)
        }
    }

    private func levelColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }

    private func deletePlayers(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let player = players[index]
                try? await roster.deletePlayer(player)
            }
        }
    }
}

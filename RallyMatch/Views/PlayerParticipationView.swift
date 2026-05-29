import SwiftUI

struct PlayerParticipationView: View {
    @Bindable var sessionStore: SessionStore

    private var rows: [PlayerParticipation] {
        ParticipationStats.counts(
            players: sessionStore.players,
            matches: sessionStore.matches
        )
    }

    private var target: Int {
        max(1, sessionStore.matchPerPlayer)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("目標")
                    Spacer()
                    Text("1人あたり \(target) 試合")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("参加者")
                    Spacer()
                    Text("\(sessionStore.players.count) 名")
                        .foregroundStyle(.secondary)
                }
            }

            Section("出場回数") {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.player.name)
                                .font(.headline)
                                .foregroundStyle(levelColor(row.player.level))
                            Text(row.player.level.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(row.matchCount) 試合")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(row.matchCount >= target ? .primary : .orange)
                            Text("\(row.matchCount)/\(target)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                Text("試合数が少ない順に表示しています")
            }
        }
        .navigationTitle("出場回数")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func levelColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }
}

#Preview {
    NavigationStack {
        PlayerParticipationView(sessionStore: {
            let store = SessionStore()
            store.matchPerPlayer = 3
            store.players = [
                SessionPlayer(name: "田中", level: .beginner),
                SessionPlayer(name: "佐藤", level: .experienced),
            ]
            return store
        }())
    }
}

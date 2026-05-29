import SwiftUI
import SwiftData

struct PlayerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let circle: Circle
    var player: Player?

    @State private var name = ""
    @State private var level: PlayerLevel = .experienced
    @State private var errorMessage: String?

    var body: some View {
        Form {
            TextField("名前", text: $name)
            Picker("レベル", selection: $level) {
                ForEach(PlayerLevel.allCases) { lv in
                    Text(lv.label).tag(lv)
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .navigationTitle(player == nil ? "参加者追加" : "参加者編集")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let player {
                name = player.name
                level = player.level
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<Player>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let duplicate = existing.contains {
            $0.circleId == circle.id &&
            $0.name == trimmed &&
            $0.id != player?.id
        }
        if duplicate {
            errorMessage = "同じ名前の参加者が既にいます"
            return
        }

        if let player {
            player.name = trimmed
            player.level = level
        } else {
            let p = Player(circleId: circle.id, name: trimmed, level: level)
            p.circle = circle
            modelContext.insert(p)
        }
        try? modelContext.save()
        dismiss()
    }
}

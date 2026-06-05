import SwiftUI

struct PlayerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var roster = CircleRosterRepository.shared

    let circle: CloudCircle
    var player: RosterPlayer?

    @State private var name = ""
    @State private var level: PlayerLevel = .experienced
    @State private var errorMessage: String?
    @State private var isSaving = false

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
                Button("保存") {
                    Task { await save() }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .overlay {
            if isSaving {
                ProgressView()
            }
        }
    }

    private func save() async {
        errorMessage = ""
        isSaving = true
        defer { isSaving = false }

        do {
            if let player {
                try await roster.updatePlayer(player, name: name, level: level)
            } else {
                _ = try await roster.addPlayer(circleId: circle.id, name: name, level: level)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

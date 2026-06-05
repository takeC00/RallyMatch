import SwiftUI

/// 今日だけ参加の追加・編集（Match）
struct DayParticipantFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var dayStore = DayParticipantStore.shared

    let circleId: String
    var participant: SessionPlayer?
    var onAdd: ((SessionPlayer) -> Void)?
    var onSaved: (() -> Void)?

    @State private var name = ""
    @State private var level: PlayerLevel = .experienced
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var isEditing: Bool { participant != nil }

    var body: some View {
        Form {
            Section {
                TextField("表示名", text: $name)
                Picker("レベル", selection: $level) {
                    ForEach(PlayerLevel.allCases) { lv in
                        Text(lv.label).tag(lv)
                    }
                }
            } header: {
                Text("今日だけ参加")
            } footer: {
                Text("その日の試合生成・人数合わせ専用です。日本時間で日付が変わると消えます。")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle(isEditing ? "今日だけ参加編集" : "今日だけ参加")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let participant {
                name = participant.name
                level = participant.level
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "保存" : "追加") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .overlay {
            if isSaving { ProgressView() }
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = DayParticipantError.invalidName.localizedDescription
            return
        }

        do {
            if let participant {
                let updated = SessionPlayer(id: participant.id, name: trimmed, level: level)
                try dayStore.update(updated, circleId: circleId)
            } else {
                let player = SessionPlayer(name: trimmed, level: level)
                if let onAdd {
                    onAdd(player)
                } else {
                    dayStore.add(player, circleId: circleId)
                }
            }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

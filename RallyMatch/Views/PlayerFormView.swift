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
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    private var isEditingVisitor: Bool { player != nil && player?.isLinkedAccount == false }

    var body: some View {
        Form {
            TextField("名前", text: $name)
            Picker("レベル", selection: $level) {
                ForEach(PlayerLevel.allCases) { lv in
                    Text(lv.label).tag(lv)
                }
            }
            if let player, !player.isLinkedAccount {
                Section {
                    LabeledContent("登録日") {
                        Text(VisitorExpiry.registrationDayLabel(for: player.createdAt))
                    }
                } footer: {
                    Text("日本時間で日付が変わると、次回 Match を開いたときに自動削除されます。")
                }
            }

            if isEditingVisitor {
                Section {
                    Button("Visitorを削除", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(isDeleting || isSaving)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .navigationTitle(player == nil ? "Visitor追加" : "Visitor編集")
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
            if isSaving || isDeleting {
                ProgressView()
            }
        }
        .confirmationDialog(
            "Visitorを削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                Task { await deleteVisitor() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let player {
                Text("「\(player.name)」を削除します。この操作は取り消せません。")
            }
        }
    }

    private func deleteVisitor() async {
        guard let player, !player.isLinkedAccount else { return }

        errorMessage = ""
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await roster.deleteVisitor(player)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
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

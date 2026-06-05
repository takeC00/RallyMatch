import SwiftUI

/// サークルメンバー（招待コード参加）の編集
struct RegisteredMemberFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var membersRepo = CircleMembersRepository.shared
    @Bindable private var roster = CircleRosterRepository.shared
    @Bindable private var firebase = FirebaseManager.shared

    let circle: CloudCircle
    let member: CloudCircleMember
    var existingPlayer: RosterPlayer?
    var onSaved: (() -> Void)?

    @State private var rating = ""
    @State private var level: PlayerLevel = .experienced
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private var canRemove: Bool {
        guard let uid = firebase.uid else { return false }
        if member.role == "owner" || member.userId == circle.ownerId { return false }
        if member.userId == uid { return false }
        return firebase.isCircleOwner(circle)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("表示名", value: member.userName)
                TextField("レート", text: $rating)
                    .keyboardType(.numberPad)
                Picker("レベル", selection: $level) {
                    ForEach(PlayerLevel.allCases) { lv in
                        Text(lv.label).tag(lv)
                    }
                }
                TextField("備考（任意）", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("サークルメンバー")
            } footer: {
                Text("表示名は RallyMate / Hub のアカウント設定で変更します。レート・レベルは試合生成と Mate のランキングに反映されます。")
            }

            if canRemove {
                Section {
                    Button("メンバーを削除", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(isSaving)
                } footer: {
                    Text("サークルから除外します。Mate の過去試合履歴は残ります。")
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("メンバー編集")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rating = "\(member.rating)"
            level = existingPlayer?.level ?? member.level ?? .experienced
            notes = member.notes ?? ""
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
        }
        .overlay {
            if isSaving { ProgressView() }
        }
        .confirmationDialog(
            "メンバーを削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                Task { await deleteMember() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(member.userName)」をサークルから除外します。")
        }
        .rallyDarkFormScreen()
    }

    private func save() async {
        errorMessage = ""
        isSaving = true
        defer { isSaving = false }

        let ratingValue = Int(rating) ?? member.rating

        do {
            try await membersRepo.updateRegisteredMember(
                member,
                rating: ratingValue,
                level: level,
                notes: notes.nilIfEmpty
            )
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteMember() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await membersRepo.removeMember(member)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

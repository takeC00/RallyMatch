import SwiftUI

/// 手動登録メンバー作成・編集
struct ManualMemberFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var membersRepo = CircleMembersRepository.shared

    let circle: CloudCircle
    var member: CloudCircleMember?
    var createdBy: String
    var onSaved: (() -> Void)?

    @State private var displayName = ""
    @State private var rating = "1500"
    @State private var level: PlayerLevel = .experienced
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { member != nil }

    var body: some View {
        Form {
            Section {
                TextField("表示名", text: $displayName)
                TextField("初期レート", text: $rating)
                    .keyboardType(.numberPad)
                Picker("レベル", selection: $level) {
                    ForEach(PlayerLevel.allCases) { lv in
                        Text(lv.label).tag(lv)
                    }
                }
                TextField("備考（任意）", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("手動登録メンバー")
            } footer: {
                Text("アプリアカウントを持たない常連メンバーをサークルに永続登録します。レーティング・試合履歴の対象になります。")
            }

            if isEditing {
                Section {
                    Button("メンバーを削除", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(isSaving)
                } footer: {
                    Text("削除すると試合生成の名簿からも外れます。Mate の過去試合履歴は残ります。")
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle(isEditing ? "手動登録編集" : "手動登録メンバー")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let member {
                displayName = member.userName
                rating = "\(member.rating)"
                level = member.level ?? .experienced
                notes = member.notes ?? ""
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task { await save() }
                }
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
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
        }
    }

    private func save() async {
        errorMessage = ""
        isSaving = true
        defer { isSaving = false }

        let ratingValue = Int(rating) ?? RatingDefaults.initialRating

        do {
            if let member {
                try await membersRepo.updateManualMember(
                    member,
                    displayName: displayName,
                    rating: ratingValue,
                    level: level,
                    notes: notes
                )
            } else {
                _ = try await membersRepo.createManualMember(
                    circleId: circle.id,
                    displayName: displayName,
                    rating: ratingValue,
                    level: level,
                    notes: notes.nilIfEmpty,
                    createdBy: createdBy
                )
            }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteMember() async {
        guard let member else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await membersRepo.deactivateManualMember(member)
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

private enum RatingDefaults {
    static let initialRating = 1500
}

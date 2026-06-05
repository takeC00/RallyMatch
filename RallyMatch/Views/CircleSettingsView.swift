import SwiftUI

struct CircleSettingsView: View {
    let circle: CloudCircle
    var onDeleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Bindable private var firebase = FirebaseManager.shared
    @Bindable private var roster = CircleRosterRepository.shared

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage = ""

    private var canDelete: Bool {
        firebase.isCircleOwner(circle)
    }

    var body: some View {
        Form {
            Section("招待コード") {
                HStack {
                    Text(circle.circleCode)
                        .font(.title3.monospaced().bold())
                    Spacer()
                    ShareLink(item: "Rally 招待コード: \(circle.circleCode)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }

            Section("サークル情報") {
                LabeledContent("名前", value: circle.name)
                LabeledContent("競技", value: circle.sportName.isEmpty ? "—" : circle.sportName)
                if !circle.location.isEmpty {
                    LabeledContent("活動場所", value: circle.location)
                }
                if !circle.description.isEmpty {
                    LabeledContent("説明", value: circle.description)
                }
                LabeledContent("メンバー数", value: "\(circle.memberCount) 人")
                LabeledContent("登録参加者", value: "\(roster.players(for: circle.id).count) 名")
            }

            if canDelete {
                Section {
                    Button("サークルを削除", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text("オーナーのみ削除できます。試合セッション・参加者名簿・RallyMate の試合履歴も削除されます。")
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("サークル設定")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isDeleting {
                ProgressView("削除中...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .confirmationDialog(
            "サークルを削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                Task { await deleteCircle() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(circle.name)」と関連データがすべて削除されます。この操作は取り消せません。")
        }
    }

    private func deleteCircle() async {
        isDeleting = true
        errorMessage = ""
        defer { isDeleting = false }

        do {
            try await firebase.deleteCircle(circle)
            if let onDeleted {
                onDeleted()
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

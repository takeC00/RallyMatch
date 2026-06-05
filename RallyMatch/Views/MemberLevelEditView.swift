import SwiftUI

struct MemberLevelEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var roster = CircleRosterRepository.shared

    let circle: CloudCircle
    let member: CloudCircleMember
    var existingPlayer: RosterPlayer?

    @State private var level: PlayerLevel = .experienced
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                LabeledContent("名前", value: member.userName)
                if member.rating > 0 {
                    LabeledContent("Rating", value: "\(member.rating)")
                }
            } header: {
                Text("メンバー")
            } footer: {
                Text("表示名は RallyMate / Hub のアカウント設定に連動します。")
            }

            Section {
                Picker("レベル", selection: $level) {
                    ForEach(PlayerLevel.allCases) { lv in
                        Text(lv.label).tag(lv)
                    }
                }
            } header: {
                Text("試合生成用レベル")
            } footer: {
                Text("経験者・初心者の設定は RallyMatch の試合組み合わせにのみ使われます。")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("レベル編集")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            level = existingPlayer?.level ?? .experienced
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
            if let existingPlayer {
                try await roster.updateLevel(existingPlayer, level: level)
            } else {
                try await roster.upsertLinkedMember(member, level: level)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

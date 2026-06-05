import SwiftUI

/// 参加者追加時の種別選択
struct ParticipantAddSheet: View {
    let circle: CloudCircle
    let createdBy: String
    var onDayParticipantAdded: ((SessionPlayer) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Bindable private var dayStore = DayParticipantStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ManualMemberFormView(
                            circle: circle,
                            createdBy: createdBy,
                            onSaved: { dismiss() }
                        )
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("メンバーとして追加")
                                    .font(.headline)
                                Text("手動登録メンバーを作成（常連・Androidユーザーなど）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundStyle(.orange)
                        }
                    }

                    NavigationLink {
                        DayParticipantFormView(
                            circleId: circle.id,
                            onAdd: { player in
                                addDayParticipant(player)
                                dismiss()
                            }
                        )
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("今日だけ参加")
                                    .font(.headline)
                                Text("その日の試合生成・人数合わせ用")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.blue)
                        }
                    }
                } footer: {
                    Text("アカウントメンバーは招待コード参加で自動的に一覧に表示されます。「今日だけ参加」は当日の試合設定でのみ使われ、翌日は消えます。")
                }

                let dayParticipants = dayStore.participants(for: circle.id)
                if !dayParticipants.isEmpty {
                    Section("今日だけ参加（\(dayParticipants.count) 名）") {
                        ForEach(dayParticipants) { participant in
                            NavigationLink {
                                DayParticipantFormView(
                                    circleId: circle.id,
                                    participant: participant
                                )
                            } label: {
                                HStack {
                                    Text(participant.name)
                                    Spacer()
                                    Text(participant.level.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("参加者を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func addDayParticipant(_ player: SessionPlayer) {
        if let onDayParticipantAdded {
            onDayParticipantAdded(player)
        } else {
            dayStore.add(player, circleId: circle.id)
        }
    }
}

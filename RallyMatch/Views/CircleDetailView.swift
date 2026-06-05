import SwiftUI

struct CircleDetailView: View {
    let circle: CloudCircle

    @Environment(\.dismiss) private var dismiss
    @Bindable private var roster = CircleRosterRepository.shared
    @Bindable private var membersRepo = CircleMembersRepository.shared

    private var accountMembers: [CloudCircleMember] {
        membersRepo.members(for: circle.id)
    }

    private var guestPlayers: [RosterPlayer] {
        roster.players(for: circle.id).filter { !$0.isLinkedAccount }
    }

    private var isLoading: Bool {
        (roster.isLoadingCircleIds.contains(circle.id)
            || membersRepo.isLoadingCircleIds.contains(circle.id))
        && accountMembers.isEmpty
        && guestPlayers.isEmpty
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if accountMembers.isEmpty && guestPlayers.isEmpty {
                ContentUnavailableView(
                    "参加者がいません",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("招待コードで参加するか、ゲスト参加者を追加してください")
                )
            } else {
                List {
                    if !accountMembers.isEmpty {
                        Section {
                            ForEach(accountMembers) { member in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.userName)
                                            .font(.headline)
                                        Text(roleLabel(member.role))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(member.rating)")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } header: {
                            Text("アカウントメンバー")
                        } footer: {
                            Text("RallyMate・RallyHub で参加したメンバーです。試合生成にも利用できます。")
                        }
                    }

                    Section {
                        ForEach(guestPlayers) { player in
                            NavigationLink {
                                PlayerFormView(circle: circle, player: player)
                            } label: {
                                HStack {
                                    Text(player.name)
                                        .foregroundStyle(levelColor(player.level))
                                    Spacer()
                                    Text(player.level.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteGuestPlayers)
                    } header: {
                        Text("ゲスト参加者")
                    } footer: {
                        Text("アカウント未登録の参加者用です。Mate のランキングには表示されません。")
                    }

                    Section("サークル情報") {
                        LabeledContent("競技", value: circle.sportName)
                        if !circle.location.isEmpty {
                            LabeledContent("活動場所", value: circle.location)
                        }
                        LabeledContent("招待コード", value: circle.circleCode)
                        LabeledContent("メンバー数", value: "\(circle.memberCount) 人")
                    }
                }
            }
        }
        .navigationTitle(circle.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PlayerFormView(circle: circle, player: nil)
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("ゲスト参加者を追加")
            }

            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    CircleSettingsView(circle: circle, onDeleted: { dismiss() })
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("サークル設定")
            }
        }
        .refreshable {
            await reload()
        }
        .task {
            await reload()
        }
    }

    private func reload() async {
        await membersRepo.refresh(circleId: circle.id)
        try? await membersRepo.syncMembersToRoster(circleId: circle.id)
        await roster.refresh(circleId: circle.id)
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "admin", "owner": "管理者"
        default: "メンバー"
        }
    }

    private func levelColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }

    private func deleteGuestPlayers(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let player = guestPlayers[index]
                try? await roster.deletePlayer(player)
            }
        }
    }
}

import SwiftUI

struct CircleDetailView: View {
    let circle: CloudCircle

    @Environment(\.dismiss) private var dismiss
    @Bindable private var roster = CircleRosterRepository.shared
    @Bindable private var membersRepo = CircleMembersRepository.shared

    @State private var showVisitorHelp = false
    @State private var visitorPendingDelete: RosterPlayer?
    @State private var showDeleteVisitorConfirm = false

    private var accountMembers: [CloudCircleMember] {
        membersRepo.members(for: circle.id)
    }

    private var linkedAccountPlayers: [RosterPlayer] {
        roster.players(for: circle.id).filter(\.isLinkedAccount)
    }

    private var guestPlayers: [RosterPlayer] {
        roster.players(for: circle.id).filter { !$0.isLinkedAccount }
    }

    private struct AccountMemberRow: Identifiable {
        let member: CloudCircleMember
        let player: RosterPlayer?

        var id: String { member.id }
    }

    private var accountMemberRows: [AccountMemberRow] {
        accountMembers.map { member in
            AccountMemberRow(
                member: member,
                player: roster.linkedPlayer(circleId: circle.id, userId: member.userId)
            )
        }
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
                    description: Text("招待コードで参加するか、Visitor を追加してください")
                )
            } else {
                List {
                    if !accountMemberRows.isEmpty {
                        Section {
                            ForEach(accountMemberRows) { row in
                                NavigationLink {
                                    MemberLevelEditView(
                                        circle: circle,
                                        member: row.member,
                                        existingPlayer: row.player
                                    )
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(row.member.userName)
                                                .font(.headline)
                                                .foregroundStyle(levelColor(row.player?.level ?? .experienced))
                                            Text(roleLabel(row.member.role))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text((row.player?.level ?? .experienced).label)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(levelBadgeColor(row.player?.level ?? .experienced).opacity(0.15))
                                            .foregroundStyle(levelColor(row.player?.level ?? .experienced))
                                            .clipShape(Capsule())
                                        Text("\(row.member.rating)")
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text("アカウントメンバー")
                        } footer: {
                            Text("タップして経験者・初心者を編集できます。試合生成の組み合わせに反映されます。")
                        }
                    }

                    Section {
                        ForEach(guestPlayers) { player in
                            NavigationLink {
                                PlayerFormView(circle: circle, player: player)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(player.name)
                                            .foregroundStyle(levelColor(player.level))
                                        Spacer()
                                        Text(player.level.label)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("登録: \(VisitorExpiry.registrationDayLabel(for: player.createdAt))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    visitorPendingDelete = player
                                    showDeleteVisitorConfirm = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    visitorPendingDelete = player
                                    showDeleteVisitorConfirm = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        VisitorSectionHeader(showHelp: $showVisitorHelp, title: "Visitor")
                    } footer: {
                        Text("アカウント未登録の参加者です。日本時間で日付が変わると、次回 Match を開いたときに自動で削除されます。左スワイプまたは長押しで手動削除もできます。")
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
                .accessibilityLabel("Visitor追加")
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
        .navigationDestination(isPresented: $showVisitorHelp) {
            VisitorHelpView()
        }
        .confirmationDialog(
            "Visitorを削除しますか？",
            isPresented: $showDeleteVisitorConfirm,
            presenting: visitorPendingDelete
        ) { player in
            Button("削除", role: .destructive) {
                Task { await deleteVisitor(player) }
            }
            Button("キャンセル", role: .cancel) {
                visitorPendingDelete = nil
            }
        } message: { player in
            Text("「\(player.name)」を削除します。この操作は取り消せません。")
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

    private func levelBadgeColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }

    private func deleteVisitor(_ player: RosterPlayer) async {
        do {
            try await roster.deleteVisitor(player)
            visitorPendingDelete = nil
        } catch {
            roster.lastError = error.localizedDescription
        }
    }
}

import SwiftUI

struct CircleDetailView: View {
    let circle: CloudCircle

    @Environment(\.dismiss) private var dismiss
    @Bindable private var roster = CircleRosterRepository.shared
    @Bindable private var membersRepo = CircleMembersRepository.shared
    @Bindable private var firebase = FirebaseManager.shared
    @Bindable private var dayStore = DayParticipantStore.shared

    @State private var showParticipantHelp = false
    @State private var showAddParticipant = false
    @State private var legacyPendingDelete: RosterPlayer?
    @State private var showDeleteLegacyConfirm = false
    @State private var pendingMemberDelete: CloudCircleMember?
    @State private var showDeleteMemberConfirm = false
    @State private var isDeletingMember = false

    private var registeredMembers: [CloudCircleMember] {
        membersRepo.registeredMembers(for: circle.id)
    }

    private var manualMembers: [CloudCircleMember] {
        membersRepo.manualMembers(for: circle.id)
    }

    private var todayDayParticipants: [SessionPlayer] {
        _ = dayStore.revision
        return dayStore.participants(for: circle.id)
    }

    private var legacyDayVisitors: [RosterPlayer] {
        roster.players(for: circle.id).filter(\.isLegacyDayVisitor)
    }

    private struct MemberRow: Identifiable {
        let member: CloudCircleMember
        let player: RosterPlayer?

        var id: String { member.id }
    }

    private func memberRows(_ members: [CloudCircleMember]) -> [MemberRow] {
        members.map { member in
            MemberRow(member: member, player: roster.rosterPlayer(for: member))
        }
    }

    private var isLoading: Bool {
        (roster.isLoadingCircleIds.contains(circle.id)
            || membersRepo.isLoadingCircleIds.contains(circle.id))
        && registeredMembers.isEmpty
        && manualMembers.isEmpty
        && legacyDayVisitors.isEmpty
        && todayDayParticipants.isEmpty
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("読み込み中...")
            } else if registeredMembers.isEmpty && manualMembers.isEmpty && legacyDayVisitors.isEmpty && todayDayParticipants.isEmpty {
                ContentUnavailableView(
                    "参加者がいません",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("招待コードで参加するか、手動登録メンバーを追加してください")
                )
            } else {
                List {
                    if !registeredMembers.isEmpty {
                        memberSection(
                            title: "サークルメンバー",
                            footer: "タップして経験者・初心者を編集できます。Hub / Mate で参加すると自動的に表示されます。",
                            rows: memberRows(registeredMembers),
                            roleLabel: roleLabel
                        )
                    }

                    if !manualMembers.isEmpty {
                        memberSection(
                            title: "サークルメンバー（手動追加）",
                            footer: "アプリ未登録の常連メンバーです。レーティング・試合履歴の永続管理対象です。",
                            rows: memberRows(manualMembers),
                            roleLabel: { _ in "手動追加" }
                        )
                    }

                    if !todayDayParticipants.isEmpty {
                        Section {
                            ForEach(todayDayParticipants) { participant in
                                NavigationLink {
                                    DayParticipantFormView(
                                        circleId: circle.id,
                                        participant: participant
                                    )
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(participant.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text("今日だけ参加")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                        Spacer()
                                        levelBadge(participant.level)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        dayStore.remove(id: participant.id, circleId: circle.id)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text("今日だけ参加")
                        } footer: {
                            Text("試合設定画面でも選択できます。日本時間で日付が変わると消えます。")
                        }
                    }

                    if !legacyDayVisitors.isEmpty {
                        Section {
                            ForEach(legacyDayVisitors) { player in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(player.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        levelBadge(player.level)
                                    }
                                    Text("旧データ（次回起動時に自動削除）")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        legacyPendingDelete = player
                                        showDeleteLegacyConfirm = true
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text("今日だけ参加（旧データ）")
                        }
                    }

                }
            }
        }
        .navigationTitle(circle.name)
        .rallyDarkScreenBackground()
        .rallyDarkNavigationBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddParticipant = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("参加者を追加")
            }
        }
        .sheet(isPresented: $showAddParticipant) {
            if let uid = firebase.uid {
                ParticipantAddSheet(circle: circle, createdBy: uid)
            }
        }
        .onChange(of: showAddParticipant) { _, isShowing in
            if !isShowing {
                Task { await reload() }
            }
        }
        .navigationDestination(isPresented: $showParticipantHelp) {
            VisitorHelpView()
        }
        .confirmationDialog(
            "削除しますか？",
            isPresented: $showDeleteLegacyConfirm,
            presenting: legacyPendingDelete
        ) { player in
            Button("削除", role: .destructive) {
                Task { await deleteLegacyVisitor(player) }
            }
            Button("キャンセル", role: .cancel) {
                legacyPendingDelete = nil
            }
        } message: { player in
            Text("「\(player.name)」を削除します。")
        }
        .confirmationDialog(
            "メンバーを削除しますか？",
            isPresented: $showDeleteMemberConfirm,
            presenting: pendingMemberDelete
        ) { member in
            Button("削除", role: .destructive) {
                Task { await deleteMember(member) }
            }
            Button("キャンセル", role: .cancel) {
                pendingMemberDelete = nil
            }
        } message: { member in
            if member.isManual {
                Text("「\(member.userName)」を削除します。過去の試合履歴は残ります。")
            } else {
                Text("「\(member.userName)」をサークルから除外します。")
            }
        }
        .refreshable {
            await reload()
        }
        .task {
            await reload()
        }
    }

    @ViewBuilder
    private func memberSection(
        title: String,
        footer: String,
        rows: [MemberRow],
        roleLabel: @escaping (String) -> String
    ) -> some View {
        Section {
            ForEach(rows) { row in
                NavigationLink {
                    if row.member.isManual {
                        ManualMemberFormView(
                            circle: circle,
                            member: row.member,
                            createdBy: firebase.uid ?? ""
                        )
                    } else {
                        RegisteredMemberFormView(
                            circle: circle,
                            member: row.member,
                            existingPlayer: row.player
                        )
                    }
                } label: {
                    memberRowLabel(row: row, role: roleLabel(row.member.role))
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if canRemoveMember(row.member) {
                        Button(role: .destructive) {
                            pendingMemberDelete = row.member
                            showDeleteMemberConfirm = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }

    private func memberRowLabel(row: MemberRow, role: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.member.userName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let level = row.player?.level ?? row.member.level ?? .experienced
            levelBadge(level)
            Text("\(row.member.rating)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func reload() async {
        await membersRepo.refresh(circleId: circle.id)
        do {
            try await membersRepo.syncMembersToRoster(circleId: circle.id)
        } catch {
            membersRepo.lastError = error.localizedDescription
        }
        await roster.refresh(circleId: circle.id)
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "admin", "owner": "管理者"
        default: "メンバー"
        }
    }

    private func levelBadge(_ level: PlayerLevel) -> some View {
        Text(level.label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(levelBadgeColor(level).opacity(0.15))
            .foregroundStyle(levelColor(level))
            .clipShape(Capsule())
    }

    private func levelColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }

    private func levelBadgeColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }

    private func deleteLegacyVisitor(_ player: RosterPlayer) async {
        do {
            try await roster.deleteVisitor(player)
            legacyPendingDelete = nil
        } catch {
            roster.lastError = error.localizedDescription
        }
    }

    private var currentUserMembership: CloudCircleMember? {
        guard let uid = firebase.uid else { return nil }
        return membersRepo.members(for: circle.id).first { $0.userId == uid }
    }

    private var isOwnerOrAdmin: Bool {
        firebase.isCircleOwner(circle)
            || ["admin", "owner"].contains(currentUserMembership?.role ?? "")
    }

    private func canRemoveMember(_ member: CloudCircleMember) -> Bool {
        guard !isDeletingMember else { return false }
        if member.role == "owner" || member.userId == circle.ownerId { return false }
        if member.userId == firebase.uid { return false }
        if member.isManual { return isOwnerOrAdmin }
        if member.isRegistered { return firebase.isCircleOwner(circle) }
        return false
    }

    private func deleteMember(_ member: CloudCircleMember) async {
        isDeletingMember = true
        defer {
            isDeletingMember = false
            pendingMemberDelete = nil
        }

        do {
            try await membersRepo.removeMember(member)
        } catch {
            membersRepo.lastError = error.localizedDescription
        }
    }
}

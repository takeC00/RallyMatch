import SwiftUI

/// Mate の Circle タブと同等（サークル切替・招待・作成・参加・アカウント）
struct CircleTabView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Bindable private var firebase = FirebaseManager.shared
    @Bindable private var roster = CircleRosterRepository.shared
    @Bindable private var membersRepo = CircleMembersRepository.shared

    @State private var showJoinSheet = false
    @State private var showCreateSheet = false
    @State private var showCircleSelectSheet = false
    @State private var showDeleteConfirm = false
    @State private var showAccountSettings = false

    @State private var isDeletingCircle = false
    @State private var deleteError = ""

    var body: some View {
        NavigationStack {
            List {
                Section(header: sectionHeader("現在のサークル")) {
                    if let current = currentCircle {
                        Button {
                            showCircleSelectSheet = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(current.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    if !current.description.isEmpty {
                                        Text(current.description)
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }

                                    if !current.sportName.isEmpty {
                                        Text(current.sportName)
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray.opacity(0.7))
                            }
                        }
                    } else {
                        Button {
                            showCircleSelectSheet = true
                        } label: {
                            HStack {
                                Text("サークルを選択する")
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray.opacity(0.7))
                            }
                        }
                    }
                }
                .listRowBackground(CircleTabStyle.rowBackground)

                if let current = currentCircle {
                    Section(header: sectionHeader("メンバー・参加者")) {
                        NavigationLink {
                            CircleDetailView(circle: current)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("参加者を管理")
                                        .foregroundStyle(.white)
                                    Text("\(memberSummary(for: current)) 名")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }

                        NavigationLink {
                            CircleSettingsView(circle: current)
                        } label: {
                            Text("サークル情報")
                                .foregroundStyle(.white)
                        }
                    }
                    .listRowBackground(CircleTabStyle.rowBackground)
                }

                Section(header: sectionHeader("新しいサークルに参加")) {
                    Button("招待コードで参加する") {
                        showJoinSheet = true
                    }
                    .foregroundStyle(.white)
                }
                .listRowBackground(CircleTabStyle.rowBackground)

                if let current = currentCircle, firebase.isCircleOwner(current) {
                    Section(header: sectionHeader("オーナー操作")) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            if isDeletingCircle {
                                HStack {
                                    ProgressView()
                                    Text("削除中...")
                                }
                            } else {
                                Text("サークルを削除")
                            }
                        }
                        .disabled(isDeletingCircle)

                        if !deleteError.isEmpty {
                            Text(deleteError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .listRowBackground(CircleTabStyle.rowBackground)
                }
            }
            .navigationTitle("サークル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("サークルを作成")
                }
            }
            .accountToolbar(showAccountSettings: $showAccountSettings)
            .accountSettingsSheet(isPresented: $showAccountSettings)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .refreshable {
                await reloadMembers()
            }
            .task {
                await reloadMembers()
            }
            .onChange(of: firebase.joinedCircles.map(\.id)) { _, _ in
                Task { await reloadMembers() }
            }
            .sheet(isPresented: $showJoinSheet) {
                NavigationStack {
                    CircleJoinView()
                }
                .rallyDarkFormScreen()
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    CircleFormView()
                }
                .rallyDarkFormScreen()
            }
            .sheet(isPresented: $showCircleSelectSheet) {
                NavigationStack {
                    List {
                        Section(header: sectionHeader("サークルを選択")) {
                            ForEach(firebase.joinedCircles) { circle in
                                let isCurrent = firebase.currentCircleId == circle.id
                                Button {
                                    Task {
                                        try? await firebase.setCurrentCircle(circle.id)
                                        showCircleSelectSheet = false
                                    }
                                } label: {
                                    CircleSelectRow(
                                        name: circle.name,
                                        isCurrent: isCurrent
                                    )
                                }
                                .listRowBackground(CircleTabStyle.rowBackground)
                            }
                        }
                    }
                    .navigationTitle("サークル切替")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.black, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.ignoresSafeArea())
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("閉じる") {
                                showCircleSelectSheet = false
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                "サークルを削除しますか？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    Task { await deleteCurrentCircle() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                if let current = currentCircle {
                    Text("「\(current.name)」と関連データがすべて削除されます。この操作は取り消せません。")
                }
            }
            .onAppear {
                Task { await firebase.refreshCircles() }
            }
        }
    }

    private var currentCircle: CloudCircle? {
        guard let id = firebase.currentCircleId else { return nil }
        return firebase.joinedCircles.first { $0.id == id }
    }

    private func memberSummary(for circle: CloudCircle) -> Int {
        let count = membersRepo.members(for: circle.id).count
        if count > 0 { return count }
        return roster.players(for: circle.id).filter { !$0.isLegacyDayVisitor }.count
    }

    private func reloadMembers() async {
        await firebase.refreshCircles()
        let circleIds = firebase.joinedCircles.map(\.id)
        await membersRepo.refreshAll(circleIds: circleIds)
        await membersRepo.syncAllJoinedCircles(circleIds)
        await roster.refreshAll(circleIds: circleIds)
    }

    private func deleteCurrentCircle() async {
        guard let current = currentCircle else { return }

        isDeletingCircle = true
        deleteError = ""
        defer { isDeletingCircle = false }

        do {
            if sessionStore.circleId == current.id, let sessionId = sessionStore.sessionId {
                try? await SessionSyncService.shared.deleteSession(sessionId: sessionId)
                sessionStore.reset()
            }

            try await firebase.deleteCircle(current)
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).foregroundStyle(.gray)
    }
}

private enum CircleTabStyle {
    static let rowBackground = Color.white.opacity(0.06)
}

private struct CircleSelectRow: View {
    let name: String
    let isCurrent: Bool

    var body: some View {
        HStack {
            Text(name)
                .foregroundStyle(.white)

            Spacer()

            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

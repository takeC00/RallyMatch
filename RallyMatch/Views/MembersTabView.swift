import SwiftUI

struct MembersTabView: View {
    @Bindable private var firebase = FirebaseManager.shared
    @Bindable private var roster = CircleRosterRepository.shared
    @Bindable private var membersRepo = CircleMembersRepository.shared

    var body: some View {
        NavigationStack {
            Group {
                if firebase.isLoadingCircles && firebase.joinedCircles.isEmpty {
                    ProgressView("サークル読み込み中...")
                } else if firebase.joinedCircles.isEmpty {
                    ContentUnavailableView(
                        "サークルがありません",
                        systemImage: "person.3",
                        description: Text("右上から作成するか、招待コードで参加してください")
                    )
                } else {
                    List(firebase.joinedCircles) { circle in
                        NavigationLink {
                            CircleDetailView(circle: circle)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(circle.name)
                                        .font(.headline)
                                    if firebase.currentCircleId == circle.id {
                                        Text("選択中")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("\(membersRepo.members(for: circle.id).count) 名（アカウント）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !circle.sportName.isEmpty {
                                    Text(circle.sportName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .contextMenu {
                            Button("このサークルを選択") {
                                Task { try? await firebase.setCurrentCircle(circle.id) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("メンバー登録")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        CircleJoinView()
                    } label: {
                        Image(systemName: "ticket")
                    }
                    .accessibilityLabel("招待コードで参加")

                    NavigationLink {
                        CircleFormView()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("サークル作成")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .refreshable {
                await reloadMembers()
            }
            .task {
                await reloadMembers()
            }
            .onChange(of: firebase.joinedCircles.map(\.id)) { _, _ in
                Task { await reloadMembers() }
            }
        }
    }

    private func reloadMembers() async {
        await firebase.refreshCircles()
        let circleIds = firebase.joinedCircles.map(\.id)
        await membersRepo.refreshAll(circleIds: circleIds)
        await membersRepo.syncAllJoinedCircles(circleIds)
        await roster.refreshAll(circleIds: circleIds)
    }
}

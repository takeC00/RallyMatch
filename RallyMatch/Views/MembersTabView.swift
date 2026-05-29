import SwiftUI
import SwiftData

struct MembersTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Circle.createdAt) private var circles: [Circle]

    var body: some View {
        NavigationStack {
            Group {
                if circles.isEmpty {
                    ContentUnavailableView(
                        "サークルがありません",
                        systemImage: "person.3",
                        description: Text("右上の「サークル作成」から追加してください")
                    )
                } else {
                    List {
                        ForEach(circles) { circle in
                            NavigationLink {
                                CircleDetailView(circle: circle)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(circle.name)
                                        .font(.headline)
                                    Text("\(circle.players.count) 名登録")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteCircles)
                    }
                }
            }
            .navigationTitle("メンバー登録")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
        }
    }

    private func deleteCircles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(circles[index])
        }
        try? modelContext.save()
    }
}

import SwiftUI
import SwiftData

struct MembersTabView: View {
    @Query(sort: \Circle.createdAt) private var circles: [Circle]

    var body: some View {
        NavigationStack {
            Group {
                if circles.isEmpty {
                    ContentUnavailableView(
                        "サークルがありません",
                        systemImage: "person.3",
                        description: Text("右上の＋からサークルを作成してください")
                    )
                } else {
                    List(circles) { circle in
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
                }
            }
            .navigationTitle("メンバー登録")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CircleFormView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

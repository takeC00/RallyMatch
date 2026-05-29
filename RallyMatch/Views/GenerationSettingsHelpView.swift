import SwiftUI

struct GenerationSettingsHelpView: View {
    var body: some View {
        List {
            Section {
                Text("試合の組み合わせ方と、1人あたりの試合数・コート数を設定します。条件に完全には合わない場合も、できる限り近い形で生成します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("生成モード") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("モードA（ミックス）")
                        .font(.headline)
                    Text("初心者と経験者が交流する試合を優先します。各チームは「初心者＋経験者」のペアになりやすく、実力差が極端にならないよう調整します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("モードB（レベル分離）")
                        .font(.headline)
                    Text("初心者同士・経験者同士の試合のみを生成します。レベル別に試合したいときに使います。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("1人あたり試合数") {
                Text("各参加者が最低でも何試合プレイするかの目標です。この回数に近づくよう、できる限り試合を組みます。人数やコート数の都合で、目標に届かない場合があります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("コート数") {
                Text("同時に使えるコートの数です。例えば2コートなら、同じタイミングで2試合まで並行して進行できます。4の倍数でない人数の場合、余った人はその試合を休憩します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("その他のルール") {
                Label("同じペア・同じ対戦相手は、できる限り避けます", systemImage: "arrow.triangle.2.circlepath")
                Label("連続で試合に出る・休む回数もなるべく均等にします", systemImage: "figure.badminton")
                Label("1巡目＝全員が最低1回出場し終わるまで、2巡目以降も同様です", systemImage: "list.number")
            }
        }
        .navigationTitle("生成条件の説明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        GenerationSettingsHelpView()
    }
}

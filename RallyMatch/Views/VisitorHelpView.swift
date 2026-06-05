import SwiftUI

struct VisitorHelpView: View {
    var body: some View {
        List {
            Section {
                Text("Visitor（ビジター）は、アプリアカウントを持たない参加者を RallyMatch の試合生成に登録するための機能です。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("アカウントメンバーとの違い") {
                helpRow(
                    title: "アカウントメンバー",
                    detail: "RallyMate / RallyHub / Match で招待コード参加したユーザー。Rating やサークルメンバー一覧に表示されます。",
                    systemImage: "person.crop.circle.fill"
                )
                helpRow(
                    title: "Visitor",
                    detail: "Match だけに登録する名前のみの参加者。試合の組み合わせ生成に使います。RallyMate で試合結果を登録する場合も選択でき、レート計算では 1500 固定（Visitor 自身のレートは変動しません）。",
                    systemImage: "person.crop.circle.badge.plus"
                )
            }

            Section("Visitor の追加・編集") {
                Label("メンバー登録 → サークル詳細 → Visitor セクション", systemImage: "person.3")
                Label("試合設定 → Visitor追加", systemImage: "plus.circle")
                helpText("名前とレベル（経験者 / 初心者）を設定できます。アカウントメンバーは招待コード参加で自動的に一覧に表示されます。")
            }

            Section("自動削除（無料プラン対応）") {
                helpText("Visitor はその日だけの参加者向けです。日本時間（JST）で日付が変わったあと、Match アプリでサークル名簿を開いたタイミングで、前日以前に登録された Visitor が自動的に削除されます。")
                helpText("サーバー側のスケジュール実行は使わないため、Firebase の無料プラン（Spark）のまま利用できます。削除は Match を開いたときに行われる点にご注意ください。")
            }

            Section("手動削除") {
                Label("サークル詳細 → Visitor を左スワイプ", systemImage: "trash")
                Label("Visitor 編集画面の「Visitorを削除」", systemImage: "minus.circle")
                helpText("アカウントメンバーは削除できません。Visitor のみ対象です。")
            }

            Section("RallyMate との連携") {
                helpText("RallyMate で試合結果を入力するとき、当日の Visitor もメンバーと同様に選択できます。")
                helpText("レート計算では Visitor は常に 1500 として扱われ、Visitor 本人のレートは増減しません。アカウントメンバーのみレートが変動します。")
                helpText("Visitor は翌日以降に Match 起動時などで名簿から削除されます。削除後も試合履歴では参加者名が「Visitor」と表示されます。")
            }

            Section("試合生成での使い方") {
                helpText("試合設定画面で当日参加するメンバーと Visitor にチェックを入れ、4名以上選んで試合を生成します。経験者・初心者の設定は生成モード（ミックス / レベル分離）の組み合わせに使われます。")
            }

            Section("よくある例") {
                Label("その日だけ参加する友人・ゲスト", systemImage: "figure.wave")
                Label("まだアプリに登録していないメンバー", systemImage: "person.badge.plus")
                Label("練習参加者を仮名で登録しておく", systemImage: "pencil")
            }
        }
        .navigationTitle("Visitor とは")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpText(_ string: String) -> some View {
        Text(string)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func helpRow(title: String, detail: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

struct VisitorSectionHeader: View {
    @Binding var showHelp: Bool
    var title: String

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(title)
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.body)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Visitor の説明")
        }
        .textCase(nil)
    }
}

#Preview {
    NavigationStack {
        VisitorHelpView()
    }
}

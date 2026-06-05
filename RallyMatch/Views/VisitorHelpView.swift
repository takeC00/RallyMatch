import SwiftUI

struct VisitorHelpView: View {
    var body: some View {
        List {
            Section {
                Text("RallyOS では参加者を3種類に分けて管理します。用途に応じて使い分けてください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("ユーザー種別") {
                helpRow(
                    title: "メンバー（アカウント）",
                    detail: "Firebase Auth を持つ正式ユーザー。Hub / Mate / Match で招待コード参加。レーティング・ランキング・試合履歴の対象。",
                    systemImage: "person.crop.circle.fill"
                )
                helpRow(
                    title: "手動登録メンバー",
                    detail: "アカウントは持たないが、主催者がサークルに永続登録するユーザー。Android 未対応期間やアプリ未インストールの常連向け。レーティング・試合履歴・ランキングの対象。",
                    systemImage: "person.crop.circle.badge.checkmark"
                )
                helpRow(
                    title: "今日だけ参加",
                    detail: "その日だけの一時参加者。サークルメンバー一覧には表示しません。レーティング・ランキング対象外。人数合わせ・試合生成用。",
                    systemImage: "calendar.badge.clock"
                )
            }

            Section("参加者の追加") {
                Label("メンバーとして追加 → 手動登録メンバーを作成", systemImage: "person.badge.plus")
                Label("今日だけ参加 → その日の試合設定にのみ追加", systemImage: "calendar")
                helpText("アカウントメンバーは招待コード参加で自動的に一覧に表示されます。")
            }

            Section("手動登録メンバー") {
                helpText("表示名・初期レート（デフォルト1500）・レベル区分（経験者/初心者）・備考を設定できます。")
                helpText("Match の試合生成、Mate のレーティング管理、Hub のサークルメンバー一覧に表示されます。")
                helpText("将来、本人がアカウント作成した際に正式メンバーへ昇格・データ引き継ぎできる設計です（昇格処理は今後対応）。")
            }

            Section("今日だけ参加") {
                helpText("Match: 試合設定画面から追加。セッション内のみ有効で、サークル名簿には残りません。")
                helpText("Hub: イベント詳細から追加。イベント単位で管理します（eventVisitors）。")
                helpText("Mate: レーティング管理対象外です。試合結果の永続登録には含めません。")
            }

            Section("Match 試合生成") {
                helpText("アカウントメンバーと手動登録メンバーは circleMembers から自動同期されます。Match を開くと試合設定に表示されます。")
                helpText("当日の「今日だけ参加」は試合生成に使えますが、翌日以降は残りません。")
            }

            Section("旧 Visitor データ") {
                helpText("以前 circleRoster に登録されていた一日参加者は、Match 起動時に自動削除されます。常連の方は手動登録メンバーへの移行をおすすめします。")
            }
        }
        .navigationTitle("参加者の種類")
        .navigationBarTitleDisplayMode(.inline)
        .rallyDarkFormScreen()
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
            .accessibilityLabel("参加者の説明")
        }
        .textCase(nil)
    }
}

#Preview {
    NavigationStack {
        VisitorHelpView()
    }
}

import SwiftUI

struct MatchListHelpView: View {
    var body: some View {
        List {
            Section {
                Text("試合一覧画面の操作を説明します。試合済の更新や入れ替え・遅刻早退の変更は、都度クラウドへ自動同期されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("画面上部のアイコン（左から）") {
                Label("新規 … いまの試合を破棄して作り直す", systemImage: "doc.badge.plus")
                Label("QRコード … 参加者用 QR を表示", systemImage: "qrcode")
                Label("遅刻 / 早退 … 参加・退場の ON / OFF", systemImage: "person.badge.clock")
                Label("操作の説明 … このページを開く（オレンジ）", systemImage: "questionmark.circle")
            }
            .font(.subheadline)

            Section("新規") {
                Text("書類＋マークのアイコンをタップすると確認ダイアログが出ます。「破棄して新規作成」で、いまの試合を捨てて最初から作り直します。クラウド上のデータと参加者用 QR も無効になり、元に戻せません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("QRコード") {
                Text("QR アイコンから、参加者がスマホブラウザで試合一覧を見るための QR を表示します。URL は表示せず、QR の読み取りのみ想定しています。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("遅刻 / 早退") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("時計付きの人物アイコンから開きます。サークル全員を ON / OFF で参加管理します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label("ON … 遅刻参加。以降の未実施試合に組み込まれます", systemImage: "person.badge.plus")
                    Label("OFF … 早退。試合済・試合中の名前は残り、それ以降の試合からは除外されます", systemImage: "person.badge.minus")
                    Label("試合中の選手は OFF にできません", systemImage: "sportscourt.fill")
                    Label("参加者は常に4名以上必要です", systemImage: "person.3")
                    Label("変更後、試合済・試合中以外の未実施試合が自動で作り直されます", systemImage: "arrow.triangle.2.circlepath")
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            }

            Section("試合の操作") {
                Label("未実施の試合を右スワイプ … 「試合済」にします", systemImage: "checkmark.circle")
                Label("未実施の選手名をタップ … 別の参加者と入れ替えます", systemImage: "arrow.left.arrow.right")
            }
            .font(.subheadline)

            Section("自動削除") {
                Text("試合データは翌日 4:00（日本時間）にクラウドから自動削除されます。イベント終了後に前日のデータが残り続けることはありません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("試合一覧の説明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MatchListHelpView()
    }
}

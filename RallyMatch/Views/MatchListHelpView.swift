import SwiftUI

struct MatchListHelpView: View {
    var body: some View {
        List {
            Section {
                Text("試合一覧画面の操作と、メニュー各項目の挙動を説明します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("新規") {
                Text("画面右上の「新規」で、いまの試合を破棄して最初から作り直します。クラウド上のデータと参加者用QRも無効になり、元に戻せません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("遅刻 / 早退") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("サークル全員を ON / OFF で参加管理します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label("ON … 遅刻参加。以降の未実施試合に組み込まれます", systemImage: "person.badge.plus")
                    Label("OFF … 早退。試合済・試合中の名前は残り、それ以降の試合からは除外されます", systemImage: "person.badge.minus")
                    Label("試合中の選手は OFF にできません", systemImage: "sportscourt.fill")
                    Label("参加者は常に4名以上必要です", systemImage: "person.3")
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            }

            Section("再生成") {
                Text("試合済と試合中（未実施の先頭・コート数ぶん）はそのまま残し、それ以降の未実施試合だけを、現在の参加者で作り直します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("クラウドに同期") {
                Text("手元の試合一覧を Firebase に再送信します。通信エラー後の復旧や、参加者 Web への反映確認に使います。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("試合の操作") {
                Label("未実施の試合を右スワイプ … 「試合済」にします", systemImage: "checkmark.circle")
                Label("未実施の選手名をタップ … 別の参加者と入れ替えます", systemImage: "arrow.left.arrow.right")
            }
            .font(.subheadline)

            Section("QRコード") {
                Text("参加者がスマホブラウザで試合一覧を見るための QR を表示します。URL は表示せず、QR の読み取りのみ想定しています。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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

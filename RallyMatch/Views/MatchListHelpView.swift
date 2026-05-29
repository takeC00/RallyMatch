import SwiftUI

struct MatchListHelpView: View {
    var body: some View {
        List {
            Section {
                helpText("試合一覧画面の操作を説明します。試合済の更新や入れ替え・遅刻早退の変更は、都度クラウドへ自動同期されます。")
            }

            Section("画面上部のアイコン（左から）") {
                helpLabel("QRコード … 参加者用 QR を表示", systemImage: "qrcode")
                helpLabel("新規 … いまの試合を破棄して作り直す", systemImage: "doc.badge.plus")
                helpLabel("遅刻 / 早退 … 参加・退場の ON / OFF", systemImage: "person.badge.clock")
                helpLabel("操作の説明 … このページを開く（オレンジ）", systemImage: "questionmark.circle")
            }

            Section("新規") {
                helpText("書類＋マークのアイコンをタップすると確認ダイアログが出ます。「破棄して新規作成」で、いまの試合を捨てて最初から作り直します。クラウド上のデータと参加者用 QR も無効になり、元に戻せません。")
            }

            Section("QRコード") {
                helpText("QR アイコンから、参加者がスマホブラウザで試合一覧を見るための QR を表示します。URL は表示せず、QR の読み取りのみ想定しています。")
            }

            Section("遅刻 / 早退") {
                VStack(alignment: .leading, spacing: 8) {
                    helpText("時計付きの人物アイコンから開きます。サークル全員を ON / OFF で参加管理します。")
                    helpLabel("ON … 遅刻参加。以降の未実施試合に組み込まれます", systemImage: "person.badge.plus")
                    helpLabel("OFF … 早退。試合済・試合中の名前は残り、それ以降の試合からは除外されます", systemImage: "person.badge.minus")
                    helpLabel("試合中の選手は OFF にできません", systemImage: "sportscourt.fill")
                    helpLabel("参加者は常に4名以上必要です", systemImage: "person.3")
                    helpLabel("変更後、試合済・試合中以外の未実施試合が自動で作り直されます", systemImage: "arrow.triangle.2.circlepath")
                }
                .padding(.vertical, 4)
                .listRowInsets(Self.wideRowInsets)
            }

            Section {
                HelpProgressIntroDiagram()
                    .listRowInsets(Self.wideRowInsets)
            } header: {
                Text("試合中の変更")
            } footer: {
                helpText("右の「○コート」または「試合中」バッジをタップして切り替えます。参加者 Web にも反映されます。")
            }

            Section("その他の試合操作") {
                helpLabel("未実施の試合を右スワイプ … 「試合済」にします", systemImage: "checkmark.circle")
                helpLabel("未実施の選手名をタップ … 別の参加者と入れ替えます", systemImage: "arrow.left.arrow.right")
            }

            Section("自動削除") {
                helpText("試合データは翌日 4:00（日本時間）にクラウドから自動削除されます。イベント終了後に前日のデータが残り続けることはありません。")
            }
        }
        .navigationTitle("試合一覧の説明")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let wideRowInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

    private func helpText(_ string: String) -> some View {
        Text(string)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func helpLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

// MARK: - 試合中の変更（図解）

private struct HelpProgressIntroDiagram: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpProgressStep(
                title: "① 最初の状態（コート2の例）",
                caption: "未実施の先頭から、コート数ぶんが自動で試合中になります。",
                rows: [
                    .init(label: "第1試合", badge: .playing),
                    .init(label: "第2試合", badge: .playing),
                    .init(label: "第3試合", badge: .court(1)),
                    .init(label: "第4試合", badge: .court(2)),
                ]
            )

            HelpProgressStep(
                title: "② 後の試合を先に開始",
                caption: "第5試合の「1コート」をタップすると試合中に。いちばん早い試合中（第1試合）が待ちに戻ります。",
                rows: [
                    .init(label: "第1試合", badge: .court(1), note: "待ち"),
                    .init(label: "第2試合", badge: .playing),
                    .init(label: "第5試合", badge: .playing, note: "タップ"),
                ],
                highlightRowIndex: 2
            )

            HelpDiagramArrow()

            HelpProgressStep(
                title: "③ 飛ばした試合はそのまま",
                caption: "第1試合は未実施のまま残ります。後からスワイプで試合済にできます。",
                rows: [
                    .init(label: "第1試合", badge: .court(1), note: "未実施のまま"),
                    .init(label: "第2試合", badge: .playing),
                    .init(label: "第5試合", badge: .playing),
                ],
                highlightRowIndex: 0
            )

            HelpProgressStep(
                title: "④ 試合中を解除する",
                caption: "「試合中」バッジをもう一度タップすると、待ちに戻せます。",
                beforeAfter: (
                    [.init(label: "第5試合", badge: .playing)],
                    [.init(label: "第5試合", badge: .court(1), note: "待ち")]
                )
            )

            HelpProgressStep(
                title: "⑤ 試合が終わると先頭が戻る",
                caption: "試合中の試合を試合済にすると、飛ばされていた先頭の試合が再び試合中になります。",
                beforeAfter: (
                    [
                        .init(label: "第1試合", badge: .court(1), note: "待ち"),
                        .init(label: "第5試合", badge: .playing),
                    ],
                    [
                        .init(label: "第1試合", badge: .playing, note: "自動で復帰"),
                        .init(label: "第5試合", badge: .done),
                    ]
                )
            )
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HelpProgressStep: View {
    struct Row: Identifiable {
        let id = UUID()
        let label: String
        let badge: HelpMatchBadgeStyle
        var note: String?
    }

    let title: String
    let caption: String
    var rows: [Row] = []
    var beforeAfter: ([Row], [Row])?
    var highlightRowIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let beforeAfter {
                VStack(alignment: .leading, spacing: 10) {
                    HelpProgressRowList(rows: beforeAfter.0, title: "変更前")
                    HelpDiagramArrow()
                    HelpProgressRowList(rows: beforeAfter.1, title: "変更後")
                }
            } else {
                HelpProgressRowList(rows: rows, highlightIndex: highlightRowIndex)
            }

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HelpProgressRowList: View {
    let rows: [HelpProgressStep.Row]
    var highlightIndex: Int?
    var title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HelpMatchRow(
                    label: row.label,
                    badge: row.badge,
                    note: row.note,
                    highlighted: highlightIndex == index
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct HelpMatchRow: View {
    let label: String
    let badge: HelpMatchBadgeStyle
    var note: String?
    var highlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption.weight(.medium))
                HelpMatchBadge(style: badge)
                Spacer(minLength: 0)
            }
            if let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(highlighted ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, highlighted ? 6 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlighted ? Color.orange.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private enum HelpMatchBadgeStyle {
    case playing
    case court(Int)
    case done

    var isTappable: Bool {
        switch self {
        case .playing, .court: true
        case .done: false
        }
    }
}

private struct HelpMatchBadge: View {
    let style: HelpMatchBadgeStyle

    var body: some View {
        Group {
            switch style {
            case .playing:
                HStack(spacing: 3) {
                    Image(systemName: "sportscourt.fill")
                    Text("試合中")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())

            case .court(let no):
                Text("\(no)コート")
                    .font(.caption2)
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.teal.opacity(0.15))
                    .clipShape(Capsule())

            case .done:
                Text("済")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .overlay {
            if style.isTappable {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
        }
    }
}

private struct HelpDiagramArrow: View {
    var body: some View {
        HStack {
            Spacer()
            Image(systemName: "arrow.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        MatchListHelpView()
    }
}

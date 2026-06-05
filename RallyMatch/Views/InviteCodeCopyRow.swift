import SwiftUI
import UIKit

/// 招待コードをタップでクリップボードにコピー
struct InviteCodeCopyRow: View {
    let code: String

    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = code
            copied = true
        } label: {
            HStack {
                Text(code)
                    .font(.title3.monospaced().bold())
                    .foregroundStyle(.primary)
                Spacer()
                Label {
                    Text(copied ? "コピー済み" : "タップでコピー")
                        .font(.caption)
                } icon: {
                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .foregroundStyle(copied ? .green : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("招待コード \(code)")
        .accessibilityHint(copied ? "コピー済み" : "タップでコピー")
        .onChange(of: code) { _, _ in
            copied = false
        }
    }
}

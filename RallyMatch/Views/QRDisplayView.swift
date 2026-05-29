import SwiftUI

struct QRDisplayView: View {
    let sessionId: String
    @Environment(\.dismiss) private var dismiss

    private var urlString: String {
        AppConfig.sessionURL(sessionId: sessionId)?.absoluteString ?? ""
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                if let qr = QRCodeGenerator.image(from: urlString) {
                    qr
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(UIScreen.main.bounds.width - 48, 320))
                        .padding(24)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text("QRを生成できません")
                        .foregroundStyle(.white)
                }
                Spacer()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.35))
                    .padding()
            }
        }
    }
}

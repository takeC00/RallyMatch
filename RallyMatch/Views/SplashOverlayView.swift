import SwiftUI

/// 起動直後にスプラッシュ画像を表示（Launch Screen の補完）
struct SplashOverlayView: View {
    @Binding var isPresented: Bool

    var body: some View {
        Image("LaunchSplash")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
            .onAppear {
                Task {
                    try? await Task.sleep(for: .seconds(2.0))
                    withAnimation(.easeOut(duration: 1.5)) {
                        isPresented = false
                    }
                }
            }
    }
}

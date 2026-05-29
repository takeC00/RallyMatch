import SwiftUI

/// アプリのルート（タブバー付き）
struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            MainTabView()

            if showSplash {
                SplashOverlayView(isPresented: $showSplash)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 1.5), value: showSplash)
    }
}

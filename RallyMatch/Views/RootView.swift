import SwiftUI

/// アプリのルート（タブバー付き）
struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView()

            if showSplash {
                SplashOverlayView(isPresented: $showSplash)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 1.5), value: showSplash)
        .background(Color.black.ignoresSafeArea())
        .task {
            FirebaseManager.shared.startAuthListener()
            FirebaseManager.shared.bootstrapSession()
        }
    }
}

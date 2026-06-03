import SwiftUI

struct ContentView: View {

    @Bindable private var firebase = FirebaseManager.shared

    var body: some View {
        Group {
            if firebase.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

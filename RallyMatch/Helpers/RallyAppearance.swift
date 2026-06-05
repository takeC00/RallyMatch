import SwiftUI
import UIKit

enum RallyScreenStyle {
    static let rowBackground = Color.white.opacity(0.06)
}

enum RallyAppearance {
    static func configure() {
        UIScrollView.appearance().backgroundColor = .black
        UITableView.appearance().backgroundColor = .black

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = .black
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let navBar = UINavigationBarAppearance()
        navBar.configureWithOpaqueBackground()
        navBar.backgroundColor = .black
        navBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBar.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navBar
        UINavigationBar.appearance().scrollEdgeAppearance = navBar
        UINavigationBar.appearance().compactAppearance = navBar
        UINavigationBar.appearance().tintColor = .white
    }
}

extension View {
    func rallyDarkScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
    }

    func rallyDarkNavigationBar() -> some View {
        toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func rallyDarkFormScreen() -> some View {
        rallyDarkScreenBackground()
            .rallyDarkNavigationBar()
    }
}

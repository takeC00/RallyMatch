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

        // Form / List 内の UIKit ラベル・入力欄（黒背景で見えなくなるのを防ぐ）
        UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor = .white
        UITextField.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor = .white
        UITextView.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor = .white

        UISwitch.appearance().onTintColor = .systemGreen
    }
}

extension View {
    func rallyDarkScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .foregroundStyle(.white)
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

    /// 白背景カード内（例: レーティング説明の具体例）
    func rallyLightCardContent() -> some View {
        foregroundStyle(.black)
            .tint(.blue)
            .colorScheme(.light)
    }
}

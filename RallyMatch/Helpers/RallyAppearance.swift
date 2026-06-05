import SwiftUI
import UIKit

enum RallyScreenStyle {
    static let rowBackground = Color.white.opacity(0.06)
}

enum RallyAppearance {
    static func configure() {
        // キーボード表示時に黒い帯が出ないよう、UIKit スクロール背景は透明にする
        UIScrollView.appearance().backgroundColor = .clear
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear

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

        UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor = .white
        UITextField.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor = .white
        UITextField.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).backgroundColor = .clear
        UITextView.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor = .white
        UITextView.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).backgroundColor = .clear

        UISwitch.appearance().onTintColor = .systemGreen
    }
}

extension View {
    func rallyDarkScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background {
                Color.black
                    .ignoresSafeArea()
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
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

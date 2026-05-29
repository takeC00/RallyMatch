//
//  RallyMatchApp.swift
//  RallyMatch
//

import SwiftUI
import SwiftData

@main
struct RallyMatchApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Circle.self, Player.self])
    }
}

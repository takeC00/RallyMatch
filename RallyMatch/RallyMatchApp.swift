//
//  RallyMatchApp.swift
//  RallyMatch
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct RallyMatchApp: App {

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
           FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Circle.self, Player.self])
    }
}

//
//  RallyMatchApp.swift
//  RallyMatch
//

import SwiftUI
import FirebaseCore

@main
struct RallyMatchApp: App {

    init() {
        RallyAppearance.configure()
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
           FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

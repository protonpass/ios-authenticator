//
//  AuthenticatorApp.swift
//  Authenticator
//
//  Created by martin on 04/02/2025.
//

import PresentationLayer
import SwiftData
import SwiftUI

@main
struct AuthenticatorApp: App {
//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            Item.self
//        ])
//        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//
//        do {
//            return try ModelContainer(for: schema, configurations: [modelConfiguration])
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()

    var body: some Scene {
        WindowGroup {
            TokensListView()
//            ContentView()
        }
//        .modelContainer(sharedModelContainer)
    }
}

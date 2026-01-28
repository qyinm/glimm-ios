//
//  glimmApp.swift
//  glimm
//

import SwiftUI
import SwiftData

@main
struct glimmApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Memory.self,
            Settings.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

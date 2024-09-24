//
//  WristAsNeededApp.swift
//  WristAsNeeded Watch App
//
//  Created by Dan Hart on 9/24/24.
//

import SwiftUI
import SwiftData
import CoreData

@main
struct WristAsNeeded_Watch_AppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LogItem.self,
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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


//
//  AsNeededApp.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/26/22.
//

import SwiftUI
import AppIntents
import SwiftData
import SwiftDate

@main
struct AsNeededApp: App {
    init() {
        LogShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onDisappear {
                    Logbook.shared.save()
                }
        }
        .modelContainer(Logbook.shared.sharedModelContainer)
    }
}

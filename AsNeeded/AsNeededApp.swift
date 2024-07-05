//
//  AsNeededApp.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/26/22.
//

import SwiftUI
import AppIntents

@main
struct AsNeededApp: App {
    private var userData: UserData
    
    init() {
        userData = UserData.shared
        
        LogShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userData)
        }
    }
}

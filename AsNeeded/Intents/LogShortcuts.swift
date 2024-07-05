//
//  LogShortcuts.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/5/24.
//

import Foundation
import AppIntents
import SwiftUI

/**
 An `AppShortcut` wraps an intent to make it automatically discoverable throughout the system. An `AppShortcutsProvider` manages the shortcuts the app
 makes available. The app can update the available shortcuts by calling `updateAppShortcutParameters()` as needed.
 */
class LogShortcuts: AppShortcutsProvider {
    
    /// The color the system uses to display the App Shortcuts in the Shortcuts app.
    static var shortcutTileColor = ShortcutTileColor.navy
    
    /**
     This sample app contains several examples of different intents, but only the intents this array describes make sense as App Shortcuts.
     Put the App Shortcut most people will use as the first item in the array. This first shortcut shouldn't bring the app to the foreground.
     
     Every phrase that people use to invoke an App Shortcut needs to contain the app name, using the `applicationName` placeholder in the provided
     phrase text, as well as any app name synonyms declared in the `INAlternativeAppNames` key of the app's `Info.plist` file. These phrases are
     localized in a string catalog named `AppShortcuts.xcstrings`.
     
     - Tag: open_favorites_app_shortcut
     */
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: QuickLogOneIntent(), phrases: [
            "Quick Log in \(.applicationName)",
            "Quick Log One in \(.applicationName)",
            "In \(.applicationName), Quick Log",
            "In \(.applicationName), Quick Log One",
        ],
        shortTitle: "Quick Log One",
        systemImageName: "pencil.circle.fill")
        
        AppShortcut(intent: GetTodayCountIntent(), phrases: [
            "Get Today's Count in \(.applicationName)",
            "Get Today \(.applicationName)",
            "In \(.applicationName), Get Today's Count",
            "In \(.applicationName), Get Today",
        ],
        shortTitle: "Get Today's Count",
        systemImageName: "doc.plaintext")
    }
}


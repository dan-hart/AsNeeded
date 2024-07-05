//
//  QuickLogOneIntent.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/5/24.
//

import Foundation
import AppIntents

struct QuickLogOneIntent: AppIntent {
    
    /// Every intent needs to include metadata, such as a localized title. The title of the intent is displayed throughout the system.
    static var title: LocalizedStringResource = "Quick Log One"

    /// An intent can optionally provide a localized description that the Shortcuts app displays.
    static var description = IntentDescription("Log one MG of medication right now.")
    
    /// Tell the system to bring the app to the foreground when the intent runs.
    static var openAppWhenRun: Bool = false
    
    /**
     When the system runs the intent, it calls `perform()`.
     
     Intents run on an arbitrary queue. Intents that manipulate UI need to annotate `perform()` with `@MainActor`
     so that the UI operations run on the main actor.
     */
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        Logbook.quickLog()
        UserData.shared.quantityInMG -= 1
        
        if let logs = Logbook.getLogs(for: .now) {
            return .result(dialog: "Logged ✅ You've now taken \(Int(logs.totalMG.rounded(.up))) MG today.")
        } else {
            return .result(dialog: "Logged ✅")
        }
    }
}


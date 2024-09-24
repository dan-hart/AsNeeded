//
//  GetTodayCount.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/5/24.
//

import Foundation
import AppIntents
import SwiftUI

struct GetTodayCountIntent: AppIntent {
    
    /// Every intent needs to include metadata, such as a localized title. The title of the intent is displayed throughout the system.
    static var title: LocalizedStringResource = "Get Today's Count"

    /// An intent can optionally provide a localized description that the Shortcuts app displays.
    static var description = IntentDescription("Get the count of today's doses in MG.")
    
    /// Tell the system to bring the app to the foreground when the intent runs.
    static var openAppWhenRun: Bool = false
    
    /**
     When the system runs the intent, it calls `perform()`.
     
     Intents run on an arbitrary queue. Intents that manipulate UI need to annotate `perform()` with `@MainActor`
     so that the UI operations run on the main actor.
     */
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let logs = Logbook.shared.getLogs(for: .now) {
            return .result(dialog: "You've taken \(Int(logs.totalMG.rounded(.up))) MG today.")
        } else {
            return .result(dialog: "Error fetching today's logs.")
        }
    }
}

//
//  AsNeededApp.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/26/22.
//

import SwiftUI
import HealthKit
import HealthKitUI

@main
struct AsNeededApp: App {
    @StateObject private var watchConnectivityReceiver = WCReceiver()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchConnectivityReceiver)
        }
    }
}

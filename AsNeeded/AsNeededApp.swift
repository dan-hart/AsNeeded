//
//  AsNeededApp.swift
//  AsNeeded
//
//  Created by AsNeeded Team on 9/26/22.
//

import SwiftUI
import HealthKit
import HealthKitUI
import DHLoggingKit

#if canImport(AppIntents)
import AppIntents
#endif

@main
struct AsNeededApp: App {
	@StateObject private var watchConnectivityReceiver = WCReceiver()
	private let logger = DHLogger.general
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(watchConnectivityReceiver)
				.onAppear {
					logger.info("AsNeeded app launched successfully")
				}
		}
	}
}

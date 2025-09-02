//
//  AsNeededApp.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/26/22.
//

import SwiftUI
import HealthKit
import HealthKitUI
import DHLoggingKit

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

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

#if canImport(AppIntents)
import AppIntents
#endif

@main
struct AsNeededApp: App {
	@StateObject private var watchConnectivityReceiver = WCReceiver()
	@StateObject private var revenueCatManager = RevenueCatManager.shared
	private let logger = DHLogger.general
	
	init() {
		// Configure RevenueCat on app launch
		RevenueCatManager.shared.configure()

		// Register custom fonts for accessibility
		FontManager.registerCustomFonts()

		// Configure navigation bar appearance with default font
		let savedFontFamily = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedFontFamily)
		let fontFamily = FontFamily(rawValue: savedFontFamily ?? FontFamily.system.rawValue) ?? .system
		NavigationBarAppearanceManager.configureAppearance(for: fontFamily)
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(watchConnectivityReceiver)
				.environmentObject(revenueCatManager)
				.onAppear {
					logger.info("AsNeeded app launched successfully")
					Task { @MainActor in
						AppReviewManager.shared.recordAppLaunch()
					}
				}
		}
	}
}

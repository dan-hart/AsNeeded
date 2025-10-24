// AppDelegate.swift
// Handles UIKit app lifecycle events including quick actions

import DHLoggingKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
	private let logger = DHLogger(category: "AppDelegate")

	// MARK: - Quick Actions

	/// Handle quick action from app icon (3D Touch / Haptic Touch) when app is already running
	func application(
		_ application: UIApplication,
		performActionFor shortcutItem: UIApplicationShortcutItem,
		completionHandler: @escaping (Bool) -> Void
	) {
		logger.info("Handling quick action: \(shortcutItem.type)")
		Task { @MainActor in
			QuickActionHandler.shared.handleShortcutItem(shortcutItem)
			completionHandler(true)
		}
	}

	/// Handle quick action when app is launched from quick action
	func application(
		_ application: UIApplication,
		configurationForConnecting connectingSceneSession: UISceneSession,
		options: UIScene.ConnectionOptions
	) -> UISceneConfiguration {
		// Check if launched from quick action
		if let shortcutItem = options.shortcutItem {
			logger.info("App launched from quick action: \(shortcutItem.type)")
			// Handle the shortcut item on main actor
			Task { @MainActor in
				QuickActionHandler.shared.handleShortcutItem(shortcutItem)
			}
		}

		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}
}

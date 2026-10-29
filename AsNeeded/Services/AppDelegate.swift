// AppDelegate.swift
// Handles UIKit app lifecycle events including quick actions

import DHLoggingKit
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
	private let logger = DHLogger(category: "AppDelegate")

	// MARK: - Medication Notifications
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		let center = UNUserNotificationCenter.current()
		center.delegate = self
		center.setNotificationCategories(MedicationNotificationAction.categories)
		return true
	}

	nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
		let notification = response.notification
		guard let action = MedicationNotificationAction(
			actionIdentifier: response.actionIdentifier,
			requestIdentifier: notification.request.identifier,
			categoryIdentifier: notification.request.content.categoryIdentifier,
			medicationID: notification.request.content.userInfo[MedicationReminderRequest.medicationIDKey] as? String
		) else { return }
		await MainActor.run {
			self.logger.info("Handling medication notification action")
			MedicationNotificationActionDispatcher(navigationManager: .shared, removeDelivered: { identifier in
				UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
			}).handle(action)
		}
	}

	nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
		[.banner, .list, .sound]
	}

	// MARK: - Quick Actions

	/// Handle quick action from app icon (3D Touch / Haptic Touch) when app is already running
	func application(
		_ application: UIApplication,
		performActionFor shortcutItem: UIApplicationShortcutItem,
		completionHandler: @escaping (Bool) -> Void
	) {
		logger.info("Handling quick action")
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
			logger.info("App launched from quick action")
			// Handle the shortcut item on main actor
			Task { @MainActor in
				QuickActionHandler.shared.handleShortcutItem(shortcutItem)
			}
		}

		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}
}

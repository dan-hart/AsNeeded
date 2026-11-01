import ANModelKit
import DHLoggingKit
import Foundation
import UserNotifications

@MainActor
struct MedicationNotificationResponseHandler {
	let navigationManager: NavigationManager
	let notifications: MedicationNotificationClient
	let logDose: (MedicationNotificationAction) async throws -> ANEventConcept
	let showNames: () -> Bool
	private let logger = DHLogger(category: "MedicationNotificationResponse")

	static var live: Self {
		let doseLogger = NotificationDoseLogger(dataStore: .shared, prepare: {
			await MigrationCoordinator.shared.runMigrationIfNeeded()
			// A concurrent startup migration may still own storage. Fail visibly instead of
			// waiting past the system's background allowance or logging later without another tap.
			guard MigrationCoordinator.shared.isComplete else { throw NotificationDoseLogger.Failure.reviewRequired }
		}, profile: { MedicationSafetyProfileStore.shared.profile(for: $0) })
		return Self(navigationManager: .shared, notifications: .live(UNUserNotificationCenter.current()),
			logDose: { try await doseLogger.log($0) },
			showNames: { UserDefaults.standard.bool(forKey: UserDefaultsKeys.showMedicationNamesInNotifications) })
	}

	func handle(_ action: MedicationNotificationAction) async {
		guard action.kind == .log else {
			MedicationNotificationActionDispatcher(navigationManager: navigationManager,
				removeDelivered: { notifications.removeDelivered([$0]) }).handle(action)
			return
		}
		let feedbackID = "dose-log-feedback.\(action.eventID.uuidString)"
		let request: UNNotificationRequest
		do {
			let event = try await logDose(action)
			notifications.removeDelivered([action.requestIdentifier])
			let content = UNMutableNotificationContent()
			content.title = String(localized: "Dose logged")
			if showNames(), let medication = event.medication, let dose = event.dose {
				let recordedDose = String(localized: "\(String(localized: "Dose logged")): \(dose.unit.localizedCompactAmount(for: dose.amount))")
				content.body = String(localized: "\(recordedDose) · \(medication.displayName). Tap to view History.")
			} else {
				content.body = String(localized: "Your dose was saved. Tap to view History.")
			}
			content.categoryIdentifier = MedicationNotificationAction.confirmationCategoryIdentifier
			content.userInfo = [MedicationReminderRequest.medicationIDKey: action.medicationID.uuidString]
			request = UNNotificationRequest(identifier: feedbackID, content: content, trigger: nil)
		} catch {
			logger.logPrivacySafeError("Notification dose was not saved", error: error)
			let content = UNMutableNotificationContent()
			content.title = String(localized: "Dose not logged")
			content.body = String(localized: "Open AsNeeded to review the medication, dose, and saved guidance before logging.")
			content.categoryIdentifier = MedicationNotificationAction.reviewCategoryIdentifier
			content.userInfo = [MedicationReminderRequest.medicationIDKey: action.medicationID.uuidString]
			request = UNNotificationRequest(identifier: feedbackID, content: content, trigger: nil)
		}
		// Feedback scheduling is separate from the committed save. Never report a saved dose
		// as failed because iOS refused the confirmation notification.
		// Replace earlier failures too, so a successful retry leaves no stale review prompt.
		notifications.removePending([feedbackID])
		notifications.removeDelivered([feedbackID])
		do { try await notifications.add(request) }
		catch { logger.logPrivacySafeError("Unable to deliver notification action feedback", error: error) }
	}
}

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
	static var confirmationTitle: String { String(localized: "Dose logged") }
	static var genericConfirmationBody: String { String(localized: "Your dose was saved. Tap to view History.") }

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
		let savedEvent: ANEventConcept?
		do {
			savedEvent = try await logDose(action)
		} catch {
			logger.logPrivacySafeError("Notification dose was not saved", error: error)
			savedEvent = nil
		}
		if savedEvent != nil {
			notifications.removeDelivered([action.requestIdentifier])
		}
		let includeName = savedEvent?.medication != nil && savedEvent?.dose != nil && showNames()
		let feedback = Self.feedbackRequest(for: action, savedEvent: savedEvent, showNames: includeName)
		// Replace earlier failures too, so a successful retry leaves no stale review prompt.
		notifications.removePending([feedback.identifier])
		notifications.removeDelivered([feedback.identifier])
		// Delivery is best effort after the save outcome is known.
		do {
			try await notifications.add(feedback)
			if includeName && !showNames() {
				notifications.removePending([feedback.identifier])
				notifications.removeDelivered([feedback.identifier])
				let generic = Self.feedbackRequest(for: action, savedEvent: savedEvent, showNames: false)
				try await notifications.add(generic)
				let delivered = await notifications.deliveredRequests()
				if delivered.contains(where: { $0.identifier == feedback.identifier && $0.content.body == feedback.content.body }) {
					notifications.removeDelivered([feedback.identifier])
				}
			}
		}
		catch { logger.logPrivacySafeError("Unable to deliver notification action feedback", error: error) }
	}

	private static func feedbackRequest(
		for action: MedicationNotificationAction,
		savedEvent: ANEventConcept?,
		showNames: Bool
	) -> UNNotificationRequest {
		let content = UNMutableNotificationContent()
		if let event = savedEvent {
			content.title = confirmationTitle
			if showNames, let medication = event.medication, let dose = event.dose {
				let recordedDose = String(localized: "\(String(localized: "Dose logged")): \(dose.unit.localizedCompactAmount(for: dose.amount))")
				content.body = String(localized: "\(recordedDose) · \(medication.displayName). Tap to view History.")
			} else {
				content.body = genericConfirmationBody
			}
			content.categoryIdentifier = MedicationNotificationAction.confirmationCategoryIdentifier
		} else {
			content.title = String(localized: "Dose not logged")
			content.body = String(localized: "Open AsNeeded to review the medication, dose, and saved guidance before logging.")
			content.categoryIdentifier = MedicationNotificationAction.reviewCategoryIdentifier
		}
		content.userInfo = [MedicationReminderRequest.medicationIDKey: action.medicationID.uuidString]
		return UNNotificationRequest(identifier: "dose-log-feedback.\(action.eventID.uuidString)", content: content, trigger: nil)
	}
}

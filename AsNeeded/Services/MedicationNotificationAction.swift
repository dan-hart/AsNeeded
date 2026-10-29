import Foundation
import UserNotifications

/// Notification responses open the exact medication for review; they never record a dose.
struct MedicationNotificationAction: Equatable, Sendable {
	enum Kind: String, Sendable { case open, skip }
	let kind: Kind
	let medicationID: UUID
	let requestIdentifier: String

	init?(actionIdentifier: String, requestIdentifier: String, categoryIdentifier: String,
		medicationID: String?) {
		guard [MedicationReminderRequest.categoryIdentifier, MedicationAvailabilityNotificationPlanner.categoryIdentifier].contains(categoryIdentifier),
			!requestIdentifier.isEmpty, let medicationID, let id = UUID(uuidString: medicationID) else { return nil }
		switch actionIdentifier {
		case "LOG_ACTION", "TAKEN_ACTION", UNNotificationDefaultActionIdentifier: kind = .open
		case "SKIP_ACTION": kind = .skip
		default: return nil
		}
		self.medicationID = id
		self.requestIdentifier = requestIdentifier
	}

	static var categories: Set<UNNotificationCategory> {
		let log = UNNotificationAction(identifier: "LOG_ACTION", title: "Log", options: [.foreground])
		let skip = UNNotificationAction(identifier: "SKIP_ACTION", title: "Skip", options: [])
		return [
			UNNotificationCategory(identifier: MedicationReminderRequest.categoryIdentifier,
				actions: [log, skip], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "Medication reminder", options: []),
			UNNotificationCategory(identifier: MedicationAvailabilityNotificationPlanner.categoryIdentifier,
				actions: [log], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "Next dose availability", options: []),
		]
	}
}

@MainActor
struct MedicationNotificationActionDispatcher {
	let navigationManager: NavigationManager
	let removeDelivered: (String) -> Void

	func handle(_ action: MedicationNotificationAction) {
		if action.kind == .skip {
			// Dismiss this occurrence; preserve the recurring schedule and all dose/stock data.
			removeDelivered(action.requestIdentifier)
			return
		}
		navigationManager.pendingWidgetRoute = nil
		navigationManager.shouldShowLogDoseChooser = false
		navigationManager.navigateToLogDose(medicationID: action.medicationID.uuidString)
	}
}

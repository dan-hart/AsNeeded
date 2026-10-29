import Foundation
import CryptoKit
import UserNotifications

/// Only explicit Log actions record a dose. Body and feedback taps navigate without saving.
struct MedicationNotificationAction: Equatable, Sendable {
	enum Kind: String, Sendable { case open, log, history, skip }
	let kind: Kind
	let medicationID: UUID
	let requestIdentifier: String
	let categoryIdentifier: String
	let deliveredAt: Date
	static let confirmationCategoryIdentifier = "DOSE_LOG_CONFIRMATION"
	static let reviewCategoryIdentifier = "DOSE_LOG_REVIEW"

	init?(actionIdentifier: String, requestIdentifier: String, categoryIdentifier: String,
		medicationID: String?, deliveredAt: Date = .now) {
		guard !requestIdentifier.isEmpty, let medicationID, let id = UUID(uuidString: medicationID),
			deliveredAt.timeIntervalSince1970.isFinite else { return nil }
		switch (categoryIdentifier, actionIdentifier) {
		case (MedicationReminderRequest.categoryIdentifier, "LOG_ACTION"),
			(MedicationAvailabilityNotificationPlanner.categoryIdentifier, "LOG_ACTION"),
			(MedicationReminderRequest.categoryIdentifier, "TAKEN_ACTION"),
			(MedicationAvailabilityNotificationPlanner.categoryIdentifier, "TAKEN_ACTION"): kind = .log
		case (MedicationReminderRequest.categoryIdentifier, UNNotificationDefaultActionIdentifier),
			(MedicationAvailabilityNotificationPlanner.categoryIdentifier, UNNotificationDefaultActionIdentifier),
			(Self.reviewCategoryIdentifier, UNNotificationDefaultActionIdentifier),
			(Self.reviewCategoryIdentifier, "REVIEW_DOSE_ACTION"): kind = .open
		case (Self.confirmationCategoryIdentifier, UNNotificationDefaultActionIdentifier),
			(Self.confirmationCategoryIdentifier, "VIEW_LOG_ACTION"): kind = .history
		case (MedicationReminderRequest.categoryIdentifier, "SKIP_ACTION"): kind = .skip
		default: return nil
		}
		self.medicationID = id
		self.requestIdentifier = requestIdentifier
		self.categoryIdentifier = categoryIdentifier
		self.deliveredAt = deliveredAt
	}

	/// Recurring notifications reuse request identifiers; delivery time distinguishes occurrences.
	var eventID: UUID {
		let identity = [categoryIdentifier, requestIdentifier, medicationID.uuidString,
			String(deliveredAt.timeIntervalSince1970.bitPattern)].joined(separator: "\u{0}")
		let bytes = Array(SHA256.hash(data: Data(identity.utf8)).prefix(16))
		return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
			bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
	}

	static var categories: Set<UNNotificationCategory> {
		let log = UNNotificationAction(identifier: "LOG_ACTION", title: "Log", options: [.authenticationRequired])
		let skip = UNNotificationAction(identifier: "SKIP_ACTION", title: "Skip", options: [])
		return [
			UNNotificationCategory(identifier: MedicationReminderRequest.categoryIdentifier,
				actions: [log, skip], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "Medication reminder", options: []),
			UNNotificationCategory(identifier: MedicationAvailabilityNotificationPlanner.categoryIdentifier,
				actions: [log], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "Next dose availability", options: []),
			UNNotificationCategory(identifier: confirmationCategoryIdentifier,
				actions: [UNNotificationAction(identifier: "VIEW_LOG_ACTION", title: "View Log", options: [.foreground])],
				intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "Dose logged", options: []),
			UNNotificationCategory(identifier: reviewCategoryIdentifier,
				actions: [UNNotificationAction(identifier: "REVIEW_DOSE_ACTION", title: "Review Dose", options: [.foreground])],
				intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "Dose not logged", options: []),
		]
	}
}

@MainActor
struct MedicationNotificationActionDispatcher {
	let navigationManager: NavigationManager
	let removeDelivered: (String) -> Void

	func handle(_ action: MedicationNotificationAction) {
		// Background saves belong to the asynchronous handler, never this navigation owner.
		guard action.kind != .log else { return }
		if action.kind == .skip {
			// Dismiss this occurrence; preserve the recurring schedule and all dose/stock data.
			removeDelivered(action.requestIdentifier)
			return
		}
		navigationManager.pendingWidgetRoute = nil
		navigationManager.shouldShowLogDoseChooser = false
		if action.kind == .history {
			navigationManager.pendingLogMedicationID = nil
			navigationManager.pendingMedicationDetail = nil
			navigationManager.navigateToHistory(medicationID: action.medicationID.uuidString)
		} else {
			navigationManager.navigateToLogDose(medicationID: action.medicationID.uuidString)
		}
	}
}

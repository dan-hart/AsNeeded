import CryptoKit
import Foundation
import UserNotifications

/// A response carries only a stable medication identity; delivered occurrences share a durable dose ID.
struct MedicationNotificationAction: Equatable, Sendable, Identifiable {
	enum Kind: String, Sendable { case log, open, skip }
	let kind: Kind
	let medicationID: UUID
	let requestIdentifier: String
	let eventID: UUID
	let respondedAt: Date
	var id: String { "\(eventID.uuidString)|\(kind.rawValue)" }

	init?(actionIdentifier: String, requestIdentifier: String, categoryIdentifier: String,
		medicationID: String?, deliveredAt: Date, respondedAt: Date = .now) {
		guard [MedicationReminderRequest.categoryIdentifier, MedicationAvailabilityNotificationPlanner.categoryIdentifier].contains(categoryIdentifier),
			!requestIdentifier.isEmpty, let medicationID, let id = UUID(uuidString: medicationID),
			deliveredAt.timeIntervalSinceReferenceDate.isFinite, respondedAt.timeIntervalSinceReferenceDate.isFinite else { return nil }
		switch actionIdentifier {
		case "LOG_ACTION", "TAKEN_ACTION": kind = .log
		case UNNotificationDefaultActionIdentifier: kind = .open
		case "SKIP_ACTION": kind = .skip
		default: return nil
		}
		self.medicationID = id
		self.requestIdentifier = requestIdentifier
		self.respondedAt = respondedAt
		// Include delivery time: recurring requests reuse their identifier on different days.
		let key = "notification-dose|\(requestIdentifier)|\(id.uuidString)|\(deliveredAt.timeIntervalSinceReferenceDate.bitPattern)"
		let bytes = Array(SHA256.hash(data: Data(key.utf8)))
		eventID = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
			bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
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
		navigationManager.enqueueNotificationAction(action)
	}
}

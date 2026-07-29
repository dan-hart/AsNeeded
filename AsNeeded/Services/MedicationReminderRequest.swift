import ANModelKit
import Foundation
import UserNotifications

struct MedicationReminderRequest {
	static let categoryIdentifier = "MEDICATION_REMINDER"
	static let medicationIDKey = "medicationId"

	struct Identity: Hashable {
		let medicationID: UUID
		let repeats: Bool
		let year: Int?
		let month: Int?
		let day: Int?
		let weekday: Int?
		let hour: Int?
		let minute: Int?

		var identifier: String {
			let values: [String] = [
				medicationID.uuidString,
				repeats ? "recurring" : "once",
				year.map { String($0) } ?? "-",
				month.map { String($0) } ?? "-",
				day.map { String($0) } ?? "-",
				weekday.map { String($0) } ?? "-",
				hour.map { String($0) } ?? "-",
				minute.map { String($0) } ?? "-"
			]
			return values.joined(separator: "|")
		}
	}

	struct ReconciliationPlan {
		let requestToAdd: UNNotificationRequest
		let identifiersToRemove: [String]
	}

	static func make(
		medication: ANMedicationConcept,
		date: Date,
		isRecurring: Bool,
		repeatInterval: DateComponents? = nil,
		isUrgent: Bool,
		showMedicationNames: Bool,
		calendar: Calendar = .current
	) -> UNNotificationRequest {
		let repeats = isRecurring && repeatInterval != nil
		let components: DateComponents
		if let repeatInterval, repeats {
			components = recurringComponents(from: repeatInterval)
		} else {
			components = oneTimeComponents(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date))
		}

		let content = UNMutableNotificationContent()
		if showMedicationNames {
			content.title = medication.displayName
			content.body = "It's time to take \(medication.displayName)"
		} else {
			content.title = "Medication Reminder"
			content.body = "It's time to take your medication"
		}
		content.sound = .default
		content.categoryIdentifier = categoryIdentifier
		content.userInfo = [medicationIDKey: medication.id.uuidString]
		content.interruptionLevel = isUrgent ? .timeSensitive : .active

		let identity = Identity(medicationID: medication.id, repeats: repeats, components: components)
		let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
		return UNNotificationRequest(identifier: identity.identifier, content: content, trigger: trigger)
	}

	static func identity(for request: UNNotificationRequest) -> Identity? {
		guard request.content.categoryIdentifier == categoryIdentifier,
			let medicationID = medicationID(from: request.content.userInfo),
			let trigger = request.trigger as? UNCalendarNotificationTrigger
		else {
			return nil
		}

		let components = trigger.repeats
			? recurringComponents(from: trigger.dateComponents)
			: oneTimeComponents(from: trigger.dateComponents)
		return Identity(medicationID: medicationID, repeats: trigger.repeats, components: components)
	}

	static func legacyIdentifiers(matching request: UNNotificationRequest, in requests: [UNNotificationRequest]) -> [String] {
		guard let identity = identity(for: request) else {
			return []
		}

		return requests.compactMap { candidate in
			guard Self.identity(for: candidate) == identity,
				candidate.identifier != request.identifier,
				candidate.identifier != identity.identifier
			else {
				return nil
			}
			return candidate.identifier
		}.sorted()
	}

	static func reconciliationPlans(
		in requests: [UNNotificationRequest],
		urgencyByMedicationID: [UUID: Bool]
	) -> [ReconciliationPlan] {
		let groupedRequests = Dictionary(grouping: requests.compactMap { request -> (Identity, UNNotificationRequest)? in
			guard let identity = identity(for: request),
				urgencyByMedicationID[identity.medicationID] != nil
			else {
				return nil
			}
			return (identity, request)
		}, by: { $0.0 })

		return groupedRequests.compactMap { identity, matches in
			guard let isUrgent = urgencyByMedicationID[identity.medicationID] else {
				return nil
			}
			let desiredInterruptionLevel: UNNotificationInterruptionLevel = isUrgent ? .timeSensitive : .active
			let requests = matches.map(\.1).sorted { $0.identifier < $1.identifier }
			guard let source = requests.first(where: { $0.identifier == identity.identifier }) ?? requests.first else {
				return nil
			}
			let identifiersToRemove = requests.map(\.identifier).filter { $0 != identity.identifier }.sorted()
			guard let canonicalRequest = canonicalRequest(
				from: source,
				identity: identity,
				interruptionLevel: desiredInterruptionLevel
			) else {
				return nil
			}
			let isCurrentCanonical = source.identifier == identity.identifier
				&& identifiersToRemove.isEmpty
				&& source.content.interruptionLevel == desiredInterruptionLevel
				&& source.trigger is UNCalendarNotificationTrigger
				&& (source.trigger as? UNCalendarNotificationTrigger)?.dateComponents == components(for: identity)
			guard !isCurrentCanonical else {
				return nil
			}
			return ReconciliationPlan(requestToAdd: canonicalRequest, identifiersToRemove: identifiersToRemove)
		}.sorted { $0.requestToAdd.identifier < $1.requestToAdd.identifier }
	}

	static func updatingUrgency(
		of request: UNNotificationRequest,
		isUrgent: Bool
	) -> UNNotificationRequest? {
		guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
			return nil
		}
		content.interruptionLevel = isUrgent ? .timeSensitive : .active
		return UNNotificationRequest(
			identifier: request.identifier,
			content: content,
			trigger: request.trigger
		)
	}

	static func duplicateIdentifiers(in requests: [UNNotificationRequest]) -> [String] {
		let groupedRequests = Dictionary(grouping: requests.compactMap { request -> (Identity, UNNotificationRequest)? in
			guard let identity = identity(for: request) else {
				return nil
			}
			return (identity, request)
		}, by: { $0.0 })

		var duplicates: [String] = []
		for (identity, matches) in groupedRequests {
			guard matches.count > 1 else {
				continue
			}
			if matches.contains(where: { $0.1.identifier == identity.identifier }) {
				duplicates.append(contentsOf: matches.map(\.1.identifier).filter { $0 != identity.identifier })
				continue
			}
			guard let retainedIdentifier = matches.map(\.1.identifier).min() else {
				continue
			}
			duplicates.append(contentsOf: matches.map(\.1.identifier).filter { $0 != retainedIdentifier })
		}
		return duplicates.sorted()
	}

	static func deliveredIdentifiers(for medicationID: UUID, in requests: [UNNotificationRequest]) -> [String] {
		requests.compactMap { request in
			guard request.content.categoryIdentifier == categoryIdentifier,
				Self.medicationID(from: request.content.userInfo) == medicationID
			else {
				return nil
			}
			return request.identifier
		}.sorted()
	}

	static func deliveredIdentifiers(for medication: ANMedicationConcept, in requests: [UNNotificationRequest]) -> [String] {
		deliveredIdentifiers(for: medication.id, in: requests)
	}

	private static func medicationID(from userInfo: [AnyHashable: Any]) -> UUID? {
		if let medicationID = userInfo[medicationIDKey] as? UUID {
			return medicationID
		}
		guard let value = userInfo[medicationIDKey] as? String else {
			return nil
		}
		return UUID(uuidString: value)
	}

	private static func recurringComponents(from components: DateComponents) -> DateComponents {
		var normalized = DateComponents(hour: components.hour, minute: components.minute)
		normalized.weekday = components.weekday
		return normalized
	}

	private static func oneTimeComponents(from components: DateComponents) -> DateComponents {
		DateComponents(year: components.year, month: components.month, day: components.day, hour: components.hour, minute: components.minute)
	}

	private static func components(for identity: Identity) -> DateComponents {
		if identity.repeats {
			var components = DateComponents(hour: identity.hour, minute: identity.minute)
			components.weekday = identity.weekday
			return components
		}
		return DateComponents(year: identity.year, month: identity.month, day: identity.day, hour: identity.hour, minute: identity.minute)
	}

	private static func canonicalRequest(
		from source: UNNotificationRequest,
		identity: Identity,
		interruptionLevel: UNNotificationInterruptionLevel
	) -> UNNotificationRequest? {
		guard let content = source.content.mutableCopy() as? UNMutableNotificationContent else {
			return nil
		}
		content.interruptionLevel = interruptionLevel
		let trigger = UNCalendarNotificationTrigger(dateMatching: components(for: identity), repeats: identity.repeats)
		return UNNotificationRequest(identifier: identity.identifier, content: content, trigger: trigger)
	}
}

private extension MedicationReminderRequest.Identity {
	init(medicationID: UUID, repeats: Bool, components: DateComponents) {
		self.medicationID = medicationID
		self.repeats = repeats
		year = components.year
		month = components.month
		day = components.day
		weekday = components.weekday
		hour = components.hour
		minute = components.minute
	}
}

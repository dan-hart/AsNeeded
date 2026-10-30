import Foundation

/// Pure projection of known future availability into notification intent.
struct MedicationAvailabilityNotificationPlanner {
	static let identifierPrefix = "availability."
	static let categoryIdentifier = "MEDICATION_AVAILABILITY"

	struct Candidate {
		let medicationID: UUID
		let medicationName: String
		let enabled: Bool
		let archived: Bool
		let eligibleDate: Date?
	}

	struct Notification {
		let identifier: String
		let medicationID: UUID
		let date: Date
		let title: String
		let body: String
	}

	func notifications(for candidates: [Candidate], at now: Date, showMedicationNames: Bool) -> [Notification] {
		candidates.compactMap { candidate in
			guard candidate.enabled, !candidate.archived,
				let date = candidate.eligibleDate, date > now else { return nil }
			return Notification(
				identifier: Self.identifierPrefix + candidate.medicationID.uuidString,
				medicationID: candidate.medicationID,
				date: date,
				title: showMedicationNames ? candidate.medicationName : String(localized: "Next Dose Availability"),
				body: showMedicationNames
					? String(localized: "The waiting time based on your saved dose guidance for \(candidate.medicationName) has passed. Review your instructions before taking a dose.")
					: String(localized: "The waiting time based on your saved dose guidance has passed. Review your medication instructions before taking a dose.")
			)
		}
	}

	func identifiersToRemove(pending: [String], desired: [Notification]) -> [String] {
		let desiredIDs = Set(desired.map(\.identifier))
		return pending.filter { $0.hasPrefix(Self.identifierPrefix) && !desiredIDs.contains($0) }
	}
}

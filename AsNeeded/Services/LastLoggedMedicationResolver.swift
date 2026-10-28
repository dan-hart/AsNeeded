import ANModelKit
import Foundation

/// Recording recency uses committed event identities; dates are only an upgrade
/// or unavailable-target fallback because a newly recorded dose can be backdated.
enum LastLoggedMedicationResolver {
	static func resolve(
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		lastLoggedEventIDs: [UUID]
	) -> ANMedicationConcept? {
		func currentMedication(for event: ANEventConcept) -> ANMedicationConcept? {
			guard event.eventType == .doseTaken, let medicationID = event.medication?.id else { return nil }
			return medications.first { $0.id == medicationID && !$0.isArchived }
		}
		let eventsByID = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		for id in lastLoggedEventIDs {
			if let event = eventsByID[id], let medication = currentMedication(for: event) {
				return medication
			}
		}
		// Undo, deletion and archiving can invalidate the saved pointer. Preserve
		// an available historical target, or let the caller open the selector.
		return events.sorted {
			if $0.date != $1.date { return $0.date > $1.date }
			return $0.id.uuidString < $1.id.uuidString
		}.lazy.compactMap { currentMedication(for: $0) }.first
	}
}

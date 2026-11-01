import ANModelKit
import Foundation

@MainActor
struct NotificationDoseLogger {
	let dataStore: DataStore
	let prepare: () async throws -> Void
	let profile: (UUID) -> MedicationSafetyProfile
	var now: () -> Date = { .now }

	enum Failure: Error { case reviewRequired }

	func log(_ action: MedicationNotificationAction) async throws -> ANEventConcept {
		guard action.kind == .log else { throw Failure.reviewRequired }
		try await prepare()
		return try await dataStore.recordDose(shouldRecordForReview: false, makeEvent: { snapshot in
			// A retry must preserve the original dose/date even if the prescription changed.
			if let existing = snapshot.events.first(where: { $0.id == action.eventID }) {
				guard existing.eventType == .doseTaken, existing.medication?.id == action.medicationID else {
					throw Failure.reviewRequired
				}
				return existing
			}
			guard let medication = snapshot.medications.first(where: { $0.id == action.medicationID && !$0.isArchived }),
				let amount = medication.prescribedDoseAmount, amount.isFinite, amount > 0,
				let unit = medication.prescribedUnit else { throw Failure.reviewRequired }
			// Read time only after acquiring storage ownership. A later commit must see earlier doses.
			let date = now()
			guard date.timeIntervalSince1970.isFinite else { throw Failure.reviewRequired }
			let dose = ANDoseConcept(amount: amount, unit: unit)
			let assessment = MedicationDoseGuidanceService().assessment(for: medication, proposedDose: dose,
				at: date, events: snapshot.events, profile: profile(medication.id))
			guard assessment.severity == .clear else { throw Failure.reviewRequired }
			return ANEventConcept(id: action.eventID, eventType: .doseTaken, medication: medication, dose: dose, date: date)
		})
	}
}

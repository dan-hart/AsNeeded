import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("Next Dose Shortcut Selection")
struct GetNextDoseIntentTests {
	@Test("No-argument shortcut ignores archived medications")
	func ignoresArchivedMedications() {
		var archived = ANMedicationConcept(clinicalName: "Archived")
		archived.isArchived = true
		#expect(GetNextDoseIntent.selectMedication(from: [archived], at: .now, events: [], profiles: [:]) == nil)
	}

	@Test("Unknown availability does not outrank a calculated dose window")
	func prefersKnownAvailability() {
		let now = Date(timeIntervalSince1970: 1_800_000_000)
		let unknown = ANMedicationConcept(clinicalName: "A Unknown")
		var known = ANMedicationConcept(clinicalName: "Z Known")
		known.minimumHoursBetweenDoses = 4
		let event = ANEventConcept(eventType: .doseTaken, medication: known, dose: ANDoseConcept(amount: 1, unit: .tablet), date: now.addingTimeInterval(-3600))
		let selected = GetNextDoseIntent.selectMedication(from: [unknown, known], at: now, events: [event], profiles: [:])
		#expect(selected?.id == known.id)
	}
}

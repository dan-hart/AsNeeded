import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct LogDoseSessionTests {
	@Test("A rehosted dose form retains inputs and its in-flight save guard")
	func retainedDoseDraft() {
		let medication = ANMedicationConcept(clinicalName: "Example", prescribedUnit: .tablet, prescribedDoseAmount: 0.5)
		let session = LogDoseView.Session()
		let draft = session.draft(for: medication)
		#expect(draft.amount == 0.5)
		#expect(draft.selectedUnit == .tablet)
		draft.amount = 1.5
		draft.reason = "Demo reason"
		draft.note = "Demo note"
		draft.selectedDate = Date(timeIntervalSince1970: 1_700_000_000)
		draft.symptomSeverityBefore = 3
		draft.isLogging = true
		let rehosted = session.draft(for: medication)
		#expect(rehosted === draft)
		#expect(rehosted.amount == 1.5)
		#expect(rehosted.reason == "Demo reason")
		#expect(rehosted.note == "Demo note")
		#expect(rehosted.selectedDate == Date(timeIntervalSince1970: 1_700_000_000))
		#expect(rehosted.symptomSeverityBefore == 3)
		#expect(rehosted.isLogging)
	}

	@Test("Finishing a dose form or choosing another medication starts fresh")
	func freshDoseDraft() {
		let first = ANMedicationConcept(clinicalName: "First example")
		let second = ANMedicationConcept(clinicalName: "Second example")
		let session = LogDoseView.Session()
		let previous = session.draft(for: first)
		previous.reason = "Previous reason"
		session.reset()
		let next = session.draft(for: first)
		#expect(next !== previous)
		#expect(next.reason.isEmpty)
		#expect(!next.isLogging)
		let different = session.draft(for: second)
		#expect(different !== next)
		#expect(different.note.isEmpty)
	}
}

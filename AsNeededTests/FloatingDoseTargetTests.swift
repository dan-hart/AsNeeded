import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("Floating dose selection")
struct FloatingDoseTargetTests {
	@Test("An explicit filter always wins over the last medication logged")
	func selectedTarget() {
		let first = ANMedicationConcept(clinicalName: "Synthetic A")
		let second = ANMedicationConcept(clinicalName: "Synthetic B")
		#expect(LogDosePickerModel.quickLogMedication(selectedID: first.id, useLastLogged: false,
			lastLoggedID: second.id, from: [first, second])?.id == first.id)
	}

	@Test("Missing and archived selections never fall back to another medication", arguments: [true, false])
	func unavailableSelection(_ archived: Bool) {
		var first = ANMedicationConcept(clinicalName: "Synthetic A")
		first.isArchived = archived
		let second = ANMedicationConcept(clinicalName: "Synthetic B")
		let medications = archived ? [first, second] : [second]
		#expect(LogDosePickerModel.quickLogMedication(selectedID: first.id, useLastLogged: false,
			lastLoggedID: second.id, from: medications) == nil)
	}

	@Test("All uses the last logged current record, while an empty filter offers the chooser")
	func allAndUnselected() {
		let medication = ANMedicationConcept(clinicalName: "Current name", prescribedDoseAmount: 2)
		let target = LogDosePickerModel.quickLogMedication(selectedID: nil, useLastLogged: true,
			lastLoggedID: medication.id, from: [medication])
		#expect(target?.clinicalName == "Current name")
		#expect(target?.prescribedDoseAmount == 2)
		#expect(LogDosePickerModel.quickLogMedication(selectedID: nil, useLastLogged: false,
			lastLoggedID: medication.id, from: [medication]) == nil)
		#expect(LogDosePickerModel.quickLogMedication(selectedID: nil, useLastLogged: true,
			lastLoggedID: nil, from: [medication]) == nil)
	}
}

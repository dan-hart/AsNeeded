import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("Log Dose Picker")
struct LogDosePickerModelTests {
	@Test("Widget dose links select only the exact active medication")
	func deepLinkSelection() {
		let first = ANMedicationConcept(clinicalName: "Synthetic first")
		let second = ANMedicationConcept(clinicalName: "Synthetic second")
		var archived = ANMedicationConcept(clinicalName: "Synthetic archived")
		archived.isArchived = true
		let medications = [first, second, archived]
		#expect(LogDosePickerModel.medication(forDeepLink: second.id.uuidString.lowercased(), from: medications)?.id == second.id)
		#expect(LogDosePickerModel.medication(forDeepLink: archived.id.uuidString, from: medications) == nil)
		#expect(LogDosePickerModel.medication(forDeepLink: UUID().uuidString, from: medications) == nil)
		#expect(LogDosePickerModel.medication(forDeepLink: "invalid", from: medications) == nil)
	}

	@Test("Choices exclude archived medications and keep the existing list order")
	func activeChoicesKeepOrder() {
		let first = ANMedicationConcept(clinicalName: "Synthetic Z")
		let second = ANMedicationConcept(clinicalName: "Synthetic A")
		var archived = ANMedicationConcept(clinicalName: "Synthetic archived")
		archived.isArchived = true
		let choices = LogDosePickerModel.medications(from: [first, archived, second])
		#expect(choices.map(\.id) == [first.id, second.id])
	}

	@Test("Search matches clinical and display names without changing identity or order")
	func searchMatchesBothNames() {
		let medication = ANMedicationConcept(clinicalName: "Synthetic clinical", nickname: "Example relief")
		let other = ANMedicationConcept(clinicalName: "Other example")
		let medications = [medication, other]
		#expect(LogDosePickerModel.medications(from: medications, matching: "  CLINICAL  ").map(\.id) == [medication.id])
		#expect(LogDosePickerModel.medications(from: medications, matching: "relief").map(\.id) == [medication.id])
		#expect(LogDosePickerModel.medications(from: medications, matching: "example").map(\.id) == [medication.id, other.id])
		#expect(LogDosePickerModel.medications(from: medications, matching: "  \n  ").map(\.id) == medications.map(\.id))
	}

	@Test("Empty, unavailable and archived-only choices stay empty")
	func unavailableChoices() {
		var archived = ANMedicationConcept(clinicalName: "Synthetic archived", nickname: "Hidden")
		archived.isArchived = true
		#expect(LogDosePickerModel.medications(from: []).isEmpty)
		#expect(LogDosePickerModel.medications(from: [archived], matching: "Hidden").isEmpty)
		let active = ANMedicationConcept(clinicalName: "Synthetic active")
		#expect(LogDosePickerModel.medications(from: [active], matching: "absent").isEmpty)
	}
}

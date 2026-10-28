import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct DoseStockStabilityTests {
	@Test("Logging an older snapshot cannot recreate a deleted medication", arguments: ["detail", "list", "quick"])
	func deletedMedicationIsNotRecreated(surface: String) async throws {
		let store = DataStore(testIdentifier: UUID().uuidString)
		let medication = ANMedicationConcept(clinicalName: "Deleted example", quantity: 10.5, prescribedUnit: .tablet, prescribedDoseAmount: 0.5)
		try await store.addMedication(medication)
		try await store.deleteMedication(medication)
		let dose = ANDoseConcept(amount: 0.5, unit: .tablet)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose, date: Date())
		let saved: Bool
		switch surface {
		case "detail": saved = await MedicationDetailViewModel(dataStore: store).logDose(medication: medication, dose: dose, event: event, source: "stability_test")
		case "list": saved = await MedicationListViewModel(dataStore: store).logDose(med: medication, dose: dose, event: event)
		default: saved = await MedicationListViewModel(dataStore: store).quickLog(medication: medication)
		}
		#expect(!saved)
		#expect(store.medications.isEmpty)
		#expect(store.events.isEmpty)
	}

	@Test("Logging from an older medication snapshot preserves current stock and edits", arguments: ["detail", "list", "quick"])
	func staleSnapshotDoesNotResetStock(surface: String) async throws {
		let store = DataStore(testIdentifier: UUID().uuidString)
		let original = ANMedicationConcept(clinicalName: "Original example", quantity: 10.5, prescribedUnit: .tablet, prescribedDoseAmount: 0.5)
		try await store.addMedication(original)
		let detail = MedicationDetailViewModel(dataStore: store)
		let list = MedicationListViewModel(dataStore: store)
		let dose = ANDoseConcept(amount: 0.5, unit: .tablet)
		for index in 0..<2 {
			let event = ANEventConcept(eventType: .doseTaken, medication: original, dose: dose, date: Date())
			let saved: Bool
			switch surface {
			case "detail": saved = await detail.logDose(medication: original, dose: dose, event: event, source: "stability_test")
			case "list": saved = await list.logDose(med: original, dose: dose, event: event)
			default: saved = await list.quickLog(medication: original)
			}
			#expect(saved)
			if index == 0 {
				var updated = try #require(store.medications.first)
				updated.nickname = "Edited example"
				try await store.updateMedication(updated)
			}
		}
		#expect(store.events.count == 2)
		#expect(store.medications.first?.quantity == 9.5)
		#expect(store.medications.first?.nickname == "Edited example")
	}
}

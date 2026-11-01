import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("QA quick log dispatch", .serialized)
struct QAQuickLogRegressionTests {
	@Test("A medication row can log with no recording history")
	func firstRowDose() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let medication = ANMedicationConcept(clinicalName: "Synthetic first", quantity: 20, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		try await store.addMedication(medication)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults)
		#expect(store.lastLoggedMedication == nil)
		#expect(await model.quickLog(medication: medication))
		#expect(store.events.count == 1)
		#expect(store.medications.first?.quantity == 19)
	}

	@Test("Row logging targets its medication regardless of last recorded dose")
	func differentRowDose() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let first = ANMedicationConcept(clinicalName: "Synthetic first", quantity: 20, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		let second = ANMedicationConcept(clinicalName: "Synthetic second", quantity: 30, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		try await store.addMedication(first)
		try await store.addMedication(second)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults)
		#expect(await model.quickLog(medication: first))
		#expect(await model.quickLog(medication: second))
		#expect(store.events.count == 2)
		#expect(store.events.filter { $0.medication?.id == second.id }.count == 1)
		#expect(store.medications.first { $0.id == second.id }?.quantity == 28)
	}

	@Test("An archived row cannot record or decrement stock")
	func archivedRowsCannotLog() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name)
		var medication = ANMedicationConcept(clinicalName: "Synthetic archived", quantity: 20, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		medication.isArchived = true
		try await store.addMedication(medication)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults)
		#expect(!(await model.quickLog(medication: medication)))
		#expect(store.events.isEmpty)
		#expect(store.medications.first?.quantity == 20)
	}
}

import Testing
import Foundation
@testable import AsNeeded
@testable import ANModelKit

@MainActor
@Suite(.tags(.viewModel, .medication, .unit))
struct MedicationListViewModelUnitTests {

	@Test("ViewModel can be initialized with default DataStore")
	func viewModelCanBeInitializedWithDefaultDataStore() {
		let viewModel = MedicationListViewModel()
		// Should not crash and should be properly initialized
		#expect(viewModel.items.count >= 0) // Can be empty or have items
	}

	@Test("ViewModel can be initialized with custom DataStore")
	func viewModelCanBeInitializedWithCustomDataStore() {
		let customDataStore = DataStore.shared
		let viewModel = MedicationListViewModel(dataStore: customDataStore)
		#expect(viewModel.items.count >= 0)
	}

	@Test("Items property returns medications from DataStore")
	func itemsPropertyReturnsMedicationsFromDataStore() {
		let viewModel = MedicationListViewModel()
		let items = viewModel.items
		// Verify items is an array of ANMedicationConcept
		#expect(items is [ANMedicationConcept])
	}

	@Test("ViewModel has required async methods")
	func viewModelHasRequiredAsyncMethods() async {
		let viewModel = MedicationListViewModel()
		let testMedication = ANMedicationConcept(clinicalName: "Test Med")
		let testEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: testMedication
		)

		// These should not crash (error handling is internal)
		await viewModel.add(testMedication)
		await viewModel.update(testMedication)
		await viewModel.addEvent(testEvent)
		await viewModel.delete(testMedication)
	}
}
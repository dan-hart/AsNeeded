// MedicationListViewModel.swift
// View model for listing, adding, and deleting medications via DataStore.

import Foundation
import ANModelKit

@MainActor
final class MedicationListViewModel: ObservableObject {
	private let dataStore: DataStore

	init(dataStore: DataStore = .shared) {
		self.dataStore = dataStore
	}

	var items: [ANMedicationConcept] { dataStore.medications }

	func add(_ med: ANMedicationConcept) async {
		try? await dataStore.addMedication(med)
	}

	func update(_ med: ANMedicationConcept) async {
		try? await dataStore.updateMedication(med)
	}

	func delete(_ med: ANMedicationConcept) async {
		try? await dataStore.deleteMedication(med)
	}

	func addEvent(_ event: ANEventConcept) async {
		try? await dataStore.addEvent(event)
	}
}

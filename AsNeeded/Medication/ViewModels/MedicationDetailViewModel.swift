// MedicationDetailViewModel.swift
// View model for medication detail operations via DataStore.

import Foundation
import ANModelKit

@MainActor
final class MedicationDetailViewModel: ObservableObject {
	private let dataStore: DataStore

	init(dataStore: DataStore = .shared) {
		self.dataStore = dataStore
	}

	func save(updated medication: ANMedicationConcept) async {
		try? await dataStore.updateMedication(medication)
	}

	func delete(_ medication: ANMedicationConcept) async {
		try? await dataStore.deleteMedication(medication)
	}

	func log(event: ANEventConcept) async {
		try? await dataStore.addEvent(event)
	}
}

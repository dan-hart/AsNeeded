// MedicationListViewModel.swift
// View model for listing, adding, and deleting medications via DataStore.

import Foundation
import ANModelKit
import DHLoggingKit

@MainActor
final class MedicationListViewModel: ObservableObject {
	private let dataStore: DataStore
	private let logger = DHLogger.ui

	init(dataStore: DataStore = .shared) {
		self.dataStore = dataStore
	}

	var items: [ANMedicationConcept] { dataStore.medications }

	func add(_ med: ANMedicationConcept) async -> Bool {
		do {
			try await dataStore.addMedication(med)
			return true
		} catch {
			// Log error but don't crash app
			print("Failed to add medication: \(error)")
			return false
		}
	}

	func update(_ med: ANMedicationConcept) async -> Bool {
		do {
			try await dataStore.updateMedication(med)
			return true
		} catch {
			print("Failed to update medication: \(error)")
			return false
		}
	}

	func delete(_ med: ANMedicationConcept) async -> Bool {
		do {
			try await dataStore.deleteMedication(med)
			return true
		} catch {
			print("Failed to delete medication: \(error)")
			return false
		}
	}

	func addEvent(_ event: ANEventConcept, shouldRecordForReview: Bool = true) async -> Bool {
		do {
			try await dataStore.addEvent(event, shouldRecordForReview: shouldRecordForReview)
			return true
		} catch {
			print("Failed to add event: \(error)")
			return false
		}
	}
}

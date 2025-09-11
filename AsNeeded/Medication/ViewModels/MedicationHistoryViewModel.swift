// MedicationHistoryViewModel.swift
// View model for presenting and mutating medication dose history.

import Foundation
import SwiftUI
import ANModelKit

@MainActor
final class MedicationHistoryViewModel: ObservableObject {
	@AppStorage("historySelectedMedicationID") private var selectedMedicationIDString: String = ""
	
	@Published var selectedMedicationID: UUID? {
		didSet {
			selectedMedicationIDString = selectedMedicationID?.uuidString ?? ""
		}
	}
	
	@Published var medications: [ANMedicationConcept] = []
	@Published var events: [ANEventConcept] = []

	private let dataStore: DataStore

	init(dataStore: DataStore = .shared, selectedMedicationID: UUID? = nil) {
		self.dataStore = dataStore
		
		// Initialize from passed ID or from AppStorage
		if let initialID = selectedMedicationID {
			self.selectedMedicationID = initialID
		} else if !selectedMedicationIDString.isEmpty {
			self.selectedMedicationID = UUID(uuidString: selectedMedicationIDString)
		}
		
		// Load initial data and observe changes
		loadData()
		observeStoreChanges()
		
		// Ensure we have a valid selection
		ensureValidSelection()
	}
	
	private func loadData() {
		medications = dataStore.medications
		events = dataStore.events
	}
	
	private func observeStoreChanges() {
		// Set up a timer to periodically refresh data
		// This ensures we catch any data changes from the stores
		Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			Task { @MainActor in
				let newMedications = self.dataStore.medications
				let newEvents = self.dataStore.events
				
				if self.medications != newMedications {
					self.medications = newMedications
					self.ensureValidSelection()
				}
				
				if self.events != newEvents {
					self.events = newEvents
				}
			}
		}
	}
	
	/// Ensures we always have a valid medication selected
	/// This prevents picker errors when selection is nil
	func ensureValidSelection() {
		// If no medications are loaded yet, wait
		guard !medications.isEmpty else { return }
		
		// If we have a selection and it's valid, keep it
		if let id = selectedMedicationID, medications.contains(where: { $0.id == id }) {
			return
		}
		
		// Otherwise, select the first medication
		selectedMedicationID = medications.first?.id
	}
	
	/// Legacy method for compatibility
	func validateSelectedMedication() {
		ensureValidSelection()
	}


	var selectedMedication: ANMedicationConcept? {
		guard let id = selectedMedicationID else { return nil }
		return medications.first { $0.id == id }
	}

	var groupedHistory: [(day: Date, entries: [ANEventConcept])] {
		guard let id = selectedMedicationID else { return [] }
		let filteredEvents = events.filter { $0.medication?.id == id && $0.eventType == .doseTaken }
		guard !filteredEvents.isEmpty else { return [] }
		let calendar = Calendar.current
		let grouped = Dictionary(grouping: filteredEvents) { event in
			calendar.startOfDay(for: event.date)
		}
		return grouped
			.map { (day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
			.sorted { $0.day > $1.day }
	}

	func deleteEvents(at offsets: IndexSet, in groupDay: Date) async {
		guard let id = selectedMedicationID else { return }
		let calendar = Calendar.current
		var filtered: [ANEventConcept] = events.filter { event in
			event.medication?.id == id && event.eventType == .doseTaken && calendar.startOfDay(for: event.date) == groupDay
		}
		// Match UI ordering: most recent first within a day
		filtered.sort { $0.date > $1.date }
		let toDelete = offsets.compactMap { index in
			filtered[doesExistAt: index]
		}
		for event in toDelete {
			try? await dataStore.eventsStore.remove(event)
			if let dose = event.dose,
			   let medicationID = event.medication?.id,
			   let medication = medications.first(where: { $0.id == medicationID }) {
				var updated = medication
				if let quantity = updated.quantity {
					updated.quantity = quantity + dose.amount
				}
				try? await dataStore.updateMedication(updated)
			}
		}
	}
	
	func updateEvent(_ event: ANEventConcept) async {
		// Find and update the event in the store
		if let index = dataStore.events.firstIndex(where: { $0.id == event.id }),
		   let existingEvent = dataStore.events[doesExistAt: index] {
			try? await dataStore.eventsStore.remove(existingEvent)
			try? await dataStore.eventsStore.insert(event)
		}
	}
}

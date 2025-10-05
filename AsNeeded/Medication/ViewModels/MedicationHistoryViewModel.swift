// MedicationHistoryViewModel.swift
// View model for presenting and mutating medication dose history.

import Foundation
import SwiftUI
import ANModelKit

@MainActor
final class MedicationHistoryViewModel: ObservableObject {
	@AppStorage("historySelectedMedicationID") private var selectedMedicationIDString: String = ""

	@Published var selectedMedicationID: String? {
		didSet {
			selectedMedicationIDString = selectedMedicationID ?? ""
		}
	}
	
	@Published var medications: [ANMedicationConcept] = []
	@Published var events: [ANEventConcept] = []

	private let dataStore: DataStore

	init(dataStore: DataStore = .shared, selectedMedicationID: String? = nil) {
		self.dataStore = dataStore

		// Initialize from passed ID or from AppStorage
		if let initialID = selectedMedicationID {
			self.selectedMedicationID = initialID
		} else if !selectedMedicationIDString.isEmpty {
			self.selectedMedicationID = selectedMedicationIDString
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
		if let selection = selectedMedicationID {
			// Check if it's "all" or a valid medication UUID
			if selection == "all" || medications.contains(where: { $0.id.uuidString == selection }) {
				return
			}
		}

		// Otherwise, set "all" as the default
		selectedMedicationID = "all"
	}
	
	/// Legacy method for compatibility
	func validateSelectedMedication() {
		ensureValidSelection()
	}


	var isShowingAllMedications: Bool {
		selectedMedicationID == "all"
	}

	var selectedMedication: ANMedicationConcept? {
		guard let selection = selectedMedicationID, selection != "all",
			  let uuid = UUID(uuidString: selection) else { return nil }
		return medications.first { $0.id == uuid }
	}

	var groupedHistory: [(day: Date, entries: [ANEventConcept])] {
		let filteredEvents: [ANEventConcept]

		if isShowingAllMedications {
			// Show all dose events for all medications
			filteredEvents = events.filter { $0.eventType == .doseTaken }
		} else {
			// Show events for selected medication only
			guard let selection = selectedMedicationID,
				  let uuid = UUID(uuidString: selection) else { return [] }
			filteredEvents = events.filter { $0.medication?.id == uuid && $0.eventType == .doseTaken }
		}

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
		let calendar = Calendar.current
		var filtered: [ANEventConcept]

		if isShowingAllMedications {
			// Filter all dose events for the specific day
			filtered = events.filter { event in
				event.eventType == .doseTaken && calendar.startOfDay(for: event.date) == groupDay
			}
		} else {
			// Filter events for selected medication only
			guard let selection = selectedMedicationID,
				  let uuid = UUID(uuidString: selection) else { return }
			filtered = events.filter { event in
				event.medication?.id == uuid && event.eventType == .doseTaken && calendar.startOfDay(for: event.date) == groupDay
			}
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
	
	func updateEvent(_ event: ANEventConcept, newDate: Date, newAmount: Double, newUnit: ANUnitConcept) async {
		// Calculate the difference in dose amount
		let oldAmount = event.dose?.amount ?? 0
		let difference = newAmount - oldAmount

		// Create updated event with new dose and date
		var updatedEvent = event
		updatedEvent.date = newDate
		updatedEvent.dose = ANDoseConcept(amount: newAmount, unit: newUnit)

		// Update event in store
		if let index = dataStore.events.firstIndex(where: { $0.id == event.id }),
		   let existingEvent = dataStore.events[doesExistAt: index] {
			try? await dataStore.eventsStore.remove(existingEvent)
			try? await dataStore.eventsStore.insert(updatedEvent)
		}

		// Adjust medication quantity by the difference
		if let medicationID = event.medication?.id,
		   let medication = medications.first(where: { $0.id == medicationID }),
		   let quantity = medication.quantity {
			var updated = medication
			updated.quantity = quantity - difference
			try? await dataStore.updateMedication(updated)
		}
	}

	func updateEventNote(_ event: ANEventConcept) async {
		// Legacy method for updating just the note without dose changes
		if let index = dataStore.events.firstIndex(where: { $0.id == event.id }),
		   let existingEvent = dataStore.events[doesExistAt: index] {
			try? await dataStore.eventsStore.remove(existingEvent)
			try? await dataStore.eventsStore.insert(event)
		}
	}

	func deleteEvent(_ event: ANEventConcept) async {
		// Delete the event and restore medication quantity if needed
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

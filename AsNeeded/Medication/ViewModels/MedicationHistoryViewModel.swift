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

	private let dataStore: DataStore

	init(dataStore: DataStore = .shared, selectedMedicationID: UUID? = nil) {
		self.dataStore = dataStore
		
		// Initialize from passed ID or from AppStorage
		if let initialID = selectedMedicationID {
			self.selectedMedicationID = initialID
		} else if !selectedMedicationIDString.isEmpty {
			self.selectedMedicationID = UUID(uuidString: selectedMedicationIDString)
		}
	}

	var medications: [ANMedicationConcept] { dataStore.medications }
	var events: [ANEventConcept] { dataStore.events }

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
		let toDelete = offsets.map { filtered[$0] }
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
}

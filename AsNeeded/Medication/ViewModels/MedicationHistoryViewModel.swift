// MedicationHistoryViewModel.swift
// View model for presenting and mutating medication dose history.

import Foundation
import ANModelKit

@MainActor
final class MedicationHistoryViewModel: ObservableObject {
    @Published var selectedMedicationID: UUID?

    private let appStore: DataStore

    init(appStore: DataStore = .shared, selectedMedicationID: UUID? = nil) {
        self.appStore = appStore
        self.selectedMedicationID = selectedMedicationID
    }

    var medications: [ANMedicationConcept] { appStore.medications }
    var events: [ANEventConcept] { appStore.events }

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
            .map { (day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }

    func deleteEvents(at offsets: IndexSet, in groupDay: Date) async {
        guard let id = selectedMedicationID else { return }
        let calendar = Calendar.current
        let filtered: [ANEventConcept] = events.filter { event in
            event.medication?.id == id && event.eventType == .doseTaken && calendar.startOfDay(for: event.date) == groupDay
        }
        let toDelete = offsets.map { filtered[$0] }
        for event in toDelete {
            try? await appStore.eventsStore.remove(event)
            if let dose = event.dose,
               let medicationID = event.medication?.id,
               let medication = medications.first(where: { $0.id == medicationID }) {
                var updated = medication
                if let quantity = updated.quantity {
                    updated.quantity = quantity + dose.amount
                }
                try? await appStore.updateMedication(updated)
            }
        }
    }
}

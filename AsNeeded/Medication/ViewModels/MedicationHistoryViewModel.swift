// MedicationHistoryViewModel.swift
// View model for presenting and mutating medication dose history.

import ANModelKit
import Boutique
import Combine
import Foundation
import SwiftUI

@MainActor
final class MedicationHistoryViewModel: ObservableObject {
	/// One calendar day of dose history, newest entry first.
	struct DayGroup: Identifiable, Equatable {
		let day: Date
		let entries: [ANEventConcept]

		var id: Date { day }
	}

    @AppStorage(UserDefaultsKeys.historySelectedMedicationID) private var selectedMedicationIDString: String = ""

    @Published var selectedMedicationID: String? {
        didSet {
            selectedMedicationIDString = selectedMedicationID ?? ""
			rebuildGroupedHistory()
        }
    }

    @Published private(set) var medications: [ANMedicationConcept] = []
    @Published private(set) var events: [ANEventConcept] = [] {
		didSet {
			rebuildGroupedHistory()
		}
	}

	/// Dose events for the current selection, grouped by day and sorted newest day first.
	/// Rebuilt only when the events or the selection change, so rendering never re-filters the store.
	@Published private(set) var groupedHistory: [DayGroup] = []

    private let dataStore: DataStore
	private let calendar = Calendar.current
	/// Shared quick-log core (compensating writes, haptics, feedback, toast state).
	let quickLogCoordinator: QuickLogCoordinator
	private var quickLogCoordinatorSubscription: AnyCancellable?
	private var storeObservationTasks: [Task<Void, Never>] = []

	// MARK: - Quick Log Toast State
	// Forwarded from the coordinator; its `objectWillChange` is re-published so views observing this
	// view model refresh when the toast changes.
	var showQuickLogToast: Bool { quickLogCoordinator.showQuickLogToast }
	var quickLogMedicationName: String { quickLogCoordinator.quickLogMedicationName }
	var quickLogDoseAmount: Double { quickLogCoordinator.quickLogDoseAmount }
	var quickLogDoseUnit: String { quickLogCoordinator.quickLogDoseUnit }
	var quickLogAccentColor: Color { quickLogCoordinator.quickLogAccentColor }
	var quickLogFeedback: QuickLogFeedbackService.Feedback? { quickLogCoordinator.quickLogFeedback }
	var quickLogToastGeneration: UUID? { quickLogCoordinator.quickLogToastGeneration }

    init(
		dataStore: DataStore = .shared,
		selectedMedicationID: String? = nil,
		quickLogCoordinator: QuickLogCoordinator? = nil
	) {
        self.dataStore = dataStore
		self.quickLogCoordinator = quickLogCoordinator ?? QuickLogCoordinator(dataStore: dataStore)
		quickLogCoordinatorSubscription = self.quickLogCoordinator.objectWillChange.sink { [weak self] _ in
			self?.objectWillChange.send()
		}

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
		rebuildGroupedHistory()
    }

	deinit {
		storeObservationTasks.forEach { $0.cancel() }
	}

    private func loadData() {
        medications = dataStore.medications
        events = dataStore.events
    }

	/// Follows the Boutique stores' event streams so the view updates the moment data loads or changes.
	/// The streams replay their latest event on subscription, which also covers a store that finished
	/// loading from disk before this view model was created.
    private func observeStoreChanges() {
		let medicationsStore = dataStore.medicationsStore
		let eventsStore = dataStore.eventsStore

		storeObservationTasks = [
			Task { [weak self] in
				for await event in medicationsStore.events {
					guard !Task.isCancelled else { return }
					if case .initialized = event.operation { continue }
					self?.refreshMedications()
				}
			},
			Task { [weak self] in
				for await event in eventsStore.events {
					guard !Task.isCancelled else { return }
					if case .initialized = event.operation { continue }
					self?.refreshEvents()
				}
			},
		]
    }

	private func refreshMedications() {
		let latest = dataStore.medications
		guard latest != medications else { return }
		medications = latest
		ensureValidSelection()
	}

	private func refreshEvents() {
		let latest = dataStore.events
		guard latest != events else { return }
		events = latest
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

	private func rebuildGroupedHistory() {
		let rebuilt = Self.groupByDay(events: events, selection: selectedMedicationID, calendar: calendar)
		guard rebuilt != groupedHistory else { return }
		groupedHistory = rebuilt
	}

	private static func groupByDay(
		events: [ANEventConcept],
		selection: String?,
		calendar: Calendar
	) -> [DayGroup] {
        let filteredEvents: [ANEventConcept]

        if selection == "all" {
            // Show all dose events for all medications
            filteredEvents = events.filter { $0.eventType == .doseTaken }
        } else {
            // Show events for selected medication only
            guard let selection,
                  let uuid = UUID(uuidString: selection) else { return [] }
            filteredEvents = events.filter { $0.medication?.id == uuid && $0.eventType == .doseTaken }
        }

        guard !filteredEvents.isEmpty else { return [] }
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.date)
        }
        return grouped
            .map { DayGroup(day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
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
               let medication = medications.first(where: { $0.id == medicationID })
            {
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
           let existingEvent = dataStore.events[doesExistAt: index]
        {
            try? await dataStore.eventsStore.remove(existingEvent)
            try? await dataStore.eventsStore.insert(updatedEvent)
        }

        // Adjust medication quantity by the difference
        if let medicationID = event.medication?.id,
           let medication = medications.first(where: { $0.id == medicationID }),
           let quantity = medication.quantity
        {
            var updated = medication
            updated.quantity = quantity - difference
            try? await dataStore.updateMedication(updated)
        }
    }

    func updateEventNote(_ event: ANEventConcept) async {
        // Legacy method for updating just the note without dose changes
        if let index = dataStore.events.firstIndex(where: { $0.id == event.id }),
           let existingEvent = dataStore.events[doesExistAt: index]
        {
            try? await dataStore.eventsStore.remove(existingEvent)
            try? await dataStore.eventsStore.insert(event)
        }
    }

	// MARK: - Dose Logging
	/// Logs the medication's default dose (long press on the floating Log Dose button).
	func quickLog(medication: ANMedicationConcept) async -> Bool {
		await quickLogCoordinator.quickLog(medication: medication, source: "history_quick_log")
	}

	/// Logs a dose chosen in the Log Dose sheet with compensating writes.
	func logDose(
		medication: ANMedicationConcept,
		dose: ANDoseConcept,
		event: ANEventConcept,
		operationID: UUID = UUID()
	) async -> Bool {
		await quickLogCoordinator.logDose(
			medication: medication,
			dose: dose,
			event: event,
			source: "history_sheet",
			operationID: operationID
		)
	}

	func undoLastQuickLog() async -> Bool {
		await quickLogCoordinator.undoLastQuickLog()
	}

	func dismissQuickLogToast() {
		quickLogCoordinator.dismissQuickLogToast()
	}

    func deleteEvent(_ event: ANEventConcept) async {
        // Delete the event and restore medication quantity if needed
        try? await dataStore.eventsStore.remove(event)
        if let dose = event.dose,
           let medicationID = event.medication?.id,
           let medication = medications.first(where: { $0.id == medicationID })
        {
            var updated = medication
            if let quantity = updated.quantity {
                updated.quantity = quantity + dose.amount
            }
            try? await dataStore.updateMedication(updated)
        }
    }
}

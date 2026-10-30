// MedicationHistoryViewModel.swift
// View model for presenting and mutating medication dose history.

import ANModelKit
import DHLoggingKit
import Foundation
import SwiftUI
import UIKit

@MainActor
final class MedicationHistoryViewModel: ObservableObject {
	@AppStorage(UserDefaultsKeys.historySelectedMedicationID) private var selectedMedicationIDString: String = ""

	@Published var selectedMedicationID: String? {
		didSet {
			selectedMedicationIDString = selectedMedicationID ?? ""
			cachedGroupedHistory = nil
		}
	}

	@Published var medications: [ANMedicationConcept] = []
	@Published var events: [ANEventConcept] = [] {
		didSet { cachedGroupedHistory = nil }
	}
	@Published private(set) var isMutating = false
	@Published var mutationError: String?

	private let dataStore: DataStore
	private var storeObservationTasks: [Task<Void, Never>] = []
	private let notificationCenter: NotificationCenter
	private var cachedGroupedHistory: [(day: Date, entries: [ANEventConcept])]?
	private var groupingCalendar = Calendar.current

	init(dataStore: DataStore = .shared, selectedMedicationID: String? = nil, notificationCenter: NotificationCenter = .default) {
		self.dataStore = dataStore
		self.notificationCenter = notificationCenter

		// Initialize from passed ID or from AppStorage
		if let initialID = selectedMedicationID {
			self.selectedMedicationID = initialID
		} else if !selectedMedicationIDString.isEmpty {
			self.selectedMedicationID = selectedMedicationIDString
		}

		// Load initial data and observe changes
		loadData()
		observeStoreChanges()
		observeClockAndForegroundChanges()

		// Ensure we have a valid selection
		ensureValidSelection()
	}

	private func loadData(snapshot: MedicationPersistenceSnapshot? = nil) {
		let snapshot = snapshot ?? MedicationPersistenceSnapshot(medications: dataStore.medications, events: dataStore.events)
		if medications != snapshot.medications { medications = snapshot.medications }
		if events != snapshot.events { events = snapshot.events }
	}

	deinit {
		storeObservationTasks.forEach { $0.cancel() }
	}

	private func observeStoreChanges() {
		// Register before the bootstrap read so a concurrent write cannot be missed.
		// Boutique emits intermediate writes; only committed snapshots are safe to cache.
		let snapshots = dataStore.committedSnapshots()
		storeObservationTasks = [
			Task { [weak self] in
				for await snapshot in snapshots {
					guard !Task.isCancelled else { return }
					self?.loadData(snapshot: snapshot)
					self?.ensureValidSelection()
				}
			},
			Task { [dataStore] in
				do {
					try await dataStore.prepareForAccess()
				} catch {
					DHLogger.data.logPrivacySafeError("Unable to load medication history", error: error)
				}
			}
		]
	}

	/// Refreshes date-relative presentation even when no medication data changes.
	func refreshForClockChange() {
		cachedGroupedHistory = nil
		objectWillChange.send()
	}

	/// Reconciles writes made by widgets or Siri while the app was inactive.
	func refreshAfterForeground() async {
		refreshForClockChange()
		do {
			let snapshot = try await dataStore.prepareForAccess()
			loadData(snapshot: snapshot)
			ensureValidSelection()
		} catch {
			DHLogger.data.logPrivacySafeError("Unable to refresh medication data", error: error)
		}
	}

	private func observeClockAndForegroundChanges() {
		let clockNotifications: [Notification.Name] = [
			.NSCalendarDayChanged,
			.NSSystemTimeZoneDidChange,
			UIApplication.significantTimeChangeNotification
		]
		for name in clockNotifications {
			storeObservationTasks.append(Task { [weak self, notificationCenter] in
				for await _ in notificationCenter.notifications(named: name) {
					guard !Task.isCancelled else { return }
					self?.refreshForClockChange()
				}
			})
		}
		storeObservationTasks.append(Task { [weak self, notificationCenter] in
			for await _ in notificationCenter.notifications(named: UIApplication.willEnterForegroundNotification) {
				guard !Task.isCancelled else { return }
				await self?.refreshAfterForeground()
			}
		})
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

	/// The All view chooser follows the same active-medication rules as the Medication tab.
	var logDosePickerMedications: [ANMedicationConcept] {
		LogDosePickerModel.medications(from: medications)
	}

	var selectedMedication: ANMedicationConcept? {
		guard let selection = selectedMedicationID, selection != "all",
		      let uuid = UUID(uuidString: selection) else { return nil }
		return medications.first { $0.id == uuid }
	}

	var groupedHistory: [(day: Date, entries: [ANEventConcept])] {
		let calendar = Calendar.current
		if groupingCalendar != calendar {
			groupingCalendar = calendar
			cachedGroupedHistory = nil
		}
		if let cachedGroupedHistory { return cachedGroupedHistory }
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

		guard !filteredEvents.isEmpty else {
			cachedGroupedHistory = []
			return []
		}
		let grouped = Dictionary(grouping: filteredEvents) { event in
			calendar.startOfDay(for: event.date)
		}
		let result = grouped
			.map { (day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
			.sorted { $0.day > $1.day }
		cachedGroupedHistory = result
		return result
	}

	@discardableResult
	func deleteEvents(at offsets: IndexSet, in groupDay: Date) async -> Bool {
		guard !isMutating else { return false }
		isMutating = true
		mutationError = nil
		defer { isMutating = false }
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
			      let uuid = UUID(uuidString: selection) else {
				mutationError = String(localized: "Choose a medication, then try deleting the entry again.")
				return false
			}
			filtered = events.filter { event in
				event.medication?.id == uuid && event.eventType == .doseTaken && calendar.startOfDay(for: event.date) == groupDay
			}
		}
		// Match UI ordering: most recent first within a day
		filtered.sort { $0.date > $1.date }
		let toDelete = offsets.compactMap { index in
			filtered[doesExistAt: index]
		}
		do {
			try await dataStore.deleteEvents(ids: Set(toDelete.map(\.id)))
			loadData()
			return true
		} catch {
			loadData()
			mutationError = String(localized: "Couldn’t finish deleting the entries. Some changes may have been saved. Review History and the medication quantity before trying again.")
			return false
		}
	}

	@discardableResult
	func updateEvent(_ event: ANEventConcept, newDate: Date, newAmount: Double, newUnit: ANUnitConcept) async -> Bool {
		guard !isMutating else { return false }
		isMutating = true
		mutationError = nil
		defer { isMutating = false }
		guard let existingEvent = dataStore.events.first(where: { $0.id == event.id }) else {
			mutationError = String(localized: "This entry is no longer available. Close the editor and review History.")
			return false
		}

		// Create updated event with new dose and date
		var updatedEvent = existingEvent
		updatedEvent.date = newDate
		updatedEvent.dose = ANDoseConcept(amount: newAmount, unit: newUnit)

		// Update event in store
		do {
			try await dataStore.updateEvent(updatedEvent)
			loadData()
			return true
		} catch {
			loadData()
			mutationError = String(localized: "Couldn’t finish saving the entry. Some changes may have been saved. Review History and the medication quantity before trying again.")
			return false
		}
	}

	@discardableResult
	func updateEventNote(_ event: ANEventConcept) async -> Bool {
		guard !isMutating else { return false }
		isMutating = true
		mutationError = nil
		defer { isMutating = false }
		// Legacy method for updating just the note without dose changes
		guard let currentEvent = dataStore.events.first(where: { $0.id == event.id }) else {
			mutationError = String(localized: "This entry is no longer available. Close the editor and review History.")
			return false
		}
		do {
			var noteUpdate = currentEvent
			noteUpdate.note = event.note
			try await dataStore.updateEvent(noteUpdate)
			loadData()
			return true
		} catch {
			loadData()
			mutationError = String(localized: "Couldn’t finish saving the note. Some changes may have been saved. Review History before trying again.")
			return false
		}
	}

	@discardableResult
	func deleteEvent(_ event: ANEventConcept) async -> Bool {
		guard !isMutating else { return false }
		isMutating = true
		mutationError = nil
		defer { isMutating = false }
		guard dataStore.events.contains(where: { $0.id == event.id }) else {
			mutationError = String(localized: "This entry is no longer available. Review History before trying again.")
			return false
		}
		// Delete the event and restore medication quantity if needed
		do {
			try await dataStore.deleteEvents(ids: [event.id])
			loadData()
			return true
		} catch {
			loadData()
			mutationError = String(localized: "Couldn’t finish deleting the entry. Some changes may have been saved. Review History and the medication quantity before trying again.")
			return false
		}
	}
}

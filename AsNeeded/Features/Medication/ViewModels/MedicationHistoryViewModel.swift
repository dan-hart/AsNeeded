// MedicationHistoryViewModel.swift
// View model for presenting and mutating medication dose history.

import ANModelKit
import DHLoggingKit
import Foundation
import SwiftUI
import UIKit

@MainActor
final class MedicationHistoryViewModel: ObservableObject {
	private enum EditError: Error {
		case conflict
	}

	struct Day {
		struct MedicationTotal: Identifiable {
			let medication: ANMedicationConcept
			var amounts: [ANUnitConcept: Double] = [:]

			var id: UUID { medication.id }
		}

		let day: Date
		let entries: [ANEventConcept]
		let medicationTotals: [MedicationTotal]

		init(day: Date, entries: [ANEventConcept]) {
			self.day = day
			self.entries = entries
			var totals: [UUID: MedicationTotal] = [:]
			for entry in entries {
				guard let medication = entry.medication, let dose = entry.dose,
					dose.amount.isFinite, dose.amount > 0 else { continue }
				totals[medication.id, default: MedicationTotal(medication: medication)].amounts[dose.unit, default: 0] += dose.amount
			}
			medicationTotals = totals.values.compactMap { total in
				var total = total
				total.amounts = total.amounts.filter { $0.value.isFinite }
				return total.amounts.isEmpty ? nil : total
			}
		}
	}

	struct JumpTarget {
		let requestedDay: Date
		let landedDay: Date?
	}

	enum SavedEntryLocation: Equatable {
		case visible(UUID)
		case outsideFilters(Date)
		case unavailable
	}

	struct SubtotalID: Hashable {
		let day: Date
		let medicationID: UUID
	}

	@Published var selectedMedicationID: String? {
		didSet {
			cachedGroupedHistory = nil
			guard selectedMedicationID != storedSelection else { return }
			storedSelection = selectedMedicationID
			defaults.set(selectedMedicationID, forKey: UserDefaultsKeys.historySelectedMedicationID)
		}
	}

	@Published var dateFilter: HistoryDateFilter = .allTime {
		didSet { cachedGroupedHistory = nil }
	}

	@Published var medications: [ANMedicationConcept] = [] {
		didSet {
			medicationsByID = Dictionary(medications.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		}
	}
	@Published var events: [ANEventConcept] = [] {
		didSet { cachedGroupedHistory = nil }
	}
	@Published private(set) var doseWarnings: [UUID: MedicationHistoryDoseWarningService.Warning] = [:]
	@Published private(set) var isMutating = false
	@Published var mutationError: String?

	private let warningService = MedicationHistoryDoseWarningService()
	private var warningInput: MedicationHistoryDoseWarningService.Input?
	private var legacyProfileData: Data?
	private var legacyProfiles: [String: MedicationSafetyProfile] = [:]
	private let dataStore: DataStore
	private let defaults: UserDefaults
	private var storedSelection: String?
	private var storeObservationTasks: [Task<Void, Never>] = []
	private let notificationCenter: NotificationCenter
	private var cachedGroupedHistory: [Day]?
	private var medicationsByID: [UUID: ANMedicationConcept] = [:]
	private var groupingCalendar = Calendar.current
	private var cachedDateRange: TrendsDateRange?
	private let calendarProvider: () -> Calendar
	private let now: () -> Date

	init(dataStore: DataStore = .shared, selectedMedicationID: String? = nil, notificationCenter: NotificationCenter = .default, defaults: UserDefaults = .standard, calendar: @escaping () -> Calendar = { .current }, now: @escaping () -> Date = Date.init) {
		self.defaults = defaults
		storedSelection = defaults.string(forKey: UserDefaultsKeys.historySelectedMedicationID)
		self.calendarProvider = calendar
		self.now = now
		self.dataStore = dataStore
		self.notificationCenter = notificationCenter

		self.selectedMedicationID = selectedMedicationID ?? storedSelection.flatMap { $0.isEmpty ? nil : $0 }

		// Register for commits before reading the bootstrap snapshot.
		observeStoreChanges()
		loadData()
		observeClockAndForegroundChanges()

		// Ensure we have a valid selection
		ensureValidSelection()
	}

	private func loadData() {
		// Reads, commits, and foreground refresh all use the newest stable publication.
		// A buffered earlier stream notification cannot restore an older warning.
		guard let committed = dataStore.latestCommittedState else { return }
		let snapshot = committed.snapshot
		if legacyProfileData != committed.legacySafetyProfileData {
			legacyProfileData = committed.legacySafetyProfileData
			legacyProfiles = MedicationSafetyProfileStore.decodeProfiles(legacyProfileData)
		}
		if medications != snapshot.medications { medications = snapshot.medications }
		if events != snapshot.events { events = snapshot.events }
		let input = MedicationHistoryDoseWarningService.Input(
			medications: snapshot.medications, events: snapshot.events, profiles: legacyProfiles
		)
		if input != warningInput {
			warningInput = input
			let warnings = warningService.warnings(for: input)
			if doseWarnings != warnings { doseWarnings = warnings }
		}
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
				for await _ in snapshots {
					guard !Task.isCancelled else { return }
					self?.applyCommittedState()
				}
			},
			Task { [dataStore] in
				do {
					try await dataStore.prepareForAccess()
				} catch is CancellationError {
					return
				} catch {
					DHLogger.data.logPrivacySafeError("Unable to load medication history", error: error)
				}
			}
		]
	}

	/// Refreshes date-relative presentation even when no medication data changes.
	func refreshForClockChange() {
		// The grouping cache checks its calendar and date bounds on the next read.
		objectWillChange.send()
	}

	/// Reconciles writes made by widgets or Siri while the app was inactive.
	func refreshAfterForeground() async {
		refreshForClockChange()
		do {
			try await dataStore.prepareForAccess()
			applyCommittedState()
		} catch {
			DHLogger.data.logPrivacySafeError("Unable to refresh medication data", error: error)
		}
	}

	private func applyCommittedState() {
		// Imports can replace the preference and records in one commit.
		let restored = defaults.string(forKey: UserDefaultsKeys.historySelectedMedicationID)
		if storedSelection != restored {
			storedSelection = restored
			selectedMedicationID = restored
		}
		loadData()
		ensureValidSelection()
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
		return medicationsByID[uuid]
	}

	func currentMedication(for snapshot: ANMedicationConcept) -> ANMedicationConcept {
		medicationsByID[snapshot.id] ?? snapshot
	}

	func rollingWarningEntries(for event: ANEventConcept) -> [MedicationHistoryDoseWarningService.Dose] {
		guard let medicationID = event.medication?.id,
			let doses = warningInput?.timelines[medicationID] else { return [] }
		let cutoff = SavedDoseLimits.windowStart(endingAt: event.date)
		return doses.filter { $0.date > cutoff && $0.date <= event.date }
			.sorted(by: MedicationHistoryDoseWarningService.Dose.ordered)
	}

	var groupedHistory: [Day] {
		let calendar = calendarProvider()
		let range = dateFilter.range(calendar: calendar, now: now())
		if groupingCalendar != calendar || cachedDateRange != range {
			cachedDateRange = range
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
		let endExclusive = range.flatMap { calendar.dateInterval(of: .day, for: $0.end)?.end }
		let rangeEvents = filteredEvents.filter { event in
			guard let range else { return dateFilter == .allTime }
			guard let endExclusive else { return false }
			return event.date >= range.start && event.date < endExclusive
		}
		let grouped = Dictionary(grouping: rangeEvents) { event in
			calendar.startOfDay(for: event.date)
		}
		let result = grouped
			.map { Day(day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
			.sorted { $0.day > $1.day }
		cachedGroupedHistory = result
		return result
	}

	var activeDateRange: TrendsDateRange? {
		dateFilter.range(calendar: calendarProvider(), now: now())
	}

	var dateFilterTitle: String {
		switch dateFilter {
		case .allTime: String(localized: "All Time")
		case let .period(period): period.displayName
		case .custom: activeDateRange?.displayName ?? String(localized: "Custom Range")
		}
	}

	func clearDateFilter() {
		dateFilter = .allTime
	}

	/// Jumping out of the selected range clears only the date filter. Choose an existing row anchor.
	func jumpTarget(for date: Date) -> JumpTarget {
		let calendar = calendarProvider()
		let day = calendar.startOfDay(for: date)
		let outsideRange = activeDateRange.map { day < $0.start || day > $0.end } ?? (dateFilter != .allTime)
		if outsideRange { clearDateFilter() }
		// Civil noon gives both days a common wall-clock time even if midnight was skipped.
		func noon(on date: Date) -> Date {
			calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
		}
		let target = noon(on: day)
		func distance(to date: Date) -> Int {
			abs(calendar.dateComponents([.day], from: target, to: noon(on: date)).day ?? 0)
		}
		let landedDay = groupedHistory.min { left, right in
			let leftDistance = distance(to: left.day)
			let rightDistance = distance(to: right.day)
			return leftDistance == rightDistance ? left.day < right.day : leftDistance < rightDistance
		}?.day
		return JumpTarget(requestedDay: day, landedDay: landedDay)
	}

	func savedEntryLocation(id: UUID) -> SavedEntryLocation {
		guard let saved = events.first(where: { $0.id == id }) else { return .unavailable }
		let savedDay = calendarProvider().startOfDay(for: saved.date)
		if groupedHistory.first(where: { $0.day == savedDay })?.entries.contains(where: { $0.id == id }) == true {
			return .visible(id)
		}
		return .outsideFilters(saved.date)
	}

	/// Compare the affected medication on the day the entry left and the day it joined.
	func changedSubtotals(since previousGroups: [Day], for eventID: UUID) -> Set<SubtotalID> {
		let currentGroups = groupedHistory
		func subtotalID(in groups: [Day]) -> SubtotalID? {
			for group in groups {
				if let medicationID = group.entries.first(where: { $0.id == eventID })?.medication?.id {
					return SubtotalID(day: group.day, medicationID: medicationID)
				}
			}
			return nil
		}
		func amounts(of subtotal: SubtotalID, in groups: [Day]) -> [ANUnitConcept: Double]? {
			groups.first(where: { $0.day == subtotal.day })?.medicationTotals
				.first(where: { $0.id == subtotal.medicationID })?.amounts
		}
		let affected = Set([subtotalID(in: previousGroups), subtotalID(in: currentGroups)].compactMap { $0 })
		return affected.filter { subtotal in
			guard let current = amounts(of: subtotal, in: currentGroups) else { return false }
			return amounts(of: subtotal, in: previousGroups) != current
		}
	}

	@discardableResult
	func deleteEvents(at offsets: IndexSet, in groupDay: Date) async -> Bool {
		guard !isMutating else { return false }
		isMutating = true
		mutationError = nil
		defer { isMutating = false }
		let entries = groupedHistory.first { $0.day == groupDay }?.entries ?? []
		let toDelete = offsets.compactMap { entries[doesExistAt: $0] }
		guard !toDelete.isEmpty else {
			mutationError = String(localized: "This entry is no longer available. Review History before trying again.")
			return false
		}
		do {
			try await dataStore.deleteEvents(matching: toDelete)
			loadData()
			return true
		} catch {
			loadData()
			mutationError = String(localized: "Couldn’t finish deleting the entries. Some changes may have been saved. Review History and the medication quantity before trying again.")
			return false
		}
	}

	@discardableResult
	func updateEvent(_ event: ANEventConcept, newDate: Date? = nil, newAmount: Double? = nil, newUnit: ANUnitConcept? = nil) async -> Bool {
		await editEvent(event, failureMessage: String(localized: "Couldn’t finish saving the entry. Some changes may have been saved. Review History and the medication quantity before trying again.")) { saved in
			if let newDate, newDate != saved.date {
				guard saved.date == event.date else { throw EditError.conflict }
				saved.date = newDate
			}
			if newAmount != nil || newUnit != nil {
				guard var requested = event.dose ?? newAmount.map({ ANDoseConcept(amount: $0, unit: newUnit ?? .unit) }) else {
					throw PersistenceTransactionError.invalidDose
				}
				if let newAmount { requested.amount = newAmount }
				if let newUnit { requested.unit = newUnit }
				// An amount and its unit are one change. Preserve an already-applied retry.
				if saved.dose?.amount == requested.amount, saved.dose?.unit == requested.unit { return }
				guard saved.dose == event.dose else { throw EditError.conflict }
				saved.dose = requested
			}
		}
	}

	@discardableResult
	func updateEventNote(_ event: ANEventConcept, text: String?) async -> Bool {
		await editEvent(event, failureMessage: String(localized: "Couldn’t finish saving the note. Some changes may have been saved. Review History before trying again.")) { saved in
			let requested = DoseReflection(note: text).sanitized().note
			let current = DoseReflectionCodec.displayNote(from: saved.note)
			guard current != requested else { return }
			guard current == DoseReflectionCodec.displayNote(from: event.note) else { throw EditError.conflict }
			saved.note = try DoseReflectionCodec.updatingNote(in: saved.note, with: requested)
		}
	}

	private func editEvent(_ event: ANEventConcept, failureMessage: String, edit: (inout ANEventConcept) throws -> Void) async -> Bool {
		guard !isMutating else { return false }
		isMutating = true
		mutationError = nil
		defer { isMutating = false }
		do {
			try await dataStore.editEvent(id: event.id) { saved in
				guard saved.medication?.id == event.medication?.id, saved.eventType == event.eventType else {
					throw PersistenceTransactionError.recordUnavailable
				}
				try edit(&saved)
			}
			loadData()
			return true
		} catch EditError.conflict {
			loadData()
			mutationError = String(localized: "This entry changed while you were editing. Close the editor and reopen it to review the latest values.")
			return false
		} catch PersistenceTransactionError.recordUnavailable {
			loadData()
			mutationError = String(localized: "This entry is no longer available. Close the editor and review History.")
			return false
		} catch {
			loadData()
			mutationError = failureMessage
			return false
		}
	}

	@discardableResult
	func deleteEvent(_ event: ANEventConcept) async -> Bool {
		guard !isMutating else { return false }
		isMutating = true
		mutationError = nil
		defer { isMutating = false }
		do {
			try await dataStore.deleteEvents(matching: [event])
			loadData()
			return true
		} catch PersistenceTransactionError.recordUnavailable {
			loadData()
			mutationError = String(localized: "This entry changed or is no longer available. Review History before trying again.")
			return false
		} catch {
			loadData()
			mutationError = String(localized: "Couldn’t finish deleting the entry. Some changes may have been saved. Review History and the medication quantity before trying again.")
			return false
		}
	}
}

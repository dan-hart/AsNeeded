// MedicationTrendsViewModel.swift
// Computes usage trends and metrics for a selected medication.

import ANModelKit
import DHLoggingKit
import Foundation
import SwiftUI
import UIKit

@MainActor
final class MedicationTrendsViewModel: ObservableObject {
	@AppStorage(UserDefaultsKeys.trendsSelectedMedicationID) var selectedMedicationIDString: String = ""

	private let usesTransientSelection: Bool
	private var transientMedicationID: UUID?

	var selectedMedicationID: UUID? {
		get {
			if usesTransientSelection { return transientMedicationID }
			return selectedMedicationIDString.isEmpty ? nil : UUID(uuidString: selectedMedicationIDString)
		}
		set {
			objectWillChange.send()
			if usesTransientSelection { transientMedicationID = newValue }
			else { selectedMedicationIDString = newValue?.uuidString ?? "" }
		}
	}

	@Published var medications: [ANMedicationConcept] = [] {
		didSet { cachedDailyTotals = nil }
	}

	private let dataStore: DataStore
	private let safetyProfileStore: MedicationSafetyProfileStore
	private let doseGuidanceService: MedicationDoseGuidanceService
	private var calendar: Calendar { calendarProvider() }
	private let calendarProvider: () -> Calendar
	private let now: () -> Date
	private var storeObservationTasks: [Task<Void, Never>] = []
	private let notificationCenter: NotificationCenter
	private var allEvents: [ANEventConcept] = []
	private var cachedSelection: UUID?
	private var cachedCalendar = Calendar.current
	private var cachedEvents: [ANEventConcept]?
	private var cachedDailyTotals: [Date: Double]?

	init(
		dataStore: DataStore = .shared,
		defaults: UserDefaults = .standard,
		selectedMedicationID: UUID? = nil,
		transientSelection: Bool = false,
		safetyProfileStore: MedicationSafetyProfileStore = .shared,
		doseGuidanceService: MedicationDoseGuidanceService = MedicationDoseGuidanceService(),
		notificationCenter: NotificationCenter = .default,
		calendar: @escaping () -> Calendar = { .current },
		now: @escaping () -> Date = Date.init
	) {
		self.usesTransientSelection = transientSelection
		_selectedMedicationIDString = AppStorage(wrappedValue: "", UserDefaultsKeys.trendsSelectedMedicationID, store: defaults)
		self.dataStore = dataStore
		self.notificationCenter = notificationCenter
		self.safetyProfileStore = safetyProfileStore
		self.doseGuidanceService = doseGuidanceService
		self.now = now
		self.calendarProvider = calendar
		if let initialID = selectedMedicationID {
			self.selectedMedicationID = initialID
		}

		// Load initial data and observe changes
		loadData()
		observeStoreChanges()
		observeClockAndForegroundChanges()

		// Ensure we have a valid selection
		ensureValidSelection()
	}

	deinit {
		storeObservationTasks.forEach { $0.cancel() }
	}

	private func loadData(snapshot: MedicationPersistenceSnapshot? = nil) {
		let snapshot = snapshot ?? MedicationPersistenceSnapshot(medications: dataStore.medications, events: dataStore.events)
		if medications != snapshot.medications {
			medications = snapshot.medications
			cachedDailyTotals = nil
		}
		if allEvents != snapshot.events {
			allEvents = snapshot.events
			cachedEvents = nil
			cachedDailyTotals = nil
			// Events can change without any medication metadata changing.
			objectWillChange.send()
		}
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
					DHLogger.data.logPrivacySafeError("Unable to load medication trends", error: error)
				}
			}
		]
	}

	/// Refreshes date-relative presentation even when no medication data changes.
	func refreshForClockChange() {
		cachedDailyTotals = nil
		cachedEvents = nil
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

	private func validateDerivedCache() {
		if cachedSelection != selectedMedicationID || cachedCalendar != calendar {
			cachedSelection = selectedMedicationID
			cachedCalendar = calendar
			cachedEvents = nil
			cachedDailyTotals = nil
		}
	}

	/// Ensures we always have a valid medication selected
	/// This prevents picker errors when selection is nil
	func ensureValidSelection() {
		// Widget scopes never replace a missing explicit identity with another medication.
		guard !usesTransientSelection else { return }
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
		return medications.first { $0.id == id && (!usesTransientSelection || !$0.isArchived) }
	}

	var safetyProfile: MedicationSafetyProfile {
		guard let medication = selectedMedication else {
			return .empty
		}

		return safetyProfileStore.profile(for: medication.id)
	}

	var events: [ANEventConcept] {
		validateDerivedCache()
		if let cachedEvents { return cachedEvents }
		guard let id = selectedMedicationID else { return [] }
		let result = allEvents
			.filter { $0.medication?.id == id && $0.eventType == .doseTaken }
			.sorted { $0.date < $1.date }
		cachedEvents = result
		return result
	}

	private var totalsByDay: [Date: Double] {
		validateDerivedCache()
		if let cachedDailyTotals { return cachedDailyTotals }
		guard let unit = preferredUnit else { return [:] }
		let totals = events.reduce(into: [Date: Double]()) { totals, event in
			guard let dose = event.dose, dose.unit == unit else { return }
			totals[calendar.startOfDay(for: event.date), default: 0] += dose.amount
		}
		cachedDailyTotals = totals
		return totals
	}

	// Determine a preferred unit for aggregation
	var preferredUnit: ANUnitConcept? {
		selectedMedication?.prescribedUnit ?? events.compactMap { $0.dose?.unit }.first
	}

	var refillProjection: MedicationDoseGuidanceService.RefillProjection? {
		guard let medication = selectedMedication else {
			return nil
		}

		return doseGuidanceService.refillProjection(
			for: medication,
			events: events,
			profile: safetyProfile
		)
	}

	func doseAvailability(at date: Date = .now) -> MedicationDoseGuidanceService.Availability {
		guard let medication = selectedMedication else { return .notConfigured }
		return doseGuidanceService.availability(for: medication, at: date, events: events, profile: safetyProfile)
	}

	var nextEligibleDoseDate: Date? {
		doseAvailability().eligibleDate
	}

	/// The last completed local calendar day. Calendar arithmetic preserves day boundaries across DST.
	var trendsWindowEnd: Date {
		let today = calendar.startOfDay(for: now())
		return calendar.date(byAdding: .day, value: -1, to: today) ?? today
	}

	private var completeDayEvents: [ANEventConcept] {
		let today = calendar.startOfDay(for: now())
		return events.filter { $0.date < today }
	}

	// Daily totals for the last N complete days ending yesterday (default 14)
	func dailyTotals(last days: Int = 14) -> [(day: Date, total: Double)] {
		guard days > 0, preferredUnit != nil else { return [] }
		let start = trendsWindowEnd
		let totals = totalsByDay
		return (0 ..< days).reversed().compactMap { offset in
			guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
			return (day, totals[day] ?? 0)
		}
	}

	// Average per day over the last window (default 7 days)
	func averagePerDay(window days: Int = 7) -> Double {
		let totals = dailyTotals(last: days)
		guard !totals.isEmpty else { return 0 }
		let sum = totals.map { $0.total }.reduce(0, +)
		return sum / Double(totals.count)
	}

	// Days until refill date (if set)
	var daysUntilRefill: Int? {
		guard let date = selectedMedication?.nextRefillDate else { return nil }
		let start = calendar.startOfDay(for: now())
		let end = calendar.startOfDay(for: date)
		return calendar.dateComponents([.day], from: start, to: end).day
	}

	// Estimated days remaining from quantity and avg usage
	var estimatedDaysRemaining: Int? {
		refillProjection?.estimatedDaysRemaining
	}

	// MARK: - Usage Progress Metrics

	/// Returns the percentage of medication used (0-100) if both initial and current quantities are available
	var usagePercentage: Double? {
		guard let initial = selectedMedication?.initialQuantity,
			  let current = selectedMedication?.quantity,
			  initial > 0
		else {
			return nil
		}
		let used = initial - current
		return max(0, min(100, (used / initial) * 100))
	}

	/// Returns a formatted string representing usage (e.g., "50% used (30/60 pills)")
	var usageProgressText: String? {
		guard let initial = selectedMedication?.initialQuantity,
			  let current = selectedMedication?.quantity,
			  let percentage = usagePercentage,
			  let unit = preferredUnit
		else {
			return nil
		}
		let used = initial - current
		return String(format: "%.0f%% used (%.0f/%.0f %@)",
					  percentage, used, initial, unit.abbreviation)
	}

	/// Enum representing whether usage is on track with refill schedule
	enum RefillCycleStatus {
		case onTrack
		case ahead // Using slower than expected
		case behind // Using faster than expected
		case unknown
	}

	/// Compares usage rate to refill schedule and returns status
	var refillCycleStatus: RefillCycleStatus {
		// Need both dates and quantities
		guard let lastRefill = selectedMedication?.lastRefillDate,
			  let nextRefill = selectedMedication?.nextRefillDate,
			  let initial = selectedMedication?.initialQuantity,
			  let current = selectedMedication?.quantity,
			  initial > 0
		else {
			return .unknown
		}

		let now = now()
		let totalCycleDays = calendar.dateComponents([.day], from: lastRefill, to: nextRefill).day ?? 0
		let daysElapsed = calendar.dateComponents([.day], from: lastRefill, to: now).day ?? 0

		guard totalCycleDays > 0, daysElapsed > 0 else { return .unknown }

		// Calculate expected vs actual usage
		let timeProgress = Double(daysElapsed) / Double(totalCycleDays)
		let usedAmount = initial - current
		let usageProgress = usedAmount / initial

		// Allow 10% tolerance
		let tolerance = 0.10

		if abs(usageProgress - timeProgress) <= tolerance {
			return .onTrack
		} else if usageProgress < timeProgress {
			return .ahead // Using slower
		} else {
			return .behind // Using faster
		}
	}

	/// Returns a user-friendly description of refill cycle status
	var refillCycleStatusText: String {
		switch refillCycleStatus {
		case .onTrack:
			return String(localized: "On track")
		case .ahead:
			return String(localized: "Using slower than schedule")
		case .behind:
			return String(localized: "Using faster than schedule")
		case .unknown:
			return "—"
		}
	}

	// Calendar heatmap data for the last N complete days ending yesterday
	func calendarHeatmapData(last days: Int = 30) -> [CalendarDay] {
		let totals = dailyTotals(last: days)
		// Keep partial and future days out of the intensity scale as well.
		let today = calendar.startOfDay(for: now())
		let maxTotal = totalsByDay.filter { $0.key < today }.values.max() ?? 1
		return totals.map { day, total in
			CalendarDay(date: day, total: total, intensity: maxTotal > 0 ? total / maxTotal : 0)
		}
	}

	var patternSummary: String {
		guard !completeDayEvents.isEmpty else {
			return "Log a few doses to see timing patterns after the day is complete."
		}

		let preferredTimeBucket = mostCommonTimeBucket()
		let recentAverage = averagePerDay(window: 7)
		let priorAverage = averagePerDay(daysEnding: 7, window: 7)

		var fragments: [String] = []
		fragments.append("Use is most often clustered in the \(preferredTimeBucket).")

		if recentAverage > priorAverage * 1.2, priorAverage > 0 {
			fragments.append("Your recent pace is higher than the week before.")
		} else if priorAverage > recentAverage * 1.2, recentAverage > 0 {
			fragments.append("Your recent pace is lighter than the week before.")
		} else {
			fragments.append("Your recent pace looks fairly steady.")
		}

		if let refillProjection {
			fragments.append(refillProjection.statusMessage)
		}

		return fragments.joined(separator: " ")
	}

	private func averagePerDay(daysEnding endOffset: Int, window days: Int) -> Double {
		let totals = dailyTotals(last: endOffset + days)
		guard totals.count >= days else {
			return 0
		}

		let slice = totals.dropLast(endOffset).suffix(days)
		guard !slice.isEmpty else {
			return 0
		}

		let sum = slice.map(\.total).reduce(0, +)
		return sum / Double(slice.count)
	}

	private func mostCommonTimeBucket() -> String {
		let bucketCounts = completeDayEvents.reduce(into: [String: Int]()) { counts, event in
			let hour = calendar.component(.hour, from: event.date)
			let bucket: String

			switch hour {
			case 5 ..< 12:
				bucket = "morning"
			case 12 ..< 17:
				bucket = "afternoon"
			case 17 ..< 22:
				bucket = "evening"
			default:
				bucket = "night"
			}

			counts[bucket, default: 0] += 1
		}

		return bucketCounts.max { $0.value < $1.value }?.key ?? "day"
	}
}

struct CalendarDay {
	let date: Date
	let total: Double
	let intensity: Double // 0.0 to 1.0 for color intensity
}

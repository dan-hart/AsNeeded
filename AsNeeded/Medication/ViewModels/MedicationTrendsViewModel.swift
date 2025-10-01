// MedicationTrendsViewModel.swift
// Computes usage trends and metrics for a selected medication.

import Foundation
import SwiftUI
import Combine
import ANModelKit

@MainActor
final class MedicationTrendsViewModel: ObservableObject {
	@AppStorage("trendsSelectedMedicationID") var selectedMedicationIDString: String = ""

	var selectedMedicationID: UUID? {
		get {
			selectedMedicationIDString.isEmpty ? nil : UUID(uuidString: selectedMedicationIDString)
		}
		set {
			selectedMedicationIDString = newValue?.uuidString ?? ""
		}
	}

	@Published var medications: [ANMedicationConcept] = []

	private let dataStore: DataStore
	private let calendar = Calendar.current
	private var cancellables = Set<AnyCancellable>()

	init(dataStore: DataStore = .shared, selectedMedicationID: UUID? = nil) {
		self.dataStore = dataStore
		if let initialID = selectedMedicationID {
			self.selectedMedicationID = initialID
		}

		// Load initial data and observe changes
		loadData()
		observeStoreChanges()

		// Ensure we have a valid selection
		ensureValidSelection()
	}

	private func loadData() {
		medications = dataStore.medications
	}

	private func observeStoreChanges() {
		// Use Combine's Timer publisher instead of Foundation's Timer
		// This provides better integration with SwiftUI and proper cancellation
		Timer.publish(every: 2.0, on: .main, in: .common)
			.autoconnect()
			.sink { [weak self] _ in
				guard let self = self else { return }
				let newMedications = self.dataStore.medications
				if self.medications != newMedications {
					self.medications = newMedications
					self.ensureValidSelection()
				}
			}
			.store(in: &cancellables)
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

	var events: [ANEventConcept] {
		guard let id = selectedMedicationID else { return [] }
		// Filter events ensuring medication IDs match exactly
		return dataStore.events
			.filter { event in
				// Only include events that have a medication with matching ID and are dose taken events
				guard let eventMedication = event.medication,
					  eventMedication.id == id,
					  event.eventType == .doseTaken else {
					return false
				}
				return true
			}
			.sorted { $0.date < $1.date }
	}

	// Determine a preferred unit for aggregation
	var preferredUnit: ANUnitConcept? {
		selectedMedication?.prescribedUnit ?? events.compactMap { $0.dose?.unit }.first
	}

	// Daily totals for the last N days (default 14)
	func dailyTotals(last days: Int = 14) -> [(day: Date, total: Double)] {
		guard let unit = preferredUnit else { return [] }
		let start = calendar.startOfDay(for: Date())
		let daySequence = (0..<days).compactMap { calendar.date(byAdding: .day, value: -$0, to: start) }.reversed()
		let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
		return daySequence.map { day in
			let total = (grouped[day] ?? []).compactMap { ev -> Double? in
				guard let dose = ev.dose, dose.unit == unit else { return nil }
				return dose.amount
			}.reduce(0, +)
			return (day, total)
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
		let start = calendar.startOfDay(for: Date())
		let end = calendar.startOfDay(for: date)
		return calendar.dateComponents([.day], from: start, to: end).day
	}

	// Estimated days remaining from quantity and avg usage
	var estimatedDaysRemaining: Int? {
		guard let qty = selectedMedication?.quantity, qty > 0 else { return nil }
		let avg = averagePerDay(window: 7)
		guard avg > 0 else { return nil }
		return Int((qty / avg).rounded())
	}
	
	// Calendar heatmap data for the last N days
	func calendarHeatmapData(last days: Int = 30) -> [CalendarDay] {
		guard let unit = preferredUnit else { return [] }
		
		let endDate = calendar.startOfDay(for: Date())
		let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) ?? endDate
		
		// Create all days in the range
		var allDays: [Date] = []
		var currentDate = startDate
		while currentDate <= endDate {
			allDays.append(currentDate)
			currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
		}
		
		// Group events by day
		let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
		
		// Calculate max total for intensity scaling
		let allTotals = grouped.values.map { dayEvents in
			dayEvents.compactMap { ev -> Double? in
				guard let dose = ev.dose, dose.unit == unit else { return nil }
				return dose.amount
			}.reduce(0, +)
		}
		let maxTotal = allTotals.max() ?? 1
		
		// Create calendar days with usage data
		return allDays.map { day in
			let dayEvents = grouped[day] ?? []
			let total = dayEvents.compactMap { ev -> Double? in
				guard let dose = ev.dose, dose.unit == unit else { return nil }
				return dose.amount
			}.reduce(0, +)
			
			let intensity = maxTotal > 0 ? total / maxTotal : 0
			return CalendarDay(date: day, total: total, intensity: intensity)
		}
	}
}

struct CalendarDay {
	let date: Date
	let total: Double
	let intensity: Double // 0.0 to 1.0 for color intensity
}


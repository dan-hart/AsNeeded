// MedicationTrendsViewModel.swift
// Computes usage trends and metrics for a selected medication.

import Foundation
import SwiftUI
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

	private let dataStore: DataStore
	private let calendar = Calendar.current

	init(dataStore: DataStore = .shared, selectedMedicationID: UUID? = nil) {
		self.dataStore = dataStore
		if let initialID = selectedMedicationID {
			self.selectedMedicationID = initialID
		}
	}

	var medications: [ANMedicationConcept] { dataStore.medications }
	var selectedMedication: ANMedicationConcept? {
		guard let id = selectedMedicationID else { return nil }
		return medications.first { $0.id == id }
	}

	var events: [ANEventConcept] {
		guard let id = selectedMedicationID else { return [] }
		return dataStore.events
			.filter { $0.medication?.id == id && $0.eventType == .doseTaken }
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
}


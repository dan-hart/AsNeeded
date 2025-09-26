// GetDailyUsageIntent.swift
// App Intent for querying daily medication usage via Siri

import Foundation
import AppIntents
import ANModelKit
import DHLoggingKit

@available(iOS 16.0, *)
struct GetDailyUsageIntent: AppIntent {
	static let title: LocalizedStringResource = "Get Daily Medication Usage"
	static let description = IntentDescription("Check how much of a medication you've taken today")
	static let openAppWhenRun: Bool = false
	
	@Parameter(title: "Medication", description: "The medication to check usage for")
	var medication: MedicationEntity?
	
	@Parameter(title: "Medication Name", description: "The name of the medication to check")
	var medicationName: String?
	
	private let logger = DHLogger(category: "GetDailyUsageIntent")
	
	@MainActor
	func perform() async throws -> some IntentResult & ProvidesDialog {
		// Determine which medication to query
		let targetMedication: ANMedicationConcept
		
		if let providedMedication = medication {
			targetMedication = providedMedication.medication
			logger.info("Using entity medication for daily usage: \(targetMedication.displayName)")
		} else if let name = medicationName, !name.isEmpty {
			logger.info("Searching for medication by name for daily usage: \(name)")
			guard let foundMedication = findBestMatch(for: name) else {
				logger.warning("No medication found matching: \(name)")
				return .result(dialog: IntentDialog("I couldn't find a medication named \(name). Please make sure you've added it to AsNeeded first."))
			}
			targetMedication = foundMedication
		} else {
			logger.warning("No medication specified for daily usage query")
			return .result(dialog: IntentDialog("Please specify which medication you'd like to check usage for."))
		}
		
		// Calculate today's usage
		let todayUsage = calculateTodayUsage(for: targetMedication)
		let medicationDisplayName = if let nickname = targetMedication.nickname, !nickname.isEmpty {
			nickname
		} else {
			targetMedication.clinicalName
		}
		
		if todayUsage.totalAmount == 0 {
			logger.info("No usage found today for \(targetMedication.displayName)")
			return .result(dialog: IntentDialog("You haven't taken any \(medicationDisplayName) today."))
		}
		
		// Format the response based on the unit and amount
		let unit = todayUsage.unit
		let amount = todayUsage.totalAmount
		let doseCount = todayUsage.doseCount
		
		let amountText = amount == 1.0 ? "1" : String(format: "%.1f", amount)
		let unitText = unit.displayName(for: Int(amount.rounded()), locale: .current)
		
		var responseText: String
		if doseCount == 1 {
			responseText = "You've taken \(amountText) \(unitText) of \(medicationDisplayName) today."
		} else {
			responseText = "You've taken \(amountText) \(unitText) of \(medicationDisplayName) today across \(doseCount) doses."
		}
		
		logger.info("Daily usage for \(targetMedication.displayName): \(amount) \(unit.displayName) in \(doseCount) doses")
		return .result(dialog: IntentDialog(stringLiteral: responseText))
	}
	
	/// Calculate today's total usage for a medication
	@MainActor
	func calculateTodayUsage(for medication: ANMedicationConcept) -> (totalAmount: Double, unit: ANUnitConcept, doseCount: Int) {
		let calendar = Calendar.current
		let today = calendar.startOfDay(for: Date())
		let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
		
		// Get today's events for this medication
		let todayEvents = DataStore.shared.events.filter { event in
			guard event.eventType == .doseTaken,
				  event.medication?.id == medication.id,
				  event.dose != nil else {
				return false
			}
			return event.date >= today && event.date < tomorrow
		}
		
		guard !todayEvents.isEmpty else {
			// Return default unit if no events
			let defaultUnit = medication.prescribedUnit ?? .unit
			return (totalAmount: 0.0, unit: defaultUnit, doseCount: 0)
		}
		
		// Group by unit and sum amounts
		let eventsByUnit = Dictionary(grouping: todayEvents) { $0.dose?.unit ?? .unit }
		
		// Use the most common unit, or the prescribed unit if available
		let primaryUnit: ANUnitConcept
		if let prescribedUnit = medication.prescribedUnit,
		   eventsByUnit[prescribedUnit] != nil {
			primaryUnit = prescribedUnit
		} else {
			// Find the unit with the most events
			primaryUnit = eventsByUnit.max { $0.value.count < $1.value.count }?.key ?? .unit
		}
		
		// Sum amounts for the primary unit
		let eventsWithPrimaryUnit = eventsByUnit[primaryUnit] ?? []
		let totalAmount = eventsWithPrimaryUnit.compactMap { $0.dose?.amount }.reduce(0, +)
		
		return (totalAmount: totalAmount, unit: primaryUnit, doseCount: eventsWithPrimaryUnit.count)
	}
	
	/// Find the best matching medication for the given name
	@MainActor
	private func findBestMatch(for name: String) -> ANMedicationConcept? {
		return MedicationSearchUtility.findBestMatch(for: name)
	}
}
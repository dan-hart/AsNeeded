// LogMedicationIntent.swift
// App Intent for logging medication doses via Siri

import Foundation
import AppIntents
import ANModelKit
import DHLoggingKit

@available(iOS 16.0, *)
struct LogMedicationIntent: AppIntent {
	static let title: LocalizedStringResource = "Log Medication"
	static let description = IntentDescription("Log a dose of medication taken")
	static let openAppWhenRun: Bool = false
	
	@Parameter(title: "Medication", description: "The medication to log")
	var medication: MedicationEntity?
	
	@Parameter(title: "Medication Name", description: "The name of the medication to log")
	var medicationName: String?
	
	@Parameter(title: "Amount", description: "The amount taken (optional)", default: 1.0)
	var amount: Double
	
	@Parameter(title: "Unit", description: "The unit of measurement (optional)")
	var unit: MedicationUnitEntity?
	
	private let logger = DHLogger(category: "LogMedicationIntent")
	
	@MainActor
	func perform() async throws -> some IntentResult & ProvidesDialog {
		// Determine which medication to use
		let targetMedication: ANMedicationConcept
		
		if let providedMedication = medication {
			targetMedication = providedMedication.medication
			logger.info("Using entity medication: \(targetMedication.displayName)")
		} else if let name = medicationName, !name.isEmpty {
			logger.info("Searching for medication by name: \(name)")
			guard let foundMedication = findBestMatch(for: name) else {
				logger.warning("No medication found matching: \(name)")
				return .result(dialog: IntentDialog("I couldn't find a medication named \(name). Please make sure you've added it to AsNeeded first."))
			}
			targetMedication = foundMedication
		} else {
			logger.warning("No medication specified")
			return .result(dialog: IntentDialog("Please specify which medication you'd like to log."))
		}
		
		// Use provided unit or fall back to medication's prescribed unit or default
		let selectedUnit: ANUnitConcept
		if let providedUnit = unit {
			selectedUnit = providedUnit.unit
		} else if let prescribedUnit = targetMedication.prescribedUnit {
			selectedUnit = prescribedUnit
		} else {
			selectedUnit = .unit
		}
		
		// Use provided amount or fall back to prescribed dose
		let doseAmount = amount > 0 ? amount : (targetMedication.prescribedDoseAmount ?? 1.0)
		
		do {
			// Create dose and event
			let dose = ANDoseConcept(amount: doseAmount, unit: selectedUnit)
			let event = ANEventConcept(
				eventType: .doseTaken,
				medication: targetMedication,
				dose: dose,
				date: Date()
			)
			
			// Log the dose
			try await DataStore.shared.addEvent(event)
			
			logger.info("Successfully logged dose: \(doseAmount) \(selectedUnit.displayName) of \(targetMedication.displayName)")
			
			// Format response message
			let amountText = doseAmount == 1.0 ? "1" : String(format: "%.1f", doseAmount)
			let unitText = selectedUnit.displayName
			let medicationText = if let nickname = targetMedication.nickname, !nickname.isEmpty {
				nickname
			} else {
				targetMedication.clinicalName
			}
			
			return .result(dialog: IntentDialog("Logged \(amountText) \(unitText) of \(medicationText)"))
			
		} catch {
			logger.error("Failed to log medication dose: \(error.localizedDescription)")
			return .result(dialog: IntentDialog("Sorry, I couldn't log your medication. Please try again or open AsNeeded manually."))
		}
	}
	
	/// Find the best matching medication for the given name
	@MainActor
	private func findBestMatch(for name: String) -> ANMedicationConcept? {
		return MedicationSearchUtility.findBestMatch(for: name)
	}
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, *)
struct AsNeededShortcuts: AppShortcutsProvider {
	@AppShortcutsBuilder
	static var appShortcuts: [AppShortcut] {
		AppShortcut(
			intent: LogMedicationIntent(),
			phrases: [
				"Log medication in \(.applicationName)",
				"Take medication with \(.applicationName)", 
				"Record dose in \(.applicationName)",
				"Log \(\.$medication) in \(.applicationName)",
				"I took \(\.$medication) in \(.applicationName)"
			],
			shortTitle: "Log Medication",
			systemImageName: "pills.fill"
		)
		AppShortcut(
			intent: ListMedicationsIntent(),
			phrases: [
				"List my medications in \(.applicationName)",
				"Show my medications in \(.applicationName)",
				"What medications do I have in \(.applicationName)",
				"My medication list in \(.applicationName)"
			],
			shortTitle: "List Medications",
			systemImageName: "list.bullet"
		)
		AppShortcut(
			intent: GetDailyUsageIntent(),
			phrases: [
				"How much \(\.$medication) have I taken today in \(.applicationName)",
				"What's my daily usage of \(\.$medication) in \(.applicationName)",
				"Check my \(\.$medication) usage today in \(.applicationName)",
				"How many \(\.$medication) today in \(.applicationName)"
			],
			shortTitle: "Check Daily Usage",
			systemImageName: "chart.bar.fill"
		)
	}
}
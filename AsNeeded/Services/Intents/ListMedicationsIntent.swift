// ListMedicationsIntent.swift
// App Intent for listing user's medications via Siri

import Foundation
import AppIntents
import ANModelKit
import DHLoggingKit

@available(iOS 16.0, *)
struct ListMedicationsIntent: AppIntent {
	static let title: LocalizedStringResource = "List My Medications"
	static let description = IntentDescription("List all medications in AsNeeded")
	static let openAppWhenRun: Bool = false
	
	private let logger = DHLogger(category: "ListMedicationsIntent")
	
	@MainActor
	func perform() async throws -> some IntentResult & ProvidesDialog {
		logger.info("Performing ListMedicationsIntent")
		
		let medications = DataStore.shared.medications
		
		guard !medications.isEmpty else {
			logger.info("No medications found")
			return .result(dialog: "You don't have any medications added to AsNeeded yet. Open the app to add your first medication.")
		}
		
		logger.info("Found \(medications.count) medications")
		
		// Sort medications alphabetically by display name
		let sortedMedications = medications.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
		
		if medications.count == 1 {
			let medication = sortedMedications[0]
			return .result(dialog: "You have one medication: \(medication.displayName)")
		} else {
			let medicationNames = sortedMedications.map { $0.displayName }
			let medicationList = formatMedicationList(medicationNames)
			return .result(dialog: "You have \(medications.count) medications: \(medicationList)")
		}
	}
	
	private func formatMedicationList(_ names: [String]) -> String {
		guard names.count > 1 else {
			return names.first ?? ""
		}
		
		if names.count == 2 {
			return "\(names[0]) and \(names[1])"
		} else {
			let allButLast = names.dropLast().joined(separator: ", ")
			let last = names.last!
			return "\(allButLast), and \(last)"
		}
	}
}
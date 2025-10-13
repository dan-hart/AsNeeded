// LogDoseWidgetIntent.swift
// App Intent for logging medication doses directly from widgets (iOS 17+)

import Foundation
import AppIntents
import WidgetKit
import ANModelKit
import Boutique

@available(iOS 17.0, *)
struct LogDoseWidgetIntent: AppIntent {
	static let title: LocalizedStringResource = "Log Dose"
	static let description = IntentDescription("Log a dose directly from widget")
	static let openAppWhenRun: Bool = false

	@Parameter(title: "Medication ID")
	var medicationID: String

	@MainActor
	func perform() async throws -> some IntentResult {
		// Parse medication ID
		guard let id = UUID(uuidString: medicationID) else {
			return .result()
		}

		// Get shared data provider
		let provider = WidgetDataProvider.shared

		// Find the medication
		guard let medication = provider.medications.first(where: { $0.id == id }) else {
			return .result()
		}

		// Check if can take now (simplified 4-hour interval check)
		guard provider.canTakeNow(medication) else {
			// Cannot take yet - interval not elapsed
			return .result()
		}

		// Determine dose amount and unit
		let doseAmount = medication.prescribedDoseAmount ?? 1.0
		let selectedUnit = medication.prescribedUnit ?? .unit

		// Create dose and event
		let dose = ANDoseConcept(amount: doseAmount, unit: selectedUnit)
		let event = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: dose,
			date: Date()
		)

		do {
			// Log the dose to shared store
			try await provider.eventsStore.insert(event)

			// Update medication quantity if tracked
			if let quantity = medication.quantity, quantity > 0 {
				var updatedMedication = medication
				updatedMedication.quantity = max(0, quantity - doseAmount)
				try await provider.medicationsStore.remove(medication)
				try await provider.medicationsStore.insert(updatedMedication)
			}

			// Reload all widget timelines to show updated state
			WidgetCenter.shared.reloadAllTimelines()

			return .result()

		} catch {
			// Failed to log dose
			return .result()
		}
	}
}

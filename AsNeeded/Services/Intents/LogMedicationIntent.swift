// LogMedicationIntent.swift
// App Intent for logging medication doses via Siri

import ANModelKit
import AppIntents
import DHLoggingKit
import Foundation

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
		let dialog = try await doseLogDialog(in: .shared)
		return .result(dialog: IntentDialog(dialog))
	}

	@MainActor
	func doseLogDialog(
		in dataStore: DataStore,
		now: () -> Date = Date.init,
		migrate: (DataStore) async throws -> Void = { try await MedicationDoseLimitMigration().migrate(dataStore: $0) }
	) async throws -> LocalizedStringResource {
		try await dataStore.prepareForAccess()
		try await migrate(dataStore)
		let targetMedication: ANMedicationConcept

		if let providedMedication = medication {
			guard let current = dataStore.medications.first(where: { $0.id == providedMedication.medication.id }) else {
				return "That medication is no longer available."
			}
			targetMedication = current
			logger.info("Using entity medication")
		} else if let name = medicationName, !name.isEmpty {
			logger.info("Searching for medication by provided name")
			guard let foundMedication = MedicationSearchUtility.findBestMatch(for: name, in: dataStore.medications) else {
				logger.warning("No medication found for provided name")
				return "I couldn't find a medication named \(name). Please make sure you've added it to AsNeeded first."
			}
			targetMedication = foundMedication
		} else {
			logger.warning("No medication specified")
			return "Please specify which medication you'd like to log."
		}

		let selectedUnit = unit?.unit ?? targetMedication.prescribedUnit ?? .unit
		let doseAmount = amount > 0 ? amount : (targetMedication.prescribedDoseAmount ?? 1.0)

		do {
			let dose = ANDoseConcept(amount: doseAmount, unit: selectedUnit)
			let event = ANEventConcept(eventType: .doseTaken, medication: targetMedication, dose: dose, date: now())
			try await dataStore.recordDose(event)

			logger.info("Successfully logged medication dose from intent")
			let amountText = selectedUnit.localizedCompactAmount(for: doseAmount)
			let medicationText = if let nickname = targetMedication.nickname, !nickname.isEmpty {
				nickname
			} else {
				targetMedication.clinicalName
			}
			let recordedDose = String(localized: "\(String(localized: "Dose logged")): \(amountText)")
			return "\(recordedDose) · \(medicationText)"
		} catch {
			logger.logPrivacySafeError("Failed to log medication dose", error: error)
			return "Sorry, I couldn't log your medication. Please try again or open AsNeeded manually."
		}
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
                "I took \(\.$medication) in \(.applicationName)",
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
                "My medication list in \(.applicationName)",
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
                "How many \(\.$medication) today in \(.applicationName)",
            ],
            shortTitle: "Check Daily Usage",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: GetNextDoseIntent(),
            phrases: [
                "When can I take my medication in \(.applicationName)",
                "When is my next dose in \(.applicationName)",
                "When do I need to take \(\.$medication) in \(.applicationName)",
                "Check my next dose in \(.applicationName)",
            ],
            shortTitle: "Check Next Dose",
            systemImageName: "clock.fill"
        )
        AppShortcut(
            intent: CheckRefillStatusIntent(),
            phrases: [
                "What medications need refills in \(.applicationName)",
                "Check my refill status in \(.applicationName)",
                "Which medications are running low in \(.applicationName)",
                "Do I need any refills in \(.applicationName)",
            ],
            shortTitle: "Check Refills",
            systemImageName: "calendar.badge.exclamationmark"
        )
        AppShortcut(
            intent: GetMedicationInfoIntent(),
            phrases: [
                "Tell me about \(\.$medication) in \(.applicationName)",
                "Get information about \(\.$medication) in \(.applicationName)",
                "What do I have for \(\.$medication) in \(.applicationName)",
                "Show me \(\.$medication) details in \(.applicationName)",
            ],
            shortTitle: "Get Medication Info",
            systemImageName: "info.circle.fill"
        )
    }
}

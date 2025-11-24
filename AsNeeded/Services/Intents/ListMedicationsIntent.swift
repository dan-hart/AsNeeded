// ListMedicationsIntent.swift
// App Intent for listing user's medications via Siri

import ANModelKit
import AppIntents
import DHLoggingKit
import Foundation

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
            return .result(dialog: IntentDialog("You don't have any medications added to AsNeeded yet. Open the app to add your first medication."))
        }

        logger.info("Found \(medications.count) medications")

        // Sort medications alphabetically by display name
        let sortedMedications = medications.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        if medications.count == 1 {
            guard let medication = sortedMedications.first else {
                return .result(dialog: IntentDialog("Unable to retrieve medication information."))
            }
            return .result(dialog: IntentDialog("You have one medication: \(medication.displayName)"))
        } else {
            let medicationNames = sortedMedications.map { $0.displayName }
            let medicationList = formatMedicationList(medicationNames)
            return .result(dialog: IntentDialog("You have \(medications.count) medications: \(medicationList)"))
        }
    }

    func formatMedicationList(_ names: [String]) -> String {
        guard names.count > 1 else {
            return names.first ?? ""
        }

        if names.count == 2 {
            guard let first = names[safe: 0], let second = names[safe: 1] else {
                return names.joined(separator: ", ")
            }
            return "\(first) and \(second)"
        } else {
            let allButLast = names.dropLast().joined(separator: ", ")
            guard let last = names.last else {
                return allButLast
            }
            return "\(allButLast), and \(last)"
        }
    }
}

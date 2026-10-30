// GetDailyUsageIntent.swift
// App Intent for querying daily medication usage via Siri

import ANModelKit
import AppIntents
import DHLoggingKit
import Foundation

@available(iOS 16.0, *)
struct GetDailyUsageIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Daily Medication Usage"
    static let description = IntentDescription("Check how much of a medication you've taken today")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Medication", description: "The medication to check usage for")
    var medication: MedicationEntity?

    @Parameter(title: "Medication Name", description: "The name of the medication to check")
    var medicationName: String?

	// System-created intents use the shared store; callers can supply an isolated store.
	var dataStore: DataStore?

	init() {}

	init(dataStore: DataStore) { self.dataStore = dataStore }

    private let logger = DHLogger(category: "GetDailyUsageIntent")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = try await (dataStore ?? .shared).prepareForAccess()

        // Determine which medication to query
        let targetMedication: ANMedicationConcept

        if medication != nil {
            guard let current = resolveMedication(in: snapshot.medications) else {
				return .result(dialog: IntentDialog("That medication is no longer available. Choose a different medication in AsNeeded."))
			}
			targetMedication = current
            logger.info("Using entity medication for daily usage")
        } else if let name = medicationName, !name.isEmpty {
            logger.info("Searching for medication by provided name for daily usage")
            guard let foundMedication = resolveMedication(in: snapshot.medications) else {
                logger.warning("No medication found for provided name")
                return .result(dialog: IntentDialog("I couldn't find a medication named \(name). Please make sure you've added it to AsNeeded first."))
            }
            targetMedication = foundMedication
        } else {
            logger.warning("No medication specified for daily usage query")
            return .result(dialog: IntentDialog("Please specify which medication you'd like to check usage for."))
        }

        // Calculate today's usage
        let todayUsage = calculateTodayUsage(for: targetMedication, events: snapshot.events)
        let medicationDisplayName = if let nickname = targetMedication.nickname, !nickname.isEmpty {
            nickname
        } else {
            targetMedication.clinicalName
        }

        if todayUsage.totalAmount == 0 {
            logger.info("No daily usage found")
			return .result(dialog: IntentDialog("No doses of \(medicationDisplayName) are logged for today."))
        }

        // Format the response based on the unit and amount
        let unit = todayUsage.unit
        let amount = todayUsage.totalAmount
        let doseCount = todayUsage.doseCount

		let amountText = unit.localizedCompactAmount(for: amount)

        var responseText: String
        if doseCount == 1 {
			responseText = String(localized: "You logged \(amountText) of \(medicationDisplayName) today.")
        } else {
			responseText = String(localized: "You logged \(amountText) of \(medicationDisplayName) today across \(doseCount) doses.")
        }
		responseText += String(localized: " This total includes doses recorded in \(unit.localizedDisplayName) only.")

        logger.info("Daily usage calculated")
        return .result(dialog: IntentDialog(stringLiteral: responseText))
    }

	@MainActor
	func resolveMedication(in medications: [ANMedicationConcept]) -> ANMedicationConcept? {
		if let medication {
			guard let id = UUID(uuidString: medication.id) else { return nil }
			return medications.first { $0.id == id }
		}
		guard let medicationName else { return nil }
		return MedicationSearchUtility.findBestMatch(for: medicationName, in: medications)
	}

    /// Calculate today's total usage for a medication
    @MainActor
    func calculateTodayUsage(for medication: ANMedicationConcept, events: [ANEventConcept] = [], at now: Date = Date()) -> (totalAmount: Double, unit: ANUnitConcept, doseCount: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now

        // Get today's events for this medication
        let todayEvents = events.filter { event in
            guard event.eventType == .doseTaken,
                  event.medication?.id == medication.id,
                  event.dose != nil
            else {
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
           eventsByUnit[prescribedUnit] != nil
        {
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

}

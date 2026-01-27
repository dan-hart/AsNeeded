// GetNextDoseIntent.swift
// App Intent for checking when the next medication dose is due

import ANModelKit
import AppIntents
import DHLoggingKit
import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct GetNextDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Next Dose"
    static let description = IntentDescription("Check when your next medication dose is due")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Medication", description: "The medication to check (optional)")
    var medication: MedicationEntity?

    private let logger = DHLogger(category: "GetNextDoseIntent")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        logger.info("Performing GetNextDoseIntent")

        let medications = DataStore.shared.medications

        guard !medications.isEmpty else {
            logger.info("No medications found")
            return .result(
                dialog: IntentDialog("You don't have any medications added to AsNeeded yet."),
                view: EmptyMedicationsView()
            )
        }

        let events = DataStore.shared.events

        // If specific medication provided, check that one
        if let providedMedication = medication {
            let med = providedMedication.medication
            let medicationEvents = events
                .filter { $0.medication?.id == med.id }
                .sorted { $0.date > $1.date }

            guard let lastEvent = medicationEvents.first else {
                logger.info("No history for medication: \(med.displayName)")
                return .result(
                    dialog: IntentDialog("You haven't taken \(med.displayName) yet. You can take it now."),
                    view: NextDoseView(medicationName: med.displayName, nextDoseTime: nil, canTakeNow: true)
                )
            }

            // Simplified: Use 4-hour default interval since minimumIntervalSeconds doesn't exist yet
            let minInterval: TimeInterval = 4 * 3600 // 4 hours
            let nextAvailable = lastEvent.date.addingTimeInterval(minInterval)

            if nextAvailable > Date() {
                let timeRemaining = formatTimeRemaining(until: nextAvailable)
                logger.info("Next dose of \(med.displayName) in \(timeRemaining)")
                return .result(
                    dialog: IntentDialog("You can take \(med.displayName) in \(timeRemaining)."),
                    view: NextDoseView(medicationName: med.displayName, nextDoseTime: nextAvailable, canTakeNow: false)
                )
            }

            // Can take now
            logger.info("\(med.displayName) can be taken now")
            return .result(
                dialog: IntentDialog("You can take \(med.displayName) now."),
                view: NextDoseView(medicationName: med.displayName, nextDoseTime: nil, canTakeNow: true)
            )
        }

        // Otherwise, find the next medication due
        // Calculate next dose time for each medication
        var medicationTimes: [(medication: ANMedicationConcept, nextTime: Date?)] = []

        for medication in medications {
            let medicationEvents = events
                .filter { $0.medication?.id == medication.id }
                .sorted { $0.date > $1.date }

            guard let lastEvent = medicationEvents.first else {
                // No history, can take now
                medicationTimes.append((medication, Date()))
                continue
            }

            // Simplified: Use 4-hour default interval
            let minInterval: TimeInterval = 4 * 3600
            let nextAvailable = lastEvent.date.addingTimeInterval(minInterval)
            medicationTimes.append((medication, nextAvailable))
        }

        // Sort by next time
        let sorted = medicationTimes.sorted { item1, item2 in
            guard let time1 = item1.nextTime, let time2 = item2.nextTime else {
                return false
            }
            return time1 < time2
        }

        guard let nextMed = sorted.first else {
            return .result(
                dialog: IntentDialog("No medications are scheduled."),
                view: EmptyMedicationsView()
            )
        }

        if let nextTime = nextMed.nextTime, nextTime <= Date() {
            // Can take now
            return .result(
                dialog: IntentDialog("You can take \(nextMed.medication.displayName) now."),
                view: NextDoseView(medicationName: nextMed.medication.displayName, nextDoseTime: nil, canTakeNow: true)
            )
        } else if let nextTime = nextMed.nextTime {
            // Due later
            let timeRemaining = formatTimeRemaining(until: nextTime)
            return .result(
                dialog: IntentDialog("Your next dose is \(nextMed.medication.displayName) in \(timeRemaining)."),
                view: NextDoseView(medicationName: nextMed.medication.displayName, nextDoseTime: nextTime, canTakeNow: false)
            )
        } else {
            return .result(
                dialog: IntentDialog("You can take \(nextMed.medication.displayName) now."),
                view: NextDoseView(medicationName: nextMed.medication.displayName, nextDoseTime: nil, canTakeNow: true)
            )
        }
    }

    private func formatTimeRemaining(until date: Date) -> String {
        let interval = date.timeIntervalSince(Date())

        if interval <= 0 {
            return "now"
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") and \(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}

// MARK: - Snippet Views

struct NextDoseView: View {
    let medicationName: String
    let nextDoseTime: Date?
    let canTakeNow: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pills.fill")
                    .font(.title2)
                    .foregroundStyle(.accent)

                Text(medicationName)
                    .font(.headline)

                Spacer()
            }

            if canTakeNow {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Available Now")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            } else if let nextTime = nextDoseTime {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Dose")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(nextTime, style: .relative)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.accent)
                }
            }
        }
        .padding()
    }
}

struct EmptyMedicationsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "pills")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Medications")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

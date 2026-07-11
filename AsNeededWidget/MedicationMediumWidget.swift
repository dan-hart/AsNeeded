// MedicationMediumWidget.swift
// Medium widget showing 2-3 medications with status and quick log links

import ANModelKit
import AppIntents
import SwiftUI
import WidgetKit

struct MedicationMediumWidget: Widget {
    let kind: String = "MedicationMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MediumWidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Medication List")
        .description("Shows 2-3 medications with status and quick log")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Timeline Provider

struct MediumWidgetProvider: TimelineProvider {
    typealias Entry = MedicationListEntry

    func placeholder(in _: Context) -> MedicationListEntry {
        MedicationListEntry(
            date: Date(),
            medications: [
                MedicationInfo(
                    medication: ANMedicationConcept(
                        clinicalName: "Medication 1",
                        quantity: 30,
                        prescribedUnit: .tablet
                    ),
                    lowStock: false,
                    refillSoon: true
                ),
                MedicationInfo(
                    medication: ANMedicationConcept(
                        clinicalName: "Medication 2",
                        quantity: 15,
                        prescribedUnit: .capsule
                    ),
                    lowStock: false,
                    refillSoon: false
                ),
            ]
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (MedicationListEntry) -> Void) {
        Task { @MainActor in
            let entry = createEntry()
            completion(entry)
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<MedicationListEntry>) -> Void) {
        Task { @MainActor in
            let entry = createEntry()

            // Update every 15 minutes
            let nextUpdate = Calendar.current.date(
                byAdding: .minute,
                value: 15,
                to: Date()
            ) ?? Date()

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    @MainActor
    private func createEntry() -> MedicationListEntry {
        let provider = WidgetDataProvider.shared

        let lowStockIDs = Set(provider.lowQuantityMedications.map(\.id))
        let refillSoonIDs = Set(provider.refillDueSoon.map(\.id))

        let medications = Array(provider.medicationsByRefillPriority.prefix(3)).map { medication in
            MedicationInfo(
                medication: medication,
                lowStock: lowStockIDs.contains(medication.id),
                refillSoon: refillSoonIDs.contains(medication.id),
                statusMessage: provider.refillStatusMessage(for: medication)
            )
        }

        return MedicationListEntry(date: Date(), medications: medications)
    }
}

// MARK: - Widget View

struct MediumWidgetView: View {
    let entry: MedicationListEntry

    var body: some View {
        if entry.medications.isEmpty {
            emptyStateView
        } else {
            medicationListView
        }
    }

    private var medicationListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "pills.fill")
                    .font(.title3)
                    .foregroundStyle(Color.blue)

                Text("Medications")
                    .font(.headline.weight(.semibold))

                Spacer()

                Text("\(entry.medications.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.quaternary)
                    )
            }

            // Medication rows
            ForEach(entry.medications, id: \.medication.id) { info in
                if let url = URL(string: "asneeded://log/\(info.medication.id.uuidString)") {
                    Link(destination: url) {
                        medicationRow(info: info)
                    }
                    .buttonStyle(.plain)
                } else {
                    medicationRow(info: info)
                }
            }
        }
        .padding()
    }

    private func medicationRow(info: MedicationInfo) -> some View {
        HStack(spacing: 12) {
            // Medication icon
            ZStack {
                Circle()
                    .fill(info.medication.displayColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: info.medication.effectiveDisplaySymbol)
                    .font(.body.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(info.medication.displayColor)
            }

            // Medication info
            VStack(alignment: .leading, spacing: 4) {
                Text(info.medication.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if info.lowStock {
                    Text("Low stock")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                } else if info.refillSoon {
                    Text("Refill soon")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                } else if let statusMessage = info.statusMessage {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Quick log button - interactive on iOS 17+
            if #available(iOS 17.0, *) {
                LogDoseIconButton(
                    medicationID: info.medication.id.uuidString,
                    medicationName: info.medication.displayName,
                    color: info.medication.displayColor
                )
            } else {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(info.medication.displayColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "pills")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Medications")
                .font(.headline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Add medications in the app")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

}

// MARK: - Timeline Entry

struct MedicationListEntry: TimelineEntry {
    let date: Date
    let medications: [MedicationInfo]
}

struct MedicationInfo {
    let medication: ANMedicationConcept
    let lowStock: Bool
    let refillSoon: Bool
    let statusMessage: String?

    init(
        medication: ANMedicationConcept,
        lowStock: Bool = false,
        refillSoon: Bool = false,
        statusMessage: String? = nil
    ) {
        self.medication = medication
        self.lowStock = lowStock
        self.refillSoon = refillSoon
        self.statusMessage = statusMessage
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    MedicationMediumWidget()
} timeline: {
    MedicationListEntry(
        date: Date(),
        medications: [
            MedicationInfo(
                medication: ANMedicationConcept(
                    clinicalName: "Lisinopril",
                    quantity: 28,
                    prescribedUnit: .tablet
                )
            ),
            MedicationInfo(
                medication: ANMedicationConcept(
                    clinicalName: "Metformin",
                    quantity: 45,
                    prescribedUnit: .tablet
                )
            ),
        ]
    )
}

// MARK: - Helper Views

@available(iOS 17.0, *)
struct LogDoseIconButton: View {
    let medicationID: String
    let medicationName: String
    let color: Color

    var body: some View {
        let intent = LogDoseWidgetIntent()
        intent.medicationID = medicationID

        return Button(intent: intent) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log dose for \(medicationName)")
        .accessibilityHint("Logs the prescribed dose")
    }
}

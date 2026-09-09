// MedicationSmallWidget.swift
// Small widget showing a featured medication and refill status

import ANModelKit
import AppIntents
import SwiftUI
import WidgetKit

struct MedicationSmallWidget: Widget {
    let kind: String = "MedicationSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SmallWidgetProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Featured Medication")
        .description("Shows refill status and lets you quickly log a dose")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Timeline Provider

struct SmallWidgetProvider: TimelineProvider {
    typealias Entry = MedicationEntry

    func placeholder(in _: Context) -> MedicationEntry {
        MedicationEntry(
            date: Date(),
            medication: ANMedicationConcept(
                clinicalName: "Medication",
                quantity: 30,
                prescribedUnit: .tablet
            ),
            lowStock: false,
            refillSoon: true
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (MedicationEntry) -> Void) {
        Task { @MainActor in
            let entry = createEntry()
            completion(entry)
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<MedicationEntry>) -> Void) {
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
    private func createEntry() -> MedicationEntry {
        let provider = WidgetDataProvider.shared
        provider.invalidateRefillSnapshot()

        guard let medication = provider.featuredMedication else {
            return MedicationEntry(date: Date(), medication: nil, lowStock: false, refillSoon: false)
        }

        return MedicationEntry(
            date: Date(),
            medication: medication,
            lowStock: provider.lowQuantityMedications.contains(where: { $0.id == medication.id }),
            refillSoon: provider.refillDueSoon.contains(where: { $0.id == medication.id })
        )
    }
}

// MARK: - Widget View

struct SmallWidgetView: View {
    let entry: MedicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let medication = entry.medication {
            VStack(alignment: .leading, spacing: 8) {
                // Medication icon and name
                HStack(spacing: 8) {
                    Image(systemName: medication.effectiveDisplaySymbol)
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(medication.displayColor)

                    Text(medication.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                if entry.lowStock {
                    Text("Low stock")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                } else if entry.refillSoon {
                    Text("Refill soon")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }

                if #available(iOS 17.0, *) {
                    LogDoseButton(medicationID: medication.id.uuidString)
                } else if let quantity = medication.quantity {
                    Text("Qty: \(quantity, specifier: "%.0f")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap to log dose")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .widgetURL(URL(string: "asneeded://log/\(medication.id.uuidString)"))
        } else {
            // Empty state
            VStack(spacing: 8) {
                Image(systemName: "pills")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("No Medications")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Add medications\nin the app")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

}

// MARK: - Timeline Entry

struct MedicationEntry: TimelineEntry {
    let date: Date
    let medication: ANMedicationConcept?
    let lowStock: Bool
    let refillSoon: Bool
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    MedicationSmallWidget()
} timeline: {
    MedicationEntry(
        date: Date(),
        medication: ANMedicationConcept(
            clinicalName: "Lisinopril",
            quantity: 28,
            prescribedUnit: .tablet
        ),
        lowStock: false,
        refillSoon: true
    )

    MedicationEntry(
        date: Date(),
        medication: ANMedicationConcept(
            clinicalName: "Ibuprofen",
            quantity: 45,
            prescribedUnit: .tablet
        ),
        lowStock: true,
        refillSoon: true
    )
}

// MARK: - Helper Views

@available(iOS 17.0, *)
struct LogDoseButton: View {
    let medicationID: String

    var body: some View {
        let intent = LogDoseWidgetIntent()
        intent.medicationID = medicationID

        return Button(intent: intent) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                Text("Log Dose")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

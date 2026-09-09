// MedicationLockScreenWidget.swift
// Lock screen widgets for iOS 16+ showing medication count and status

import ANModelKit
import SwiftUI
import WidgetKit

struct MedicationLockScreenWidget: Widget {
    let kind: String = "MedicationLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenWidgetProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Medication Status")
        .description("Shows medication count and refill status on lock screen")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Timeline Provider

struct LockScreenWidgetProvider: TimelineProvider {
    typealias Entry = LockScreenEntry

    func placeholder(in _: Context) -> LockScreenEntry {
        LockScreenEntry(
            date: Date(),
            medicationCount: 3,
            featuredMedication: ANMedicationConcept(
                clinicalName: "Medication",
                quantity: 30,
                prescribedUnit: .tablet
            ),
            lowQuantityCount: 1,
            refillDueCount: 1
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (LockScreenEntry) -> Void) {
        Task { @MainActor in
            let entry = createEntry()
            completion(entry)
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
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
    private func createEntry() -> LockScreenEntry {
        let provider = WidgetDataProvider.shared
        provider.invalidateRefillSnapshot()
        let medications = provider.medications

        guard let featuredMedication = provider.featuredMedication else {
            return LockScreenEntry(
                date: Date(),
                medicationCount: medications.count,
                featuredMedication: nil,
                lowQuantityCount: provider.lowQuantityMedications.count,
                refillDueCount: provider.refillDueSoon.count
            )
        }

        return LockScreenEntry(
            date: Date(),
            medicationCount: medications.count,
            featuredMedication: featuredMedication,
            lowQuantityCount: provider.lowQuantityMedications.count,
            refillDueCount: provider.refillDueSoon.count
        )
    }
}

// MARK: - Widget View

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LockScreenEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .accessoryInline:
                inlineView
            default:
                Text("Unsupported")
            }
        }
        .widgetURL(entry.medicationURL)
    }

    // MARK: - Circular (Watch-style complication)

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                if let featuredMedication = entry.featuredMedication {
                    Image(systemName: featuredMedication.effectiveDisplaySymbol)
                        .font(.title3.weight(.semibold))

                    if entry.lowQuantityCount > 0 {
                        Text("Low")
                            .font(.caption2.weight(.bold))
                    } else if entry.refillDueCount > 0 {
                        Text("Refill")
                            .font(.caption2.weight(.bold))
                    }
                } else {
                    Image(systemName: "pills")
                        .font(.title2)

                    Text("\(entry.medicationCount)")
                        .font(.caption.weight(.bold))
                }
            }
        }
    }

    // MARK: - Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "pills.fill")
                    .font(.caption.weight(.semibold))

                Text("Medications")
                    .font(.caption.weight(.semibold))

                Spacer()

                if entry.lowQuantityCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Divider()

            if let featuredMedication = entry.featuredMedication {
                HStack {
                    Text(featuredMedication.displayName)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)

                    Spacer()

                    if entry.lowQuantityCount > 0 {
                        Text("Low stock")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    } else if entry.refillDueCount > 0 {
                        Text("Refill soon")
                            .font(.caption2.weight(.bold))
                    }
                }
            } else {
                Text("No medications")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Inline

    private var inlineView: some View {
        if let featuredMedication = entry.featuredMedication {
            if entry.lowQuantityCount > 0 {
                Text("\(Image(systemName: "pills")) \(featuredMedication.displayName) • Low stock")
            } else if entry.refillDueCount > 0 {
                Text("\(Image(systemName: "pills")) \(featuredMedication.displayName) • Refill soon")
            } else {
                Text("\(Image(systemName: "pills")) \(featuredMedication.displayName)")
            }
        } else {
            Text("\(Image(systemName: "pills")) \(entry.medicationCount) medications")
        }
    }

}

// MARK: - Timeline Entry

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let medicationCount: Int
    let featuredMedication: ANMedicationConcept?
    let lowQuantityCount: Int
    let refillDueCount: Int

    var medicationURL: URL? {
        featuredMedication.flatMap { medication in
            URL(string: "asneeded://log/\(medication.id.uuidString)")
        }
    }
}

// MARK: - Previews

#Preview(as: .accessoryCircular) {
    MedicationLockScreenWidget()
} timeline: {
    LockScreenEntry(
        date: Date(),
        medicationCount: 3,
        featuredMedication: ANMedicationConcept(
            clinicalName: "Lisinopril",
            quantity: 28,
            prescribedUnit: .tablet
        ),
        lowQuantityCount: 1,
        refillDueCount: 1
    )
}

#Preview(as: .accessoryRectangular) {
    MedicationLockScreenWidget()
} timeline: {
    LockScreenEntry(
        date: Date(),
        medicationCount: 3,
        featuredMedication: ANMedicationConcept(
            clinicalName: "Lisinopril",
            quantity: 28,
            prescribedUnit: .tablet
        ),
        lowQuantityCount: 0,
        refillDueCount: 1
    )
}

#Preview(as: .accessoryInline) {
    MedicationLockScreenWidget()
} timeline: {
    LockScreenEntry(
        date: Date(),
        medicationCount: 3,
        featuredMedication: ANMedicationConcept(
            clinicalName: "Lisinopril",
            quantity: 28,
            prescribedUnit: .tablet
        ),
        lowQuantityCount: 1,
        refillDueCount: 1
    )
}

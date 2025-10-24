// MedicationSmallWidget.swift
// Small widget showing next medication due with countdown timer

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
        .configurationDisplayName("Next Medication")
        .description("Shows your next medication due with countdown timer")
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
            nextDoseTime: Date().addingTimeInterval(3600),
            canTakeNow: false
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (MedicationEntry) -> Void) {
        Task { @MainActor in
            let entry = await createEntry()
            completion(entry)
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<MedicationEntry>) -> Void) {
        Task { @MainActor in
            let entry = await createEntry()

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

        guard let medication = provider.nextMedicationDue else {
            return MedicationEntry(date: Date(), medication: nil, nextDoseTime: nil, canTakeNow: false)
        }

        let nextDoseTime = provider.nextDoseTime(for: medication)
        let canTakeNow = provider.canTakeNow(medication)

        return MedicationEntry(
            date: Date(),
            medication: medication,
            nextDoseTime: nextDoseTime,
            canTakeNow: canTakeNow
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

                // Status and countdown
                if entry.canTakeNow {
                    if #available(iOS 17.0, *) {
                        // Interactive button for iOS 17+
                        LogDoseButton(medicationID: medication.id.uuidString)
                    } else {
                        // Fallback for iOS 16
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Now")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.green)

                            Text("Tap to log dose")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let nextDoseTime = entry.nextDoseTime {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Dose")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text(timeRemaining(until: nextDoseTime))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(medication.displayColor)
                    }
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

    private func timeRemaining(until date: Date) -> String {
        let interval = date.timeIntervalSince(Date())

        if interval <= 0 {
            return "Now"
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Timeline Entry

struct MedicationEntry: TimelineEntry {
    let date: Date
    let medication: ANMedicationConcept?
    let nextDoseTime: Date?
    let canTakeNow: Bool
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
        nextDoseTime: Date().addingTimeInterval(3600),
        canTakeNow: false
    )

    MedicationEntry(
        date: Date(),
        medication: ANMedicationConcept(
            clinicalName: "Ibuprofen",
            quantity: 45,
            prescribedUnit: .tablet
        ),
        nextDoseTime: Date(),
        canTakeNow: true
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

// MedicationLargeWidget.swift
// Large widget showing full medication list with quantities and status

import ANModelKit
import AppIntents
import SwiftUI
import WidgetKit

struct MedicationLargeWidget: Widget {
    let kind: String = "MedicationLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LargeWidgetProvider()) { entry in
            LargeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Full Medication List")
        .description("Shows all medications with quantities and status")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Timeline Provider

struct LargeWidgetProvider: TimelineProvider {
    typealias Entry = FullMedicationListEntry

    func placeholder(in _: Context) -> FullMedicationListEntry {
        FullMedicationListEntry(
            date: Date(),
            medications: [
                MedicationInfo(
                    medication: ANMedicationConcept(
                        clinicalName: "Medication 1",
                        quantity: 30,
                        prescribedUnit: .tablet
                    ),
                    nextDoseTime: Date().addingTimeInterval(3600),
                    canTakeNow: false
                ),
                MedicationInfo(
                    medication: ANMedicationConcept(
                        clinicalName: "Medication 2",
                        quantity: 15,
                        prescribedUnit: .capsule
                    ),
                    nextDoseTime: Date(),
                    canTakeNow: true
                ),
            ],
            lowQuantityCount: 1,
            refillDueCount: 0
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (FullMedicationListEntry) -> Void) {
        Task { @MainActor in
            let entry = createEntry()
            completion(entry)
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<FullMedicationListEntry>) -> Void) {
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
    private func createEntry() -> FullMedicationListEntry {
        let provider = WidgetDataProvider.shared

        // Get up to 6 medications for large widget
        let medications = Array(provider.medicationsByName.prefix(6)).map { medication in
            MedicationInfo(
                medication: medication,
                nextDoseTime: provider.nextDoseTime(for: medication),
                canTakeNow: provider.canTakeNow(medication)
            )
        }

        let lowQuantityCount = provider.lowQuantityMedications.count
        let refillDueCount = provider.refillDueSoon.count

        return FullMedicationListEntry(
            date: Date(),
            medications: medications,
            lowQuantityCount: lowQuantityCount,
            refillDueCount: refillDueCount
        )
    }
}

// MARK: - Widget View

struct LargeWidgetView: View {
    let entry: FullMedicationListEntry

    var body: some View {
        if entry.medications.isEmpty {
            emptyStateView
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // Header with alerts
                headerView

                Divider()

                // Medication list
                VStack(alignment: .leading, spacing: 10) {
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

                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pills.fill")
                    .font(.title2)
                    .foregroundStyle(Color.blue)

                Text("My Medications")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text("\(entry.medications.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(.quaternary)
                    )
            }

            // Alert badges
            HStack(spacing: 8) {
                if entry.lowQuantityCount > 0 {
                    alertBadge(
                        icon: "exclamationmark.triangle.fill",
                        text: "\(entry.lowQuantityCount) low",
                        color: .orange
                    )
                }

                if entry.refillDueCount > 0 {
                    alertBadge(
                        icon: "calendar.badge.exclamationmark",
                        text: "\(entry.refillDueCount) refill due",
                        color: .red
                    )
                }
            }
        }
    }

    private func alertBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)

            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }

    private func medicationRow(info: MedicationInfo) -> some View {
        HStack(spacing: 12) {
            // Medication icon
            ZStack {
                Circle()
                    .fill(info.medication.displayColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: info.medication.effectiveDisplaySymbol)
                    .font(.callout.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(info.medication.displayColor)
            }

            // Medication info
            VStack(alignment: .leading, spacing: 3) {
                Text(info.medication.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // Quantity
                    if let quantity = info.medication.quantity,
                       let unit = info.medication.prescribedUnit
                    {
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.caption2)

                            Text("\(String(format: "%.0f", quantity)) \(unit.abbreviation)")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(quantityColor(for: quantity))
                    }

                    // Status
                    if info.canTakeNow {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)

                            Text("Available")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.green)
                    } else if let nextDoseTime = info.nextDoseTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)

                            Text(timeRemaining(until: nextDoseTime))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 4)

            // Quick log button - interactive on iOS 17+
            if #available(iOS 17.0, *), info.canTakeNow {
                LogDoseLargeIconButton(medicationID: info.medication.id.uuidString, color: info.medication.displayColor)
            } else {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(info.medication.displayColor)
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Medications")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Add medications in the app to see them here")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func quantityColor(for quantity: Double) -> Color {
        if quantity < 10 {
            return .red
        } else if quantity < 30 {
            return .orange
        } else {
            return .green
        }
    }

    private func timeRemaining(until date: Date) -> String {
        let interval = date.timeIntervalSince(Date())

        if interval <= 0 {
            return "now"
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Timeline Entry

struct FullMedicationListEntry: TimelineEntry {
    let date: Date
    let medications: [MedicationInfo]
    let lowQuantityCount: Int
    let refillDueCount: Int
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    MedicationLargeWidget()
} timeline: {
    FullMedicationListEntry(
        date: Date(),
        medications: [
            MedicationInfo(
                medication: ANMedicationConcept(
                    clinicalName: "Lisinopril",
                    quantity: 5,
                    prescribedUnit: .tablet
                ),
                nextDoseTime: Date(),
                canTakeNow: true
            ),
            MedicationInfo(
                medication: ANMedicationConcept(
                    clinicalName: "Metformin",
                    quantity: 45,
                    prescribedUnit: .tablet
                ),
                nextDoseTime: Date().addingTimeInterval(7200),
                canTakeNow: false
            ),
            MedicationInfo(
                medication: ANMedicationConcept(
                    clinicalName: "Vitamin D3",
                    quantity: 60,
                    prescribedUnit: .capsule
                ),
                nextDoseTime: Date().addingTimeInterval(14400),
                canTakeNow: false
            ),
        ],
        lowQuantityCount: 1,
        refillDueCount: 1
    )
}

// MARK: - Helper Views

@available(iOS 17.0, *)
struct LogDoseLargeIconButton: View {
    let medicationID: String
    let color: Color

    var body: some View {
        let intent = LogDoseWidgetIntent()
        intent.medicationID = medicationID

        return Button(intent: intent) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

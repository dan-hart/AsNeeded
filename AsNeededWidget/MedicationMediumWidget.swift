// MedicationMediumWidget.swift
// Medium widget showing 2-3 medications with status and quick log links

import WidgetKit
import SwiftUI
import ANModelKit
import AppIntents

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

	func placeholder(in context: Context) -> MedicationListEntry {
		MedicationListEntry(
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
				)
			]
		)
	}

	func getSnapshot(in context: Context, completion: @escaping (MedicationListEntry) -> Void) {
		Task { @MainActor in
			let entry = await createEntry()
			completion(entry)
		}
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<MedicationListEntry>) -> Void) {
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
	private func createEntry() -> MedicationListEntry {
		let provider = WidgetDataProvider.shared

		// Get top 3 medications by next dose time
		let medications = Array(provider.medicationsByNextDose.prefix(3)).map { medication in
			MedicationInfo(
				medication: medication,
				nextDoseTime: provider.nextDoseTime(for: medication),
				canTakeNow: provider.canTakeNow(medication)
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
				Link(destination: URL(string: "asneeded://log/\(info.medication.id.uuidString)")!) {
					medicationRow(info: info)
				}
				.buttonStyle(.plain)
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

				if info.canTakeNow {
					Text("Available now")
						.font(.caption2.weight(.medium))
						.foregroundStyle(.green)
				} else if let nextDoseTime = info.nextDoseTime {
					Text("Next: \(timeRemaining(until: nextDoseTime))")
						.font(.caption2.weight(.medium))
						.foregroundStyle(.secondary)
				}
			}

			Spacer(minLength: 4)

			// Quick log button - interactive on iOS 17+
			if #available(iOS 17.0, *), info.canTakeNow {
				LogDoseIconButton(medicationID: info.medication.id.uuidString, color: info.medication.displayColor)
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
			return "\(hours)h \(minutes)m"
		} else {
			return "\(minutes)m"
		}
	}
}

// MARK: - Timeline Entry

struct MedicationListEntry: TimelineEntry {
	let date: Date
	let medications: [MedicationInfo]
}

struct MedicationInfo {
	let medication: ANMedicationConcept
	let nextDoseTime: Date?
	let canTakeNow: Bool
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
			)
		]
	)
}

// MARK: - Helper Views

@available(iOS 17.0, *)
struct LogDoseIconButton: View {
	let medicationID: String
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
	}
}

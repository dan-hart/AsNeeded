// MedicationLockScreenWidget.swift
// Lock screen widgets for iOS 16+ showing medication count and status

import WidgetKit
import SwiftUI
import ANModelKit

struct MedicationLockScreenWidget: Widget {
	let kind: String = "MedicationLockScreenWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: LockScreenWidgetProvider()) { entry in
			LockScreenWidgetView(entry: entry)
		}
		.configurationDisplayName("Medication Status")
		.description("Shows medication count and next dose on lock screen")
		.supportedFamilies([
			.accessoryCircular,
			.accessoryRectangular,
			.accessoryInline
		])
	}
}

// MARK: - Timeline Provider

struct LockScreenWidgetProvider: TimelineProvider {
	typealias Entry = LockScreenEntry

	func placeholder(in context: Context) -> LockScreenEntry {
		LockScreenEntry(
			date: Date(),
			medicationCount: 3,
			nextMedication: ANMedicationConcept(
				clinicalName: "Medication",
				quantity: 30,
				prescribedUnit: .tablet
			),
			nextDoseTime: Date().addingTimeInterval(3600),
			canTakeNow: false,
			lowQuantityCount: 1
		)
	}

	func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
		Task { @MainActor in
			let entry = await createEntry()
			completion(entry)
		}
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
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
	private func createEntry() -> LockScreenEntry {
		let provider = WidgetDataProvider.shared
		let medications = provider.medications

		guard let nextMed = provider.nextMedicationDue else {
			return LockScreenEntry(
				date: Date(),
				medicationCount: medications.count,
				nextMedication: nil,
				nextDoseTime: nil,
				canTakeNow: false,
				lowQuantityCount: provider.lowQuantityMedications.count
			)
		}

		let nextDoseTime = provider.nextDoseTime(for: nextMed)
		let canTakeNow = provider.canTakeNow(nextMed)

		return LockScreenEntry(
			date: Date(),
			medicationCount: medications.count,
			nextMedication: nextMed,
			nextDoseTime: nextDoseTime,
			canTakeNow: canTakeNow,
			lowQuantityCount: provider.lowQuantityMedications.count
		)
	}
}

// MARK: - Widget View

struct LockScreenWidgetView: View {
	@Environment(\.widgetFamily) private var family
	let entry: LockScreenEntry

	var body: some View {
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

	// MARK: - Circular (Watch-style complication)

	private var circularView: some View {
		ZStack {
			AccessoryWidgetBackground()

			VStack(spacing: 2) {
				if let nextMed = entry.nextMedication {
					Image(systemName: nextMed.effectiveDisplaySymbol)
						.font(.title3.weight(.semibold))

					if entry.canTakeNow {
						Text("Now")
							.font(.caption2.weight(.bold))
					} else if let nextDoseTime = entry.nextDoseTime {
						Text(timeRemainingShort(until: nextDoseTime))
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

			if let nextMed = entry.nextMedication {
				HStack {
					Text(nextMed.displayName)
						.font(.caption2.weight(.medium))
						.lineLimit(1)

					Spacer()

					if entry.canTakeNow {
						Text("Available")
							.font(.caption2.weight(.bold))
							.foregroundStyle(.green)
					} else if let nextDoseTime = entry.nextDoseTime {
						Text(timeRemainingShort(until: nextDoseTime))
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
		if let nextMed = entry.nextMedication {
			if entry.canTakeNow {
				Text("\(Image(systemName: "pills")) \(nextMed.displayName) • Now")
			} else if let nextDoseTime = entry.nextDoseTime {
				Text("\(Image(systemName: "pills")) \(nextMed.displayName) • \(timeRemainingShort(until: nextDoseTime))")
			} else {
				Text("\(Image(systemName: "pills")) \(nextMed.displayName)")
			}
		} else {
			Text("\(Image(systemName: "pills")) \(entry.medicationCount) medications")
		}
	}

	// MARK: - Helper

	private func timeRemainingShort(until date: Date) -> String {
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
			return "\(hours)h"
		} else {
			return "\(minutes)m"
		}
	}
}

// MARK: - Timeline Entry

struct LockScreenEntry: TimelineEntry {
	let date: Date
	let medicationCount: Int
	let nextMedication: ANMedicationConcept?
	let nextDoseTime: Date?
	let canTakeNow: Bool
	let lowQuantityCount: Int
}

// MARK: - Previews

#Preview(as: .accessoryCircular) {
	MedicationLockScreenWidget()
} timeline: {
	LockScreenEntry(
		date: Date(),
		medicationCount: 3,
		nextMedication: ANMedicationConcept(
			clinicalName: "Lisinopril",
			quantity: 28,
			prescribedUnit: .tablet
		),
		nextDoseTime: Date().addingTimeInterval(3600),
		canTakeNow: false,
		lowQuantityCount: 1
	)
}

#Preview(as: .accessoryRectangular) {
	MedicationLockScreenWidget()
} timeline: {
	LockScreenEntry(
		date: Date(),
		medicationCount: 3,
		nextMedication: ANMedicationConcept(
			clinicalName: "Lisinopril",
			quantity: 28,
			prescribedUnit: .tablet
		),
		nextDoseTime: Date(),
		canTakeNow: true,
		lowQuantityCount: 0
	)
}

#Preview(as: .accessoryInline) {
	MedicationLockScreenWidget()
} timeline: {
	LockScreenEntry(
		date: Date(),
		medicationCount: 3,
		nextMedication: ANMedicationConcept(
			clinicalName: "Lisinopril",
			quantity: 28,
			prescribedUnit: .tablet
		),
		nextDoseTime: Date().addingTimeInterval(3600),
		canTakeNow: false,
		lowQuantityCount: 1
	)
}

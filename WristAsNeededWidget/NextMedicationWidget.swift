// NextMedicationWidget.swift
// Watch complication showing next medication due

import ANModelKit
import SwiftUI
import WidgetKit

struct NextMedicationWidget: Widget {
	let kind: String = "NextMedicationWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: NextMedicationProvider()) { entry in
			NextMedicationWidgetView(entry: entry)
		}
		.configurationDisplayName("Next Medication")
		.description("Shows your next medication to take")
		.supportedFamilies([
			.accessoryCircular,
			.accessoryRectangular,
			.accessoryCorner,
			.accessoryInline,
		])
	}
}

// MARK: - Timeline Provider

struct NextMedicationProvider: TimelineProvider {
	typealias Entry = NextMedicationEntry

	func placeholder(in _: Context) -> NextMedicationEntry {
		NextMedicationEntry(
			date: Date(),
			medication: ANMedicationConcept(
				clinicalName: "Medication",
				quantity: 30,
				prescribedUnit: .tablet
			)
		)
	}

	func getSnapshot(in _: Context, completion: @escaping (NextMedicationEntry) -> Void) {
		Task { @MainActor in
			let entry = await createEntry()
			completion(entry)
		}
	}

	func getTimeline(in _: Context, completion: @escaping (Timeline<NextMedicationEntry>) -> Void) {
		Task { @MainActor in
			let entry = await createEntry()

			// Update every hour
			let nextUpdate = Calendar.current.date(
				byAdding: .hour,
				value: 1,
				to: Date()
			) ?? Date()

			let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
			completion(timeline)
		}
	}

	@MainActor
	private func createEntry() -> NextMedicationEntry {
		let provider = WatchWidgetDataProvider.shared
		return NextMedicationEntry(
			date: Date(),
			medication: provider.nextMedicationDue
		)
	}
}

// MARK: - Widget Views

struct NextMedicationWidgetView: View {
	let entry: NextMedicationEntry
	@Environment(\.widgetFamily) private var family

	var body: some View {
		switch family {
		case .accessoryCircular:
			CircularView(medication: entry.medication)
		case .accessoryRectangular:
			RectangularView(medication: entry.medication)
		case .accessoryCorner:
			CornerView(medication: entry.medication)
		case .accessoryInline:
			InlineView(medication: entry.medication)
		default:
			EmptyView()
		}
	}
}

// MARK: - Family-Specific Views

private struct CircularView: View {
	let medication: ANMedicationConcept?

	var body: some View {
		if let medication = medication {
			VStack(spacing: 2) {
				Image(systemName: medication.effectiveDisplaySymbol)
					.font(.title3)
					.symbolRenderingMode(.hierarchical)

				Text(medication.displayName)
					.font(.caption2)
					.lineLimit(1)
					.minimumScaleFactor(0.6)
			}
		} else {
			VStack(spacing: 2) {
				Image(systemName: "pills")
					.font(.title3)

				Text("None")
					.font(.caption2)
			}
		}
	}
}

private struct RectangularView: View {
	let medication: ANMedicationConcept?

	var body: some View {
		if let medication = medication {
			HStack(spacing: 8) {
				Image(systemName: medication.effectiveDisplaySymbol)
					.font(.title2)
					.symbolRenderingMode(.hierarchical)

				VStack(alignment: .leading, spacing: 2) {
					Text("Next Dose")
						.font(.caption2)
						.foregroundStyle(.secondary)

					Text(medication.displayName)
						.font(.body.weight(.semibold))
						.lineLimit(1)
				}

				Spacer()
			}
			.padding(.horizontal, 4)
		} else {
			HStack {
				Image(systemName: "pills")
					.font(.title2)

				VStack(alignment: .leading, spacing: 2) {
					Text("Next Dose")
						.font(.caption2)
						.foregroundStyle(.secondary)

					Text("No medications")
						.font(.caption)
				}

				Spacer()
			}
			.padding(.horizontal, 4)
		}
	}
}

private struct CornerView: View {
	let medication: ANMedicationConcept?

	var body: some View {
		if let medication = medication {
			Text(medication.displayName)
				.widgetLabel {
					Image(systemName: medication.effectiveDisplaySymbol)
						.symbolRenderingMode(.hierarchical)
				}
		} else {
			Text("None")
				.widgetLabel {
					Image(systemName: "pills")
				}
		}
	}
}

private struct InlineView: View {
	let medication: ANMedicationConcept?

	var body: some View {
		if let medication = medication {
			Text("Next: \(medication.displayName)")
		} else {
			Text("No medications")
		}
	}
}

// MARK: - Timeline Entry

struct NextMedicationEntry: TimelineEntry {
	let date: Date
	let medication: ANMedicationConcept?
}

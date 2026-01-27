// MedicationCountWidget.swift
// Watch complication showing medication count and doses taken today

import SwiftUI
import WidgetKit

struct MedicationCountWidget: Widget {
	let kind: String = "MedicationCountWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: MedicationCountProvider()) { entry in
			MedicationCountWidgetView(entry: entry)
		}
		.configurationDisplayName("Medication Count")
		.description("Shows medication count and doses today")
		.supportedFamilies([
			.accessoryCircular,
			.accessoryRectangular,
			.accessoryInline,
		])
	}
}

// MARK: - Timeline Provider

struct MedicationCountProvider: TimelineProvider {
	typealias Entry = MedicationCountEntry

	func placeholder(in _: Context) -> MedicationCountEntry {
		MedicationCountEntry(
			date: Date(),
			medicationCount: 5,
			dosesToday: 3
		)
	}

	func getSnapshot(in _: Context, completion: @escaping (MedicationCountEntry) -> Void) {
		Task { @MainActor in
			let entry = await createEntry()
			completion(entry)
		}
	}

	func getTimeline(in _: Context, completion: @escaping (Timeline<MedicationCountEntry>) -> Void) {
		Task { @MainActor in
			let entry = await createEntry()

			// Update every 30 minutes
			let nextUpdate = Calendar.current.date(
				byAdding: .minute,
				value: 30,
				to: Date()
			) ?? Date()

			let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
			completion(timeline)
		}
	}

	@MainActor
	private func createEntry() -> MedicationCountEntry {
		let provider = WatchWidgetDataProvider.shared
		return MedicationCountEntry(
			date: Date(),
			medicationCount: provider.medicationCount,
			dosesToday: provider.dosesToday
		)
	}
}

// MARK: - Widget Views

struct MedicationCountWidgetView: View {
	let entry: MedicationCountEntry
	@Environment(\.widgetFamily) private var family

	var body: some View {
		switch family {
		case .accessoryCircular:
			CircularCountView(count: entry.medicationCount)
		case .accessoryRectangular:
			RectangularCountView(medicationCount: entry.medicationCount, dosesToday: entry.dosesToday)
		case .accessoryInline:
			InlineCountView(medicationCount: entry.medicationCount, dosesToday: entry.dosesToday)
		default:
			EmptyView()
		}
	}
}

// MARK: - Family-Specific Views

private struct CircularCountView: View {
	let count: Int

	var body: some View {
		VStack(spacing: 2) {
			Image(systemName: "pills.fill")
				.font(.title3)
				.symbolRenderingMode(.hierarchical)

			Text("\(count)")
				.font(.title2.weight(.bold))
		}
	}
}

private struct RectangularCountView: View {
	let medicationCount: Int
	let dosesToday: Int

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 4) {
				Image(systemName: "pills.fill")
					.font(.caption)
				Text("\(medicationCount) medications")
					.font(.body.weight(.semibold))
			}

			HStack(spacing: 4) {
				Image(systemName: "checkmark.circle.fill")
					.font(.caption2)
					.foregroundStyle(.green)
				Text("\(dosesToday) doses today")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.padding(.horizontal, 4)
	}
}

private struct InlineCountView: View {
	let medicationCount: Int
	let dosesToday: Int

	var body: some View {
		Text("\(medicationCount) meds, \(dosesToday) today")
	}
}

// MARK: - Timeline Entry

struct MedicationCountEntry: TimelineEntry {
	let date: Date
	let medicationCount: Int
	let dosesToday: Int
}

import Foundation
import SFSafeSymbols
import SwiftUI
import WidgetKit

struct MedicationExperienceView: View {
	let entry: WidgetExperienceEntry
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.widgetFamily) private var family
	@Environment(\.dynamicTypeSize) private var typeSize
	private var projection: WidgetExperienceProjection { entry.projection }
	private var selected: WidgetExperienceProjection.Medication? {
		projection.medications.first { $0.id == (entry.selectedID ?? projection.automaticID) }
	}
	var body: some View {
		Group {
			if projection.state != .populated {
				WidgetEmptyView(state: projection.state)
			} else if family == .systemSmall, let medication = selected {
				VStack(alignment: .leading, spacing: 8) {
					WidgetMedicationHeading(medication: medication, name: projection.visibleName(for: medication))
					Spacer(minLength: 0)
					WidgetMedicationFacts(medication: medication, compact: typeSize.isAccessibilitySize)
				}
				.widgetURL(WidgetNavigationRoute.medication(medication.id).url)
			} else {
				VStack(alignment: .leading, spacing: 8) {
					HStack {
						Text(entry.selectedID == nil ? "Medications" : "Medication")
							.font(.customFont(fontFamily, style: .headline))
						Spacer(minLength: 0)
						WidgetRouteLink(route: .logDose(entry.selectedID)) {
							Label("Log Dose", systemSymbol: .plusCircleFill)
								.font(.customFont(fontFamily, style: .caption, weight: .semibold))
						}
					}
					if entry.selectedID != nil, let medication = selected {
						WidgetRouteLink(route: .medication(medication.id)) {
							VStack(alignment: .leading, spacing: 8) {
								WidgetMedicationHeading(medication: medication, name: projection.visibleName(for: medication))
								WidgetMedicationFacts(medication: medication, compact: false)
							}
						}
					} else {
						ForEach(Array(projection.medications.prefix(rowLimit))) { medication in
							WidgetRouteLink(route: .medication(medication.id)) {
								HStack(alignment: .top, spacing: 8) {
									WidgetMedicationHeading(medication: medication, name: projection.visibleName(for: medication))
									Spacer(minLength: 0)
									WidgetMedicationFacts(medication: medication, compact: true)
								}
							}
							if medication.id != projection.medications.prefix(rowLimit).last?.id { Divider() }
						}
					}
					Spacer(minLength: 0)
				}
				.widgetURL(WidgetNavigationRoute.medications.url)
			}
		}
		.tint(Color.accentColor)
	}
	private var rowLimit: Int {
		if typeSize.isAccessibilitySize { return family == .systemLarge ? 2 : 1 }
		return family == .systemLarge ? 5 : 2
	}
}

struct WidgetMedicationHeading: View {
	let medication: WidgetExperienceProjection.Medication
	let name: String
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.widgetRenderingMode) private var renderingMode
	var body: some View {
		HStack(alignment: .top, spacing: 6) {
			Image(systemSymbol: SFSymbol(rawValue: medication.symbol))
				.font(.customFont(fontFamily, style: .title3))
				.foregroundStyle(renderingMode == .fullColor ? (medication.colorHex.flatMap { Color(hex: $0) } ?? .accentColor) : .primary)
				.widgetAccentable()
				.accessibilityHidden(true)
			Text(name)
				.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
				.noTruncate()
				.privacySensitive()
		}
	}
}

struct WidgetMedicationFacts: View {
	let medication: WidgetExperienceProjection.Medication
	let compact: Bool
	@Environment(\.fontFamily) private var fontFamily
	var body: some View {
		VStack(alignment: .leading, spacing: 3) {
			if let last = medication.lastDose {
				Text("Last logged \(last, style: .relative) ago")
			} else { Text("No doses logged") }
			if let next = medication.nextWindow {
				if Calendar.current.isDateInToday(next) { Text("Saved window \(next, style: .time)") }
				else { Text("Saved window \(next, format: .dateTime.weekday(.abbreviated).hour().minute())") }
			} else if medication.timingUnknown {
				Text("Review timing in app")
			} else if let supply = medication.supply {
				Text("\(supply.formatted(.number.precision(.fractionLength(0...2)))) \(medication.supplyUnit ?? "units") remaining")
			}
			if !compact, let refill = medication.refillDate {
				Text("Refill \(refill, style: .date)")
			}
		}
		.font(.customFont(fontFamily, style: compact ? .caption2 : .caption))
		.foregroundStyle(.secondary)
		.privacySensitive()
	}
}

struct WidgetEmptyView: View {
	let state: WidgetExperienceProjection.State
	@Environment(\.fontFamily) private var fontFamily
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Image(systemSymbol: .pillsFill).foregroundStyle(.secondary).accessibilityHidden(true)
			Text(state == .empty ? "No medications" : "Medication unavailable")
				.font(.customFont(fontFamily, style: .headline))
			Text(state == .empty ? "Add a medication in AsNeeded." : "Open AsNeeded to review.")
				.font(.customFont(fontFamily, style: .caption))
				.foregroundStyle(.secondary)
		}
		.widgetURL(WidgetNavigationRoute.medications.url)
	}
}

struct WidgetRouteLink<Content: View>: View {
	let route: WidgetNavigationRoute
	@ViewBuilder let content: () -> Content
	var body: some View {
		if let url = route.url {
			Link(destination: url, label: content).buttonStyle(.plain)
		} else { content() }
	}
}

struct UsageExperienceView: View {
	let entry: WidgetExperienceEntry
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.widgetFamily) private var family
	@Environment(\.dynamicTypeSize) private var typeSize
	var body: some View {
		if let medication = entry.projection.medications.first(where: { $0.id == (entry.selectedID ?? entry.projection.automaticID) }), let usage = entry.projection.usage {
			VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 8) {
				Text(entry.projection.visibleName(for: medication))
					.font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
					.noTruncate()
				Text("7 complete days · ending yesterday")
					.font(.customFont(fontFamily, style: .caption2)).foregroundStyle(.secondary)
				if usage.quantitiesComplete {
					Text("\(usage.total.formatted(.number.precision(.fractionLength(0...2)))) \(usage.unit ?? "") logged")
						.font(.customFont(fontFamily, style: family == .systemSmall ? .headline : .title2, weight: .semibold))
					if !typeSize.isAccessibilitySize { WidgetUsageBars(days: usage.days, unit: usage.unit ?? "", showLabels: family != .systemSmall) }
					if family == .systemLarge, let previous = usage.previousTotal {
						Text("Previous 7 days: \(previous.formatted(.number.precision(.fractionLength(0...2)))) \(usage.unit ?? "")")
							.font(.customFont(fontFamily, style: .caption)).foregroundStyle(.secondary)
					}
				} else if usage.count > 0 {
					Text("\(usage.count) doses logged")
						.font(.customFont(fontFamily, style: .headline))
					Text("Quantity incomplete")
						.font(.customFont(fontFamily, style: .caption2)).foregroundStyle(.secondary)
					Text("Review History")
						.font(.customFont(fontFamily, style: .caption, weight: .semibold)).foregroundStyle(Color.accentColor)
				}
				if usage.count == 0, !usage.quantitiesComplete {
					Text("No doses logged").font(.customFont(fontFamily, style: .headline))
				}
				Spacer(minLength: 0)
			}
			.privacySensitive()
			.widgetURL(usage.quantitiesComplete ? WidgetNavigationRoute.trends(medication.id, days: 7).url : WidgetNavigationRoute.history(medication.id).url)
		} else { WidgetEmptyView(state: entry.projection.state) }
	}
}

struct WidgetUsageBars: View {
	let days: [WidgetExperienceProjection.Day]
	let unit: String
	let showLabels: Bool
	@Environment(\.fontFamily) private var fontFamily
	var body: some View {
		GeometryReader { geometry in
			HStack(alignment: .bottom, spacing: 6) {
				ForEach(days) { day in
					VStack(spacing: 4) {
						Spacer(minLength: 0)
						RoundedRectangle(cornerRadius: 3)
							.fill(Color.accentColor)
							.frame(height: day.quantity > 0 ? max(2, (geometry.size.height - (showLabels ? 20 : 0)) * day.quantity / max(1, days.map(\.quantity).max() ?? 1)) : 0)
							.widgetAccentable()
						if showLabels {
							Text(day.date, format: .dateTime.weekday(.narrow))
								.font(.customFont(fontFamily, style: .caption2)).foregroundStyle(.secondary)
						}
					}
						.frame(maxWidth: .infinity)
						.accessibilityElement(children: .ignore)
						.accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.quantity.formatted()) \(unit) logged")
				}
			}
		}
	}
}

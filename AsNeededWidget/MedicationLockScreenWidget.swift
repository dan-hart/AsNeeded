import Foundation
import SFSafeSymbols
import SwiftUI
import WidgetKit

struct MedicationLockScreenWidget: Widget {
	let kind = "MedicationLockScreenWidget"
	var body: some WidgetConfiguration {
		AppIntentConfiguration(kind: kind, intent: MedicationWidgetConfiguration.self, provider: WidgetExperienceProvider()) { entry in
			LockScreenExperienceView(entry: entry)
				.containerBackground(for: .widget) {}
		}
		.configurationDisplayName("Medication")
		.description("Check recorded timing and open the dose form.")
		.supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
	}
}

struct LockScreenExperienceView: View {
	let entry: WidgetExperienceEntry
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.widgetFamily) private var family
	var body: some View {
		if let medication = entry.projection.medications.first(where: { $0.id == (entry.selectedID ?? entry.projection.automaticID) }) {
			Group {
				if family == .accessoryCircular {
					Image(systemSymbol: SFSymbol(rawValue: medication.symbol))
						.font(.customFont(fontFamily, style: .title2))
						.accessibilityLabel("Open dose form for \(entry.projection.visibleName(for: medication))")
				} else if family == .accessoryInline {
					if let last = medication.lastDose {
						Text("\(entry.projection.visibleName(for: medication)) · logged \(last, style: .relative) ago")
					} else { Text("\(entry.projection.visibleName(for: medication)) · no logs") }
				} else {
					VStack(alignment: .leading, spacing: 2) {
						Text(entry.projection.visibleName(for: medication))
							.font(.customFont(fontFamily, style: .headline)).noTruncate()
						if let last = medication.lastDose {
							Text("Logged \(last, style: .relative) ago")
						} else { Text("No doses logged") }
						if let next = medication.nextWindow {
							if Calendar.current.isDate(next, inSameDayAs: entry.date) { Text("Window \(next, style: .time)") }
							else { Text("Window \(next, format: .dateTime.weekday(.abbreviated).hour().minute())") }
						}
					}
					.font(.customFont(fontFamily, style: .caption))
				}
			}
			.privacySensitive()
			.widgetURL(WidgetNavigationRoute.logDose(medication.id).url)
		} else {
			Text(entry.projection.state == .empty ? String(localized: "No medications") : String(localized: "Unavailable"))
				.font(.customFont(fontFamily, style: .caption))
				.widgetURL(WidgetNavigationRoute.medications.url)
		}
	}
}

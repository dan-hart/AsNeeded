import SwiftUI
import WidgetKit

struct MedicationUsageWidget: Widget {
	let kind = "MedicationUsageWidget"
	var body: some WidgetConfiguration {
		AppIntentConfiguration(kind: kind, intent: MedicationWidgetConfiguration.self, provider: WidgetExperienceProvider()) { entry in
			UsageExperienceView(entry: entry)
				.containerBackground(.fill.tertiary, for: .widget)
		}
		.configurationDisplayName("Medication Usage")
		.description("Logged quantity over seven complete days, ending yesterday.")
		.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
	}
}

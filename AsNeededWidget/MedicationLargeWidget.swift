import SwiftUI
import WidgetKit

struct MedicationLargeWidget: Widget {
	let kind = "MedicationLargeWidget"
	var body: some WidgetConfiguration {
		AppIntentConfiguration(kind: kind, intent: MedicationWidgetConfiguration.self, provider: WidgetExperienceProvider()) { entry in
			MedicationExperienceView(entry: entry)
				.containerBackground(.fill.tertiary, for: .widget)
		}
		.configurationDisplayName("Medication Overview")
		.description("Medication history, supply and saved windows at a glance.")
		.supportedFamilies([.systemLarge])
	}
}

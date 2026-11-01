import SwiftUI
import WidgetKit

struct MedicationSmallWidget: Widget {
	let kind = "MedicationSmallWidget"
	var body: some WidgetConfiguration {
		AppIntentConfiguration(kind: kind, intent: MedicationWidgetConfiguration.self, provider: WidgetExperienceProvider()) { entry in
			MedicationExperienceView(entry: entry)
				.containerBackground(.fill.tertiary, for: .widget)
		}
		.configurationDisplayName("Medication")
		.description("Last recorded dose and saved timing or supply.")
		.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
	}
}

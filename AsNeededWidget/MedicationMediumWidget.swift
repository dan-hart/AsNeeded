import SwiftUI
import WidgetKit

struct MedicationMediumWidget: Widget {
	let kind = "MedicationMediumWidget"
	var body: some WidgetConfiguration {
		AppIntentConfiguration(kind: kind, intent: MedicationWidgetConfiguration.self, provider: WidgetExperienceProvider()) { entry in
			MedicationExperienceView(entry: entry)
				.containerBackground(.fill.tertiary, for: .widget)
		}
		.configurationDisplayName("Medication Overview")
		.description("Medication details and a link to review a dose.")
		.supportedFamilies([.systemMedium])
	}
}

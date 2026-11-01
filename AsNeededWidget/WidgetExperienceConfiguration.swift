import ANModelKit
import AppIntents
import Foundation
import WidgetKit

struct WidgetMedicationEntity: AppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Medication"
	static let defaultQuery = WidgetMedicationQuery()
	let id: UUID
	let name: String
	var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct WidgetMedicationQuery: EntityQuery {
	func entities(for identifiers: [UUID]) async throws -> [WidgetMedicationEntity] {
		let current = await available()
		// Retain an unresolved stored UUID so the provider can show unavailable instead of Automatic.
		return identifiers.map { id in current.first { $0.id == id } ?? WidgetMedicationEntity(id: id, name: String(localized: "Unavailable medication")) }
	}
	func suggestedEntities() async throws -> [WidgetMedicationEntity] { await available() }
	@MainActor private func available() async -> [WidgetMedicationEntity] {
		let provider = WidgetDataProvider()
		await provider.loadSnapshot()
		return provider.medicationsByName.map { WidgetMedicationEntity(id: $0.id, name: $0.displayName) }
	}
}

struct MedicationWidgetConfiguration: WidgetConfigurationIntent {
	static let title: LocalizedStringResource = "Medication"
	static let description = IntentDescription("Choose a medication, or leave Automatic to use the overview or next saved window.")
	@Parameter(title: "Medication") var medication: WidgetMedicationEntity?
	@Parameter(title: "Show names", default: true) var showNames: Bool
	static var parameterSummary: some ParameterSummary {
		Summary { \.$medication; \.$showNames }
	}
}

struct WidgetExperienceEntry: TimelineEntry, Sendable {
	let date: Date
	let projection: WidgetExperienceProjection
	let selectedID: UUID?
}

struct WidgetExperienceProvider: AppIntentTimelineProvider {
	func placeholder(in context: Context) -> WidgetExperienceEntry { Self.sample() }
	func snapshot(for configuration: MedicationWidgetConfiguration, in context: Context) async -> WidgetExperienceEntry {
		if context.isPreview { return Self.sample(showNames: configuration.showNames) }
		return await load(configuration: configuration)
	}
	func timeline(for configuration: MedicationWidgetConfiguration, in context: Context) async -> Timeline<WidgetExperienceEntry> {
		await makeTimeline(configuration: configuration)
	}
	@MainActor private func load(configuration: MedicationWidgetConfiguration) async -> WidgetExperienceEntry {
		let provider = WidgetDataProvider()
		await provider.loadSnapshot()
		let date = Date()
		return WidgetExperienceEntry(date: date, projection: provider.projection(selectedID: configuration.medication?.id, showNames: configuration.showNames, at: date), selectedID: configuration.medication?.id)
	}
	@MainActor private func makeTimeline(configuration: MedicationWidgetConfiguration) async -> Timeline<WidgetExperienceEntry> {
		let provider = WidgetDataProvider()
		await provider.loadSnapshot()
		let initial = provider.projection(selectedID: configuration.medication?.id, showNames: configuration.showNames)
		let entries = initial.timelineDates.map { date in
			WidgetExperienceEntry(date: date, projection: provider.projection(selectedID: configuration.medication?.id, showNames: configuration.showNames, at: date), selectedID: configuration.medication?.id)
		}
		let reload = min(initial.date.addingTimeInterval(6 * 3600), (entries.last?.date ?? initial.date).addingTimeInterval(60))
		return Timeline(entries: entries, policy: .after(reload))
	}
	static func sample(showNames: Bool = true) -> WidgetExperienceEntry {
		let date = Date()
		let medication = ANMedicationConcept(clinicalName: String(localized: "Example medication"), quantity: 24, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		var events = (1...7).map { day in
			ANEventConcept(eventType: .doseTaken, medication: medication,
				dose: ANDoseConcept(amount: day.isMultiple(of: 3) ? 0.5 : 1, unit: .tablet),
				date: Calendar.current.date(byAdding: .day, value: -day, to: date) ?? date)
		}
		let examples = [
			ANMedicationConcept(clinicalName: String(localized: "Allergy relief"), quantity: 12, displayColorHex: "8E44AD", prescribedUnit: .tablet, prescribedDoseAmount: 1, minimumHoursBetweenDoses: 8),
			ANMedicationConcept(clinicalName: String(localized: "Rescue inhaler"), quantity: 20, displayColorHex: "16A085", prescribedUnit: .puff, prescribedDoseAmount: 2, minimumHoursBetweenDoses: 4),
			ANMedicationConcept(clinicalName: String(localized: "Muscle relief"), quantity: 8, displayColorHex: "D35400", prescribedUnit: .tablet, prescribedDoseAmount: 1, minimumHoursBetweenDoses: 6),
			ANMedicationConcept(clinicalName: String(localized: "Sleep support"), quantity: 10, displayColorHex: "2980B9", prescribedUnit: .capsule, prescribedDoseAmount: 1, minimumHoursBetweenDoses: 24),
		]
		for example in examples {
			events.append(ANEventConcept(eventType: .doseTaken, medication: example,
				dose: ANDoseConcept(amount: example.prescribedDoseAmount ?? 1, unit: example.prescribedUnit ?? .unit),
				date: date.addingTimeInterval(-3600)))
		}
		events.append(ANEventConcept(eventType: .doseTaken, medication: medication,
			dose: ANDoseConcept(amount: 8, unit: .tablet),
			date: Calendar.current.date(byAdding: .day, value: -10, to: date) ?? date))
		return WidgetExperienceEntry(date: date, projection: WidgetExperienceProjection(medications: [medication] + examples,
			events: events, showNames: showNames, at: date), selectedID: nil)
	}
}

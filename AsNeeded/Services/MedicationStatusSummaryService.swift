import ANModelKit
import Foundation

struct MedicationStatusSummaryService {
	struct Summary: Equatable {
		let headline: String
		let timingText: String
		let refillText: String
		let isLowStock: Bool
		let refillSoon: Bool
		let accessibilityLabel: String
	}

	private let calendar: Calendar
	private let refillProjectionService: MedicationRefillProjectionService
	private let timeFormatter: DateFormatter
	private let dateFormatter: DateFormatter

	init(
		calendar: Calendar = .current,
		locale: Locale = .current,
		refillProjectionService: MedicationRefillProjectionService? = nil
	) {
		self.calendar = calendar
		self.refillProjectionService = refillProjectionService ?? MedicationRefillProjectionService(calendar: calendar)
		self.timeFormatter = Self.makeFormatter(dateStyle: .none, timeStyle: .short, locale: locale, calendar: calendar)
		self.dateFormatter = Self.makeFormatter(dateStyle: .medium, timeStyle: .none, locale: locale, calendar: calendar)
	}

	func summary(
		for medication: ANMedicationConcept,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationRefillProfile
	) -> Summary {
		let projection = refillProjectionService.projection(
			for: medication,
			at: date,
			events: events,
			profile: profile
		)
		let timingText = lastDoseText(for: medication, at: date, events: events)
		let refillText = projection.statusMessage
		let headline: String
		if projection.lowStock {
			headline = "Low stock"
		} else if projection.refillSoon {
			headline = "Refill soon"
		} else {
			headline = "Refill status"
		}
		let accessibilityLabel = [medication.displayName, headline, timingText, refillText]
			.joined(separator: ". ")

		return Summary(
			headline: headline,
			timingText: timingText,
			refillText: refillText,
			isLowStock: projection.lowStock,
			refillSoon: projection.refillSoon,
			accessibilityLabel: accessibilityLabel
		)
	}

	private func lastDoseText(
		for medication: ANMedicationConcept,
		at date: Date,
		events: [ANEventConcept]
	) -> String {
		guard let lastDose = doseEvents(for: medication, through: date, events: events).last else {
			return "No doses logged yet"
		}

		let timeText = timeFormatter.string(from: lastDose.date)
		if calendar.isDate(lastDose.date, inSameDayAs: date) {
			return "Last taken \(timeText)"
		}

		return "Last taken \(dateFormatter.string(from: lastDose.date)) at \(timeText)"
	}

	private func doseEvents(
		for medication: ANMedicationConcept,
		through date: Date,
		events: [ANEventConcept]
	) -> [ANEventConcept] {
		events
			.filter { event in
				event.eventType == .doseTaken &&
					event.medication?.id == medication.id &&
					event.date <= date
			}
			.sorted { $0.date < $1.date }
	}

	private static func makeFormatter(
		dateStyle: DateFormatter.Style,
		timeStyle: DateFormatter.Style,
		locale: Locale,
		calendar: Calendar
	) -> DateFormatter {
		let formatter = DateFormatter()
		formatter.locale = locale
		formatter.calendar = calendar
		formatter.timeZone = calendar.timeZone
		formatter.dateStyle = dateStyle
		formatter.timeStyle = timeStyle
		return formatter
	}
}

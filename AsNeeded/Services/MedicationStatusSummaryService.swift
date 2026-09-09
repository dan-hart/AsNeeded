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

	init(
		calendar: Calendar = .current,
		refillProjectionService: MedicationRefillProjectionService? = nil
	) {
		self.calendar = calendar
		self.refillProjectionService = refillProjectionService ?? MedicationRefillProjectionService(calendar: calendar)
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

	private var timeFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "h:mm a"
		return formatter
	}

	private var dateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}
}

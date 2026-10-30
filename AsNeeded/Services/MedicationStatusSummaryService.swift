import ANModelKit
import Foundation

struct MedicationStatusSummaryService {
	struct Summary: Equatable {
		let severity: MedicationDoseGuidanceService.Severity
		let badgeText: String
		let headline: String
		let timingText: String
		let nextWindowText: String?
		let dailyText: String?
		let refillText: String
		let accessibilityLabel: String
	}

	private let locale: Locale
	private let calendar: Calendar
	private let guidanceService: MedicationDoseGuidanceService

	init(
		calendar: Calendar = .current,
		locale: Locale = .autoupdatingCurrent,
		guidanceService: MedicationDoseGuidanceService = MedicationDoseGuidanceService()
	) {
		self.calendar = calendar
		self.locale = locale
		self.guidanceService = guidanceService
	}

	func summary(
		for medication: ANMedicationConcept,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationSafetyProfile
	) -> Summary {
		let proposedDose = ANDoseConcept(
			amount: medication.prescribedDoseAmount ?? 1,
			unit: medication.prescribedUnit ?? .unit
		)
		let assessment = guidanceService.assessment(
			for: medication,
			proposedDose: proposedDose,
			at: date,
			events: events,
			profile: profile
		)
		let projection = guidanceService.refillProjection(
			for: medication,
			at: date,
			events: events,
			profile: profile
		)
		let timingText = lastDoseText(
			for: medication,
			at: date,
			events: events
		)
		let availability = guidanceService.availability(for: medication, at: date, events: events, profile: profile)
		let nextWindowText = availability.eligibleDate.flatMap { nextDate in
			guard nextDate > date else { return nil as String? }
			let time = timeFormatter.string(from: nextDate)
			let window = calendar.isDate(nextDate, inSameDayAs: date)
				? time : String(localized: "\(dateFormatter.string(from: nextDate)) at \(time)")
			return String(localized: "Next dose window: \(window)")
		}
		let dailyText: String?
		if availability.eligibleDate != nil {
			dailyText = self.dailyText(from: assessment, unit: proposedDose.unit)
		} else {
			dailyText = (medication.maximumDailyDoseAmount ?? profile.maxDailyAmount).map { maximum in
				let quantity = medication.prescribedUnit.map { $0.localizedCompactAmount(for: maximum, locale: locale) }
					?? String(localized: "\(maximum.formattedAmount(locale: locale)) \(String(localized: "(unit missing)"))")
				return String(localized: "Saved rolling 24-hour maximum: \(quantity)")
			}
		}
		let refillText = refillText(from: projection)
		let badgeText: String
		switch availability {
		case .notConfigured: badgeText = String(localized: "No dose limits")
		case .noDoseHistory: badgeText = String(localized: "No history")
		case .unavailable: badgeText = String(localized: "Review")
		case let .eligible(nextDate):
			badgeText = nextDate > date ? String(localized: "Waiting") : assessment.severity == .warning ? String(localized: "Review") : assessment.severity == .caution ? String(localized: "Caution") : String(localized: "Within saved limits", comment: "The user-saved timing/quantity constraints are satisfied based on recorded doses. This does not mean a maximum was reached or provide medical clearance.")
		}
		let headline = nextWindowText ?? (availability.eligibleDate != nil ? String(localized: "Saved limits met") : availability.message)
		let accessibilityLabel = [
			medication.displayName,
			timingText,
			nextWindowText,
			dailyText,
			refillText,
			availability.message
		]
		.compactMap { $0 }
		.joined(separator: ". ")

		return Summary(
			severity: assessment.severity,
			badgeText: badgeText,
			headline: headline,
			timingText: timingText,
			nextWindowText: nextWindowText,
			dailyText: dailyText,
			refillText: refillText,
			accessibilityLabel: accessibilityLabel
		)
	}

	private func lastDoseText(
		for medication: ANMedicationConcept,
		at date: Date,
		events: [ANEventConcept]
	) -> String {
		guard let lastDose = doseEvents(for: medication, through: date, events: events).last else {
			return String(localized: "No doses logged yet")
		}

		let timeText = timeFormatter.string(from: lastDose.date)
		if calendar.isDate(lastDose.date, inSameDayAs: date) {
			return String(localized: "Last taken \(timeText)")
		}

		return String(localized: "Last taken \(dateFormatter.string(from: lastDose.date)) at \(timeText)")
	}

	private func dailyText(
		from assessment: MedicationDoseGuidanceService.Assessment,
		unit: ANUnitConcept
	) -> String? {
		guard let maxDailyAmount = assessment.maxDailyAmount else {
			return nil
		}

		return String(localized: "With this dose: \(unit.localizedCompactAmount(for: assessment.projectedDailyTotal, locale: locale)) of \(unit.localizedCompactAmount(for: maxDailyAmount, locale: locale)) in 24 hours")
	}

	private func refillText(from projection: MedicationDoseGuidanceService.RefillProjection) -> String {
		if projection.lowStock {
			return String(localized: "Low stock: \(projection.statusMessage)")
		}

		if projection.refillSoon {
			return projection.statusMessage
		}

		return projection.statusMessage
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
		formatter.locale = locale
		formatter.timeZone = calendar.timeZone
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		return formatter
	}

	private var dateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.locale = locale
		formatter.timeZone = calendar.timeZone
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}
}

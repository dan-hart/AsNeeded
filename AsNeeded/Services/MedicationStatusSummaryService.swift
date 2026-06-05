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

	private let calendar: Calendar
	private let guidanceService: MedicationDoseGuidanceService

	init(
		calendar: Calendar = .current,
		guidanceService: MedicationDoseGuidanceService = MedicationDoseGuidanceService()
	) {
		self.calendar = calendar
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
		let nextWindowText = nextWindowText(
			from: assessment,
			at: date
		)
		let dailyText = dailyText(
			from: assessment,
			unit: proposedDose.unit
		)
		let refillText = refillText(from: projection)
		let badgeText = badgeText(for: assessment, profile: profile)
		let headline = headline(
			assessment: assessment,
			nextWindowText: nextWindowText,
			profile: profile
		)
		let accessibilityLabel = [
			medication.displayName,
			timingText,
			nextWindowText,
			dailyText,
			refillText,
			accessibilityGuardrailText(assessment: assessment, profile: profile)
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
			return "No doses logged yet"
		}

		let timeText = timeFormatter.string(from: lastDose.date)
		if calendar.isDate(lastDose.date, inSameDayAs: date) {
			return "Last taken \(timeText)"
		}

		return "Last taken \(dateFormatter.string(from: lastDose.date)) at \(timeText)"
	}

	private func nextWindowText(
		from assessment: MedicationDoseGuidanceService.Assessment,
		at date: Date
	) -> String? {
		guard let nextEligibleDate = assessment.nextEligibleDate, nextEligibleDate > date else {
			return nil
		}

		return "Next saved window \(timeFormatter.string(from: nextEligibleDate))"
	}

	private func dailyText(
		from assessment: MedicationDoseGuidanceService.Assessment,
		unit: ANUnitConcept
	) -> String? {
		guard let maxDailyAmount = assessment.maxDailyAmount else {
			return nil
		}

		return "24h total would be \(assessment.projectedDailyTotal.formattedAmount) of \(maxDailyAmount.formattedAmount) \(unit.abbreviation)"
	}

	private func refillText(from projection: MedicationDoseGuidanceService.RefillProjection) -> String {
		if projection.lowStock {
			return "Low stock: \(projection.statusMessage)"
		}

		if projection.refillSoon {
			return projection.statusMessage
		}

		return projection.statusMessage
	}

	private func badgeText(
		for assessment: MedicationDoseGuidanceService.Assessment,
		profile: MedicationSafetyProfile
	) -> String {
		switch assessment.severity {
		case .warning:
			return "Review"
		case .caution:
			return "Caution"
		case .clear:
			return profile.isEmpty ? "No guardrails" : "Within guidance"
		}
	}

	private func headline(
		assessment: MedicationDoseGuidanceService.Assessment,
		nextWindowText: String?,
		profile: MedicationSafetyProfile
	) -> String {
		if assessment.severity != .clear {
			return assessment.headline
		}

		if let nextWindowText {
			return nextWindowText
		}

		return profile.isEmpty ? "No saved guardrails" : "Available now"
	}

	private func accessibilityGuardrailText(
		assessment: MedicationDoseGuidanceService.Assessment,
		profile: MedicationSafetyProfile
	) -> String {
		if profile.isEmpty {
			return "No saved guardrails"
		}

		return assessment.headline
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

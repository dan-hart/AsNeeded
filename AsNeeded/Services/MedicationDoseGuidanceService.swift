import ANModelKit
import Foundation

struct MedicationDoseGuidanceService {
	enum Severity: Equatable {
		case clear
		case caution
		case warning
	}

	struct Assessment: Equatable {
		let severity: Severity
		let headline: String
		let detail: String
		let reasons: [String]
		let nextEligibleDate: Date?
		let lastDoseDate: Date?
		let dailyTotal: Double
		let projectedDailyTotal: Double
		let maxDailyAmount: Double?
		let isDuplicateCandidate: Bool
	}

	struct RefillProjection: Equatable {
		let estimatedDaysRemaining: Int?
		let projectedRunOutDate: Date?
		let averageDailyUsage: Double
		let lowStock: Bool
		let refillSoon: Bool
		let urgent: Bool
		let statusMessage: String
	}

	private let calendar: Calendar

	init(calendar: Calendar = .current) {
		self.calendar = calendar
	}

	func canTakeNow(
		medication: ANMedicationConcept,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationSafetyProfile = .empty
	) -> Bool {
		guard let nextEligibleDate = nextEligibleDate(
			for: medication,
			at: date,
			events: events,
			profile: profile
		) else {
			return true
		}

		return nextEligibleDate <= date
	}

	func nextEligibleDate(
		for medication: ANMedicationConcept,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationSafetyProfile = .empty
	) -> Date? {
		guard let minimumHoursBetweenDoses = profile.minimumHoursBetweenDoses,
		      let lastDoseDate = filteredDoseEvents(for: medication, events: events, through: date).last?.date
		else {
			return nil
		}

		return lastDoseDate.addingTimeInterval(minimumHoursBetweenDoses * 3600)
	}

	func assessment(
		for medication: ANMedicationConcept,
		proposedDose: ANDoseConcept?,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationSafetyProfile = .empty
	) -> Assessment {
		let filteredEvents = filteredDoseEvents(for: medication, events: events, through: date)
		let lastDoseDate = filteredEvents.last?.date
		let nextEligibleDate = nextEligibleDate(
			for: medication,
			at: date,
			events: filteredEvents,
			profile: profile
		)

		var reasons: [String] = []
		var severity: Severity = .clear
		let proposedUnit = proposedDose?.unit ?? medication.prescribedUnit
		let dailyTotal = dailyAmount(
			for: filteredEvents,
			endingAt: date,
			unit: proposedUnit
		)
		let projectedDailyTotal = dailyTotal + (proposedDose?.amount ?? 0)
		let duplicateCandidate = isDuplicateCandidate(
			for: proposedDose,
			at: date,
			events: filteredEvents,
			profile: profile
		)

		if duplicateCandidate {
			reasons.append("This looks close to a recent duplicate log.")
			severity = .warning
		}

		if let nextEligibleDate, nextEligibleDate > date {
			reasons.append("This is earlier than your saved minimum interval.")
			severity = .warning
		} else if let cautionHoursBetweenDoses = profile.normalizedCautionHoursBetweenDoses,
		          let lastDoseDate,
		          date.timeIntervalSince(lastDoseDate) < cautionHoursBetweenDoses * 3600
		{
			reasons.append("This is still inside your caution window.")
			severity = max(severity, .caution)
		}

		if let maxDailyAmount = profile.maxDailyAmount {
			if projectedDailyTotal > maxDailyAmount {
				reasons.append("This would exceed your saved daily limit.")
				severity = .warning
			} else if projectedDailyTotal >= maxDailyAmount * 0.8 {
				reasons.append("This would bring you close to your saved daily limit.")
				severity = max(severity, .caution)
			}
		}

		let headline: String
		let detail: String

		switch severity {
		case .warning:
			headline = "Review before logging"
			detail = reasons.first ?? "This dose is outside your saved guidance."
		case .caution:
			headline = "Close to a saved guardrail"
			detail = reasons.first ?? "This dose is still worth a second look."
		case .clear:
			headline = profile.isEmpty ? "No saved guardrails" : "Within saved guidance"
			detail = profile.isEmpty
				? "Add dose timing or refill guardrails in medication settings if you want more guidance."
				: "Recent timing and daily use look within the guidance you saved for this medication."
		}

		return Assessment(
			severity: severity,
			headline: headline,
			detail: detail,
			reasons: reasons,
			nextEligibleDate: nextEligibleDate,
			lastDoseDate: lastDoseDate,
			dailyTotal: dailyTotal,
			projectedDailyTotal: projectedDailyTotal,
			maxDailyAmount: profile.maxDailyAmount,
			isDuplicateCandidate: duplicateCandidate
		)
	}

	func refillProjection(
		for medication: ANMedicationConcept,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationSafetyProfile = .empty
	) -> RefillProjection {
		let filteredEvents = filteredDoseEvents(for: medication, events: events, through: date)
		let averageDailyUsage = averageDailyUsage(for: filteredEvents, preferredUnit: medication.prescribedUnit)
		let estimatedDaysRemaining: Int?
		let projectedRunOutDate: Date?

		if let quantity = medication.quantity,
		   quantity > 0,
		   averageDailyUsage > 0
		{
			let remainingDays = max(0, Int((quantity / averageDailyUsage).rounded(.down)))
			estimatedDaysRemaining = remainingDays
			projectedRunOutDate = calendar.date(byAdding: .day, value: remainingDays, to: date)
		} else {
			estimatedDaysRemaining = nil
			projectedRunOutDate = nil
		}

		let lowStockThreshold = profile.lowStockThreshold ?? 10
		let refillLeadDays = profile.refillLeadDays
		let quantity = medication.quantity ?? 0
		let lowStock = medication.quantity != nil && quantity <= lowStockThreshold
		let daysUntilRefill = medication.nextRefillDate.flatMap {
			calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: $0)).day
		}
		let refillSoon = lowStock ||
			(daysUntilRefill != nil && (daysUntilRefill ?? .max) <= refillLeadDays) ||
			(estimatedDaysRemaining != nil && (estimatedDaysRemaining ?? .max) <= refillLeadDays)
		let urgent = lowStock ||
			(daysUntilRefill != nil && (daysUntilRefill ?? .max) <= 2) ||
			(estimatedDaysRemaining != nil && (estimatedDaysRemaining ?? .max) <= 2)

		let statusMessage: String
		if urgent {
			statusMessage = "Refill prep would be timely."
		} else if refillSoon {
			statusMessage = "You’re approaching your refill window."
		} else if let estimatedDaysRemaining {
			statusMessage = "About \(estimatedDaysRemaining)d of supply at your recent pace."
		} else {
			statusMessage = "Log more doses to estimate your run-out date."
		}

		return RefillProjection(
			estimatedDaysRemaining: estimatedDaysRemaining,
			projectedRunOutDate: projectedRunOutDate,
			averageDailyUsage: averageDailyUsage,
			lowStock: lowStock,
			refillSoon: refillSoon,
			urgent: urgent,
			statusMessage: statusMessage
		)
	}

	private func filteredDoseEvents(
		for medication: ANMedicationConcept,
		events: [ANEventConcept],
		through date: Date
	) -> [ANEventConcept] {
		events
			.filter { event in
				event.eventType == .doseTaken &&
					event.medication?.id == medication.id &&
					event.date <= date
			}
			.sorted { $0.date < $1.date }
	}

	private func dailyAmount(
		for events: [ANEventConcept],
		endingAt date: Date,
		unit: ANUnitConcept?
	) -> Double {
		let startDate = date.addingTimeInterval(-24 * 3600)

		return events
			.filter { $0.date >= startDate && $0.date <= date }
			.compactMap { event -> Double? in
				guard let dose = event.dose else {
					return nil
				}

				if let unit, dose.unit != unit {
					return nil
				}

				return dose.amount
			}
			.reduce(0, +)
	}

	private func averageDailyUsage(
		for events: [ANEventConcept],
		preferredUnit: ANUnitConcept?
	) -> Double {
		let relevantEvents = events.filter { event in
			guard let dose = event.dose else {
				return false
			}

			if let preferredUnit {
				return dose.unit == preferredUnit
			}

			return true
		}

		guard !relevantEvents.isEmpty else {
			return 0
		}

		let grouped = Dictionary(grouping: relevantEvents) { event in
			calendar.startOfDay(for: event.date)
		}
		let activeDays = max(1, grouped.count)
		let total = relevantEvents.compactMap { $0.dose?.amount }.reduce(0, +)
		return total / Double(activeDays)
	}

	private func isDuplicateCandidate(
		for proposedDose: ANDoseConcept?,
		at date: Date,
		events: [ANEventConcept],
		profile: MedicationSafetyProfile
	) -> Bool {
		guard let lastEvent = events.last else {
			return false
		}

		let window = TimeInterval(profile.duplicateDoseWindowMinutes * 60)
		guard date.timeIntervalSince(lastEvent.date) <= window else {
			return false
		}

		guard let proposedDose else {
			return true
		}

		guard let lastDose = lastEvent.dose else {
			return true
		}

		return lastDose.unit == proposedDose.unit &&
			abs(lastDose.amount - proposedDose.amount) < 0.0001
	}
}

private func max(_ lhs: MedicationDoseGuidanceService.Severity, _ rhs: MedicationDoseGuidanceService.Severity) -> MedicationDoseGuidanceService.Severity {
	switch (lhs, rhs) {
	case (.warning, _), (_, .warning):
		return .warning
	case (.caution, _), (_, .caution):
		return .caution
	case (.clear, .clear):
		return .clear
	}
}

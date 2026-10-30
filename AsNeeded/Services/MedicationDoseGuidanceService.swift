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

	enum Availability: Equatable {
		case notConfigured
		case noDoseHistory
		case unavailable(LocalizedStringResource)
		case eligible(Date)

		var eligibleDate: Date? {
			if case let .eligible(date) = self { return date }
			return nil
		}

		/// Stable catalog key for a receiving device to resolve using its own language.
		var messageKey: String {
			switch self {
			case .notConfigured: return "No dose limits saved. Add dose timing or a 24-hour quantity limit in medication settings."
			case .noDoseHistory: return "Log a dose to calculate the next saved window."
			case let .unavailable(reason): return reason.key
			case .eligible: return "Based on your saved limits and logged doses."
			}
		}

		var message: String {
			switch self {
			case .notConfigured: return String(localized: "No dose limits saved. Add dose timing or a 24-hour quantity limit in medication settings.")
			case .noDoseHistory: return String(localized: "Log a dose to calculate the next saved window.")
			case let .unavailable(reason): return String(localized: reason)
			case .eligible: return String(localized: "Based on your saved limits and logged doses.")
			}
		}
	}

	func canTakeNow(
		medication: ANMedicationConcept,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationSafetyProfile = .empty
	) -> Bool {
		guard let eligible = availability(for: medication, at: date, events: events, profile: profile).eligibleDate else {
			return false
		}
		return eligible <= date
	}

	func nextEligibleDate(
		for medication: ANMedicationConcept,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationSafetyProfile = .empty
	) -> Date? {
		availability(for: medication, at: date, events: events, profile: profile).eligibleDate
	}

	/// Calculates a full saved dose against (candidate - 24 hours, candidate].
	/// This reports saved limits, not medical clearance or a recommendation to take a dose.
	func availability(
		for medication: ANMedicationConcept,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationSafetyProfile = .empty
	) -> Availability {
		let interval = medication.minimumHoursBetweenDoses ?? profile.minimumHoursBetweenDoses
		let maximum = medication.maximumDailyDoseAmount ?? profile.maxDailyAmount
		guard interval != nil || maximum != nil else { return .notConfigured }
		guard [interval, maximum].compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 > 0 }) else {
			return .unavailable("Enter positive, finite dose limits in medication settings.")
		}
		let doses = filteredDoseEvents(for: medication, events: events, through: date)
		guard let lastDose = doses.last else { return .noDoseHistory }
		var candidate = date
		if let interval {
			let next = lastDose.date.addingTimeInterval(interval * 3600)
			guard next.timeIntervalSince1970.isFinite else {
				return .unavailable("The saved dose interval is too large to calculate.")
			}
			candidate = max(candidate, next)
		}
		guard let maximum else { return .eligible(candidate) }
		guard let unit = medication.prescribedUnit,
		      let amount = medication.prescribedDoseAmount, amount.isFinite, amount > 0 else {
			return .unavailable("Set a dose amount and unit to check your 24-hour quantity limit.")
		}
		guard amount <= maximum else {
			return .unavailable("The saved dose exceeds your 24-hour quantity limit. Review medication settings.")
		}
		let recent = doses.filter { $0.date > candidate.addingTimeInterval(-24 * 3600) }
		guard recent.allSatisfy({ event in
			guard let dose = event.dose else { return false }
			return dose.unit == unit && dose.amount.isFinite && dose.amount > 0
		}) else {
			return .unavailable("Recent dose quantities or units do not match. Review your dose history.")
		}
		// Eligibility can change only when a recorded quantity exits the rolling window.
		let candidates = [candidate] + recent.map { $0.date.addingTimeInterval(24 * 3600) }
		for possible in candidates {
			let total = recent.filter { $0.date > possible.addingTimeInterval(-24 * 3600) }
				.compactMap { $0.dose?.amount }.reduce(0, +)
			if total.isFinite && quantityFits(total + amount, maximum: maximum) {
				return .eligible(possible)
			}
		}
		return .unavailable("The next saved window could not be calculated.")
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
		let maximum = medication.maximumDailyDoseAmount ?? profile.maxDailyAmount
		let incompatibleProposedUnit = maximum != nil && proposedDose != nil && proposedDose?.unit != medication.prescribedUnit
		var proposedMedication = medication
		if let proposedDose {
			proposedMedication.prescribedDoseAmount = proposedDose.amount
			if maximum == nil { proposedMedication.prescribedUnit = proposedDose.unit }
		}
		let availability: Availability = incompatibleProposedUnit
			? .unavailable("The dose unit does not match the saved 24-hour quantity limit. No conversion is assumed.")
			: availability(for: proposedMedication, at: date, events: filteredEvents, profile: profile)
		let nextEligibleDate = availability.eligibleDate

		var reasons: [String] = []
		var severity: Severity = .clear
		let proposedUnit = maximum != nil ? medication.prescribedUnit : (proposedDose?.unit ?? medication.prescribedUnit)
		let dailyTotal = dailyAmount(
			for: filteredEvents,
			endingAt: date,
			unit: proposedUnit
		)
		let projectedDailyTotal = dailyTotal + (incompatibleProposedUnit ? 0 : (proposedDose?.amount ?? 0))
		let duplicateCandidate = isDuplicateCandidate(
			for: proposedDose,
			at: date,
			events: filteredEvents,
			profile: profile
		)

		if duplicateCandidate {
			reasons.append(String(localized: "This looks close to a recent duplicate log."))
			severity = .warning
		}

		if case let .unavailable(reason) = availability {
			reasons.append(String(localized: reason))
			severity = .warning
		}

		let minimumHours = medication.minimumHoursBetweenDoses ?? profile.minimumHoursBetweenDoses
		if let minimumHours, let lastDoseDate, date.timeIntervalSince(lastDoseDate) < minimumHours * 3600 {
			reasons.append(String(localized: "This is earlier than your saved minimum interval."))
			severity = .warning
		} else if let cautionHoursBetweenDoses = profile.normalizedCautionHoursBetweenDoses,
		          let lastDoseDate,
		          date.timeIntervalSince(lastDoseDate) < cautionHoursBetweenDoses * 3600
		{
			reasons.append(String(localized: "This is still inside your caution window."))
			severity = max(severity, .caution)
		}

		if let maxDailyAmount = medication.maximumDailyDoseAmount ?? profile.maxDailyAmount {
			if !quantityFits(projectedDailyTotal, maximum: maxDailyAmount) {
				reasons.append(String(localized: "This would exceed your saved daily limit."))
				severity = .warning
			} else if projectedDailyTotal >= maxDailyAmount * 0.8 {
				reasons.append(String(localized: "This would bring you close to your saved daily limit."))
				severity = max(severity, .caution)
			}
		}

		let headline: String
		let detail: String

		switch severity {
		case .warning:
			headline = String(localized: "Review before logging")
			detail = reasons.first ?? String(localized: "This dose is outside your saved guidance.")
		case .caution:
			headline = String(localized: "Close to a saved guardrail")
			detail = reasons.first ?? String(localized: "This dose is still worth a second look.")
		case .clear:
			let hasGuidance = !profile.isEmpty || medication.minimumHoursBetweenDoses != nil || medication.maximumDailyDoseAmount != nil
			headline = hasGuidance ? String(localized: "Within saved guidance") : String(localized: "No saved guardrails")
			detail = !hasGuidance
				? String(localized: "Add dose timing or refill guardrails in medication settings if you want more guidance.")
				: String(localized: "Recent timing and daily use look within the guidance you saved for this medication.")
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
			maxDailyAmount: medication.maximumDailyDoseAmount ?? profile.maxDailyAmount,
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
		   quantity.isFinite, quantity > 0,
		   averageDailyUsage.isFinite, averageDailyUsage > 0,
		   let remainingDays = Int(exactly: (quantity / averageDailyUsage).rounded(.down))
		{
			estimatedDaysRemaining = remainingDays
			// Calendar can return a date whose components are clamped outside its supported range.
			// Keep the supply estimate, but only show a date that represents the requested day count.
			if date.timeIntervalSinceReferenceDate.isFinite,
			   let projectedDate = calendar.date(byAdding: .day, value: remainingDays, to: date),
			   projectedDate.timeIntervalSinceReferenceDate.isFinite,
			   calendar.dateComponents([.day], from: date, to: projectedDate).day == remainingDays {
				projectedRunOutDate = projectedDate
			} else {
				projectedRunOutDate = nil
			}
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
			statusMessage = String(localized: "Refill prep would be timely.")
		} else if refillSoon {
			statusMessage = String(localized: "You’re approaching your refill window.")
		} else if let estimatedDaysRemaining {
			statusMessage = String(localized: "About \(estimatedDaysRemaining)d of supply at your recent pace.")
		} else {
			statusMessage = String(localized: "Log more doses to estimate your run-out date.")
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

	/// Tolerate only floating-point representation error, not a meaningful extra quantity.
	private func quantityFits(_ quantity: Double, maximum: Double) -> Bool {
		guard quantity.isFinite, maximum.isFinite else { return false }
		return quantity <= maximum || quantity - maximum <= Swift.max(quantity.ulp, maximum.ulp) * 8
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
			.filter { $0.date > startDate && $0.date <= date }
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

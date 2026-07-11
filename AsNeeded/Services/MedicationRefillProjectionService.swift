import ANModelKit
import Foundation

struct MedicationRefillProjectionService {
	struct RefillProjection: Equatable {
		let estimatedDaysRemaining: Int?
		let projectedRunOutDate: Date?
		let averageDailyUsage: Double
		let lowStock: Bool
		let refillSoon: Bool
		let urgent: Bool
		let statusMessage: String
	}

	static let defaultLowStockThreshold: Double = 10
	static let refillLeadDays = 5

	private let calendar: Calendar

	init(calendar: Calendar = .current) {
		self.calendar = calendar
	}

	func projection(
		for medication: ANMedicationConcept,
		at date: Date = .now,
		events: [ANEventConcept],
		profile: MedicationRefillProfile = .empty
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

		let lowStockThreshold = profile.lowStockThreshold ?? Self.defaultLowStockThreshold
		let quantity = medication.quantity ?? 0
		let lowStock = medication.quantity != nil && quantity <= lowStockThreshold
		let daysUntilRefill = medication.nextRefillDate.flatMap {
			calendar.dateComponents(
				[.day],
				from: calendar.startOfDay(for: date),
				to: calendar.startOfDay(for: $0)
			).day
		}
		let refillSoon = lowStock ||
			(daysUntilRefill != nil && (daysUntilRefill ?? .max) <= Self.refillLeadDays) ||
			(estimatedDaysRemaining != nil && (estimatedDaysRemaining ?? .max) <= Self.refillLeadDays)
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
}

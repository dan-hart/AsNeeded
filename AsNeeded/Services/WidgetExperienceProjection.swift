import ANModelKit
import Foundation

/// A read-only value built once from a committed shared snapshot. No storage or UI dependencies.
struct WidgetExperienceProjection: Sendable {
	enum State: Equatable, Sendable { case populated, empty, unavailable, selectionUnavailable }
	struct Medication: Identifiable, Sendable {
		let id: UUID
		let name: String
		let symbol: String
		let colorHex: String?
		let lastDose: Date?
		let nextWindow: Date?
		let automaticPriorityDate: Date?
		let timingUnknown: Bool
		let supply: Double?
		let supplyUnit: ANUnitConcept?
		let refillDate: Date?
	}
	struct Day: Identifiable, Equatable, Sendable {
		let date: Date
		let quantity: Double
		let count: Int
		var id: Date { date }
	}
	struct Usage: Sendable {
		let days: [Day]
		let unit: ANUnitConcept?
		let quantitiesComplete: Bool
		let previousTotal: Double?
		var total: Double { days.reduce(0) { $0 + $1.quantity } }
		var count: Int { days.reduce(0) { $0 + $1.count } }
	}
	let date: Date
	let state: State
	let medications: [Medication]
	let automaticID: UUID?
	let showNames: Bool
	let usage: Usage?
	let timelineDates: [Date]

	func visibleName(for medication: Medication) -> String { showNames ? medication.name : String(localized: "Medication") }

	init(medications: [ANMedicationConcept], events: [ANEventConcept], profiles: [String: MedicationSafetyProfile] = [:], selectedID: UUID? = nil, showNames: Bool = true, storageAvailable: Bool = true, at date: Date, calendar: Calendar = .current) {
		self.date = date
		self.showNames = showNames
		let active = medications.filter { !$0.isArchived }.sorted {
			let lhs = $0.nickname.flatMap { $0.isEmpty ? nil : $0 } ?? $0.clinicalName
			let rhs = $1.nickname.flatMap { $0.isEmpty ? nil : $0 } ?? $1.clinicalName
			if lhs == rhs { return $0.id.uuidString < $1.id.uuidString }
			return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
		}
		let chosen = selectedID.map { id in active.filter { $0.id == id } } ?? active
		state = !storageAvailable ? .unavailable : selectedID != nil && chosen.isEmpty ? .selectionUnavailable : active.isEmpty ? .empty : .populated
		let service = MedicationDoseGuidanceService()
		let rows: [Medication] = storageAvailable ? chosen.map { medication in
			let profile = profiles[medication.id.uuidString] ?? .empty
			let availability = service.availability(for: medication, at: date, events: events, profile: profile)
			let next = availability.eligibleDate
			let doses = events.filter { $0.eventType == .doseTaken && $0.medication?.id == medication.id && $0.date <= date }
			return Medication(id: medication.id,
				name: medication.nickname.flatMap { $0.isEmpty ? nil : $0 } ?? medication.clinicalName,
				symbol: medication.symbolInfo?.name ?? "pills.fill", colorHex: medication.displayColorHex,
				lastDose: doses.map(\.date).max(), nextWindow: next.flatMap { $0 > date ? $0 : nil }, automaticPriorityDate: next,
				timingUnknown: { if case .unavailable = availability { return true }; return false }(),
				supply: medication.quantity.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil },
				supplyUnit: medication.prescribedUnit, refillDate: medication.nextRefillDate)
		} : []
		self.medications = rows
		automaticID = rows.min {
			let lhs = $0.automaticPriorityDate ?? .distantPast
			let rhs = $1.automaticPriorityDate ?? .distantPast
			return lhs == rhs ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending : lhs < rhs
		}?.id
		let usageID = selectedID ?? automaticID
		if storageAvailable, let medication = chosen.first(where: { $0.id == usageID }) {
			usage = Self.usage(for: medication, events: events, at: date, calendar: calendar)
		} else { usage = nil }
		let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86400)
		let boundaries = rows.compactMap(\.nextWindow).filter { $0 > date && $0 < midnight }
		let upcoming = Array(Set([date] + boundaries)).sorted().prefix(15)
		timelineDates = Array(upcoming) + [midnight]
	}

	private static func usage(for medication: ANMedicationConcept, events: [ANEventConcept], at date: Date, calendar: Calendar) -> Usage {
		let end = calendar.startOfDay(for: date)
		let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
		let previousStart = calendar.date(byAdding: .day, value: -7, to: start) ?? start
		let doses = events.filter { $0.eventType == .doseTaken && $0.medication?.id == medication.id && $0.date <= date }.sorted { $0.date < $1.date }
		let unit = medication.prescribedUnit ?? doses.compactMap { $0.dose?.unit }.first
		let current = doses.filter { $0.date >= start && $0.date < end }
		func complete(_ events: [ANEventConcept]) -> Bool {
			unit != nil && events.allSatisfy { event in
				guard let dose = event.dose else { return false }
				return dose.unit == unit && dose.amount.isFinite && dose.amount > 0
			}
		}
		let isComplete = complete(current)
		let days = (0..<7).compactMap { index -> Day? in
			guard let day = calendar.date(byAdding: .day, value: index, to: start),
				let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
			let bucket = current.filter { $0.date >= day && $0.date < next }
			return Day(date: day, quantity: isComplete ? bucket.compactMap { $0.dose?.amount }.reduce(0, +) : 0, count: bucket.count)
		}
		let previous = doses.filter { $0.date >= previousStart && $0.date < start }
		let total = days.reduce(0) { $0 + $1.quantity }
		let previousSum = previous.compactMap { $0.dose?.amount }.reduce(0, +)
		return Usage(days: days, unit: unit, quantitiesComplete: isComplete && total.isFinite,
			previousTotal: isComplete && complete(previous) && !previous.isEmpty && previousSum.isFinite ? previousSum : nil)
	}
}

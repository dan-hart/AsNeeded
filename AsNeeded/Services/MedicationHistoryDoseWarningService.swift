import ANModelKit
import Foundation

struct MedicationHistoryDoseWarningService {
	struct Dose: Equatable, Identifiable {
		let id: UUID
		let date: Date
		let amount: Double?
		let unit: ANUnitConcept?

		init(_ event: ANEventConcept) {
			id = event.id
			date = event.date
			amount = (event.dose?.amount).flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
			unit = event.dose?.unit
		}

		static func ordered(_ first: Self, _ second: Self) -> Bool {
			if first.date == second.date { return first.id.uuidString < second.id.uuidString }
			return first.date < second.date
		}

		func compatibleAmount(in unit: ANUnitConcept?) -> Double? {
			guard let unit, self.unit == unit else { return nil }
			return amount
		}
	}

	struct Spacing: Equatable {
		let previous: Dose
		let elapsed: TimeInterval
		let minimumHours: Double
	}

	enum QuantityFinding: Equatable {
		case exceeded(Double)
		case atLeast(Double)
		case overflow
		case unavailable
	}

	struct Warning: Equatable {
		let spacing: Spacing?
		let singleDose: QuantityFinding?
		let rolling: QuantityFinding?
		let singleMaximum: Double?
		let rollingMaximum: Double?
		let unit: ANUnitConcept?
	}

	struct Input: Equatable {
		struct Policy: Equatable {
			let saved: SavedDoseLimits
			let singleMaximum: Double?
		}

		let policies: [UUID: Policy]
		let timelines: [UUID: [Dose]]

		init(medications: [ANMedicationConcept], events: [ANEventConcept], profiles: [String: MedicationSafetyProfile]) {
			var policies: [UUID: Policy] = [:]
			for medication in medications {
				let saved = SavedDoseLimits(medication: medication, profile: profiles[medication.id.uuidString] ?? .empty)
				guard saved.minimumHours != nil || saved.maximumIn24Hours != nil || medication.maximumDoseAmount != nil else { continue }
				policies[medication.id] = Policy(saved: saved, singleMaximum: medication.maximumDoseAmount)
			}
			var timelines: [UUID: [Dose]] = [:]
			var seen: Set<UUID> = []
			for event in events {
				guard event.eventType == .doseTaken, event.date.timeIntervalSinceReferenceDate.isFinite,
					let medicationID = event.medication?.id, policies[medicationID] != nil,
					seen.insert(event.id).inserted else { continue }
				timelines[medicationID, default: []].append(Dose(event))
			}
			self.policies = policies
			self.timelines = timelines
		}
	}

	func warnings(medications: [ANMedicationConcept], events: [ANEventConcept], profiles: [String: MedicationSafetyProfile] = [:]) -> [UUID: Warning] {
		warnings(for: Input(medications: medications, events: events, profiles: profiles))
	}

	func warnings(for input: Input) -> [UUID: Warning] {
		var result: [UUID: Warning] = [:]
		for (medicationID, doses) in input.timelines {
			guard let policy = input.policies[medicationID] else { continue }
			let sorted = doses.sorted(by: Dose.ordered)
			let saved = policy.saved
			let unit = saved.unit
			var window = RollingAmounts()
			var expired = 0
			for (index, dose) in sorted.enumerated() {
				let spacing = index > 0 ? spacing(before: dose, previous: sorted[index - 1], minimum: saved.minimumHours) : nil
				let compatible = dose.compatibleAmount(in: unit)
				let single = policy.singleMaximum.flatMap { maximum in
					quantity(total: compatible ?? 0, hasUnknown: compatible == nil, maximum: maximum, unit: unit)
				}
				var rolling: QuantityFinding?
				if let maximum = saved.maximumIn24Hours {
					let cutoff = dose.date.addingTimeInterval(-SavedDoseLimits.rollingWindow)
					while expired < index, sorted[expired].date <= cutoff {
						window.removeFirst()
						expired += 1
					}
					window.append(compatible)
					// Use the final ID at a timestamp to anchor a single total that includes all tied entries.
					if index == sorted.count - 1 || sorted[index + 1].date > dose.date {
						let totals = window.totals
						rolling = quantity(total: totals.amount, hasUnknown: totals.unknownCount > 0, maximum: maximum, unit: unit)
					}
				}
				guard spacing != nil || single != nil || rolling != nil else { continue }
				result[dose.id] = Warning(spacing: spacing, singleDose: single, rolling: rolling,
					singleMaximum: policy.singleMaximum, rollingMaximum: saved.maximumIn24Hours, unit: unit)
			}
		}
		return result
	}

	private func spacing(before dose: Dose, previous: Dose, minimum: Double?) -> Spacing? {
		guard let minimum, minimum > 0, (minimum * 3_600).isFinite else { return nil }
		let elapsed = dose.date.timeIntervalSince(previous.date)
		guard elapsed < minimum * 3_600 else { return nil }
		return Spacing(previous: previous, elapsed: elapsed, minimumHours: minimum)
	}

	private func quantity(total: Double, hasUnknown: Bool, maximum: Double, unit: ANUnitConcept?) -> QuantityFinding? {
		guard unit != nil, maximum.isFinite, maximum > 0 else { return .unavailable }
		guard total.isFinite else { return .overflow }
		if !SavedDoseLimits.quantityFits(total, maximum: maximum) {
			return hasUnknown ? .atLeast(total) : .exceeded(total)
		}
		return hasUnknown ? .unavailable : nil
	}

	/// Two stacks keep an aggregate for each prefix, so expiring large values never
	/// subtracts them from a rounded or overflowing total. Each quantity moves once.
	private struct RollingAmounts {
		private struct Aggregate {
			var sum = 0.0
			var correction = 0.0
			var unknownCount = 0
			var amount: Double { sum + correction }

			mutating func add(_ value: Double?) {
				guard let value else { unknownCount += 1; return }
				let next = sum + value
				if next.isFinite {
					correction += sum >= value ? (sum - next) + value : (value - next) + sum
				} else {
					correction = 0
				}
				sum = next
			}
		}

		private struct Entry {
			let value: Double?
			let aggregate: Aggregate
		}

		private var incoming: [Entry] = []
		private var outgoing: [Entry] = []

		var totals: (amount: Double, unknownCount: Int) {
			let first = outgoing.last?.aggregate ?? Aggregate()
			let second = incoming.last?.aggregate ?? Aggregate()
			return (first.amount + second.amount, first.unknownCount + second.unknownCount)
		}

		mutating func append(_ value: Double?) {
			Self.append(value, to: &incoming)
		}

		mutating func removeFirst() {
			if outgoing.isEmpty {
				while let entry = incoming.popLast() {
					Self.append(entry.value, to: &outgoing)
				}
			}
			_ = outgoing.popLast()
		}

		private static func append(_ value: Double?, to stack: inout [Entry]) {
			var aggregate = stack.last?.aggregate ?? Aggregate()
			aggregate.add(value)
			stack.append(Entry(value: value, aggregate: aggregate))
		}
	}
}

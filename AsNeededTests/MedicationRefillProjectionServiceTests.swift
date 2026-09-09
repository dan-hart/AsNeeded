import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationRefillProjectionService Tests", .tags(.unit))
struct MedicationRefillProjectionServiceTests {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
		return calendar
	}

	private var now: Date {
		Date(timeIntervalSince1970: 1_735_689_600)
	}

	private func medication(
		quantity: Double? = 30,
		nextRefillDate: Date? = nil,
		unit: ANUnitConcept? = .tablet
	) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: "Ibuprofen",
			quantity: quantity,
			nextRefillDate: nextRefillDate,
			prescribedUnit: unit
		)
	}

	private func event(
		medication: ANMedicationConcept,
		daysAgo: Int,
		amount: Double,
		unit: ANUnitConcept = .tablet,
		eventType: ANEventType = .doseTaken
	) -> ANEventConcept {
		ANEventConcept(
			eventType: eventType,
			medication: medication,
			dose: ANDoseConcept(amount: amount, unit: unit),
			date: calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
		)
	}

	@Test("Average daily usage averages dose totals across active days")
	func averageDailyUsageAveragesActiveDays() {
		let medication = medication()
		let events = [
			event(medication: medication, daysAgo: 2, amount: 2),
			event(medication: medication, daysAgo: 1, amount: 1),
			event(medication: medication, daysAgo: 1, amount: 3),
		]

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: events
		)

		#expect(projection.averageDailyUsage == 3)
	}

	@Test("Average daily usage filters events to the prescribed unit")
	func averageDailyUsageFiltersByUnit() {
		let medication = medication(unit: .tablet)
		let events = [
			event(medication: medication, daysAgo: 1, amount: 2),
			event(medication: medication, daysAgo: 1, amount: 500, unit: .milligram),
		]

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: events
		)

		#expect(projection.averageDailyUsage == 2)
	}

	@Test("Average daily usage accepts one consistent unit without a prescribed unit")
	func averageDailyUsageAcceptsConsistentUnitWithoutPrescription() {
		let medication = medication(quantity: 12, unit: nil)
		let events = [
			event(medication: medication, daysAgo: 2, amount: 2),
			event(medication: medication, daysAgo: 1, amount: 4),
		]

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: events
		)

		#expect(projection.averageDailyUsage == 3)
		#expect(projection.estimatedDaysRemaining == 4)
		#expect(projection.aggregationUnit == .tablet)
	}

	@Test("Average daily usage declines mixed units without a prescribed unit")
	func averageDailyUsageDeclinesMixedUnitsWithoutPrescription() {
		let medication = medication(unit: nil)
		let events = [
			event(medication: medication, daysAgo: 1, amount: 2),
			event(medication: medication, daysAgo: 1, amount: 500, unit: .milligram),
		]

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: events
		)

		#expect(projection.averageDailyUsage == 0)
		#expect(projection.aggregationUnit == nil)
		#expect(projection.estimatedDaysRemaining == nil)
		#expect(projection.projectedRunOutDate == nil)
	}

	@Test("Average daily usage excludes future dose events")
	func averageDailyUsageExcludesFutureEvents() {
		let medication = medication()
		let futureEvent = event(medication: medication, daysAgo: -1, amount: 20)

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: [futureEvent]
		)

		#expect(projection.averageDailyUsage == 0)
		#expect(projection.estimatedDaysRemaining == nil)
	}

	@Test("Average daily usage excludes doses for other medications")
	func averageDailyUsageExcludesOtherMedications() {
		let medication = medication()
		let otherMedication = ANMedicationConcept(clinicalName: "Acetaminophen")
		let otherEvent = event(medication: otherMedication, daysAgo: 1, amount: 20)

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: [otherEvent]
		)

		#expect(projection.averageDailyUsage == 0)
		#expect(projection.estimatedDaysRemaining == nil)
	}

	@Test("Average daily usage excludes non-dose events")
	func averageDailyUsageExcludesNonDoseEvents() {
		let medication = medication()
		let reconcileEvent = event(
			medication: medication,
			daysAgo: 1,
			amount: 20,
			eventType: .reconcile
		)

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: [reconcileEvent]
		)

		#expect(projection.averageDailyUsage == 0)
		#expect(projection.estimatedDaysRemaining == nil)
	}

	@Test("Average daily usage groups doses by injected calendar day")
	func averageDailyUsageUsesCalendarDayBoundaries() {
		let medication = medication()
		let projectionDate = calendar.date(
			from: DateComponents(year: 2025, month: 1, day: 2, hour: 12)
		) ?? now
		let firstDate = calendar.date(
			from: DateComponents(year: 2025, month: 1, day: 1, hour: 23)
		) ?? now
		let secondDate = calendar.date(
			from: DateComponents(year: 2025, month: 1, day: 2, hour: 1)
		) ?? now
		let events = [
			ANEventConcept(
				eventType: .doseTaken,
				medication: medication,
				dose: ANDoseConcept(amount: 2, unit: .tablet),
				date: firstDate
			),
			ANEventConcept(
				eventType: .doseTaken,
				medication: medication,
				dose: ANDoseConcept(amount: 4, unit: .tablet),
				date: secondDate
			),
		]

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: projectionDate,
			events: events
		)

		#expect(projection.averageDailyUsage == 3)
	}

	@Test("Estimated days remaining uses current quantity and recent pace")
	func estimatesDaysRemaining() {
		let medication = medication(quantity: 11)
		let events = [
			event(medication: medication, daysAgo: 2, amount: 2),
			event(medication: medication, daysAgo: 1, amount: 2),
		]

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: events
		)

		#expect(projection.estimatedDaysRemaining == 5)
	}

	@Test("Projected run-out date advances by estimated remaining days")
	func projectsRunOutDate() {
		let medication = medication(quantity: 12)
		let events = [event(medication: medication, daysAgo: 1, amount: 3)]
		let expectedDate = calendar.date(byAdding: .day, value: 4, to: now)

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: events
		)

		#expect(projection.projectedRunOutDate == expectedDate)
	}

	@Test("Nil quantity without calendar refill status requests quantity")
	func nilQuantityWithoutCalendarRefillStatusRequestsQuantity() {
		let medication = medication(quantity: nil)
		let events = [event(medication: medication, daysAgo: 1, amount: 2)]

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: events
		)

		#expect(projection.averageDailyUsage == 2)
		#expect(projection.estimatedDaysRemaining == nil)
		#expect(projection.projectedRunOutDate == nil)
		#expect(!projection.lowStock)
		#expect(projection.statusMessage == "Add or update the quantity to see refill estimates.")
	}

	@Test("Nil quantity preserves urgent calendar refill status")
	func nilQuantityPreservesUrgentCalendarRefillStatus() {
		let refillDate = calendar.date(byAdding: .day, value: 1, to: now)
		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication(quantity: nil, nextRefillDate: refillDate),
			at: now,
			events: []
		)

		#expect(projection.urgent)
		#expect(projection.refillSoon)
		#expect(projection.statusMessage == "Refill prep would be timely.")
	}

	@Test("Nil quantity preserves refill-soon calendar status")
	func nilQuantityPreservesRefillSoonCalendarStatus() {
		let refillDate = calendar.date(byAdding: .day, value: 5, to: now)
		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication(quantity: nil, nextRefillDate: refillDate),
			at: now,
			events: []
		)

		#expect(!projection.urgent)
		#expect(projection.refillSoon)
		#expect(projection.statusMessage == "You’re approaching your refill window.")
	}

	@Test("Tracked quantity without usage history requests more dose logs")
	func trackedQuantityWithoutUsageHistoryRequestsDoseLogs() {
		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication(quantity: 30),
			at: now,
			events: []
		)

		#expect(projection.statusMessage == "Log more doses to estimate your run-out date.")
	}

	@Test("Zero quantity declines a run-out projection and is low stock")
	func zeroQuantityDeclinesRunOutProjection() {
		let medication = medication(quantity: 0)
		let events = [event(medication: medication, daysAgo: 1, amount: 2)]

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: events
		)

		#expect(projection.averageDailyUsage == 2)
		#expect(projection.estimatedDaysRemaining == nil)
		#expect(projection.projectedRunOutDate == nil)
		#expect(projection.lowStock)
	}

	@Test("A next-refill date inside the lead window is refill soon")
	func nextRefillDateTriggersRefillSoon() {
		let refillDate = calendar.date(byAdding: .day, value: 4, to: now)
		let medication = medication(quantity: 30, nextRefillDate: refillDate)

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: []
		)

		#expect(projection.refillSoon)
		#expect(!projection.urgent)
	}

	@Test("The default low-stock threshold is ten")
	func usesDefaultLowStockThreshold() {
		let medication = medication(quantity: 10)

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: []
		)

		#expect(MedicationRefillProjectionService.defaultLowStockThreshold == 10)
		#expect(projection.lowStock)
	}

	@Test("A custom low-stock threshold overrides the default")
	func usesCustomLowStockThreshold() {
		let medication = medication(quantity: 6)

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: [],
			profile: MedicationRefillProfile(lowStockThreshold: 5)
		)

		#expect(!projection.lowStock)
	}

	@Test("Low stock is urgent and refill soon")
	func lowStockIsUrgentAndRefillSoon() {
		let medication = medication(quantity: 4)

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: []
		)

		#expect(projection.lowStock)
		#expect(projection.refillSoon)
		#expect(projection.urgent)
		#expect(projection.statusMessage == "Refill prep would be timely.")
	}

	@Test("A run-out projection within two days is urgent")
	func imminentRunOutIsUrgent() {
		let medication = medication(quantity: 4)
		let events = [event(medication: medication, daysAgo: 1, amount: 2)]

		let projection = MedicationRefillProjectionService(calendar: calendar).projection(
			for: medication,
			at: now,
			events: events,
			profile: MedicationRefillProfile(lowStockThreshold: 1)
		)

		#expect(projection.estimatedDaysRemaining == 2)
		#expect(!projection.lowStock)
		#expect(projection.refillSoon)
		#expect(projection.urgent)
	}

	@Test("The refill lead window is fixed at five days")
	func usesFixedFiveDayRefillLeadWindow() {
		let fiveDays = calendar.date(byAdding: .day, value: 5, to: now)
		let sixDays = calendar.date(byAdding: .day, value: 6, to: now)
		let service = MedicationRefillProjectionService(calendar: calendar)

		let fiveDayProjection = service.projection(
			for: medication(quantity: 30, nextRefillDate: fiveDays),
			at: now,
			events: []
		)
		let sixDayProjection = service.projection(
			for: medication(quantity: 30, nextRefillDate: sixDays),
			at: now,
			events: []
		)

		#expect(MedicationRefillProjectionService.refillLeadDays == 5)
		#expect(fiveDayProjection.refillSoon)
		#expect(!sixDayProjection.refillSoon)
	}
}

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("CheckRefillStatusIntent Tests", .tags(.intent, .unit))
struct CheckRefillStatusIntentTests {
	@Test("Low-stock medications stay in the low-quantity bucket")
	func lowStockMedicationUsesLowQuantityBucket() {
		let medication = ANMedicationConcept(clinicalName: "Ibuprofen")
		let projection = MedicationRefillProjectionService.RefillProjection(
			estimatedDaysRemaining: 2,
			projectedRunOutDate: nil,
			averageDailyUsage: 1.5,
			lowStock: true,
			refillSoon: true,
			urgent: true,
			statusMessage: "Low stock"
		)

		let bucket = CheckRefillStatusIntent.refillBucket(
			for: medication,
			projection: projection,
			daysUntilRefill: 5
		)

		#expect(bucket == .lowQuantity(RefillInfo(name: "Ibuprofen", daysUntil: 2, quantity: nil)))
	}

	@Test("Refill-soon medications use the scheduled refill days")
	func refillSoonMedicationUsesScheduledDays() {
		let medication = ANMedicationConcept(clinicalName: "Ibuprofen", quantity: 20)
		let projection = MedicationRefillProjectionService.RefillProjection(
			estimatedDaysRemaining: 3,
			projectedRunOutDate: nil,
			averageDailyUsage: 2,
			lowStock: false,
			refillSoon: true,
			urgent: false,
			statusMessage: "Refill soon"
		)

		let bucket = CheckRefillStatusIntent.refillBucket(
			for: medication,
			projection: projection,
			daysUntilRefill: 5
		)

		#expect(bucket == .needsRefill(RefillInfo(name: "Ibuprofen", daysUntil: 5, quantity: 20)))
	}

	@Test("Refill-soon medications fall back to projected supply days")
	func refillSoonMedicationFallsBackToProjectedDays() {
		let medication = ANMedicationConcept(clinicalName: "Ibuprofen", quantity: 20)
		let projection = MedicationRefillProjectionService.RefillProjection(
			estimatedDaysRemaining: 3,
			projectedRunOutDate: nil,
			averageDailyUsage: 2,
			lowStock: false,
			refillSoon: true,
			urgent: false,
			statusMessage: "Refill soon"
		)

		let bucket = CheckRefillStatusIntent.refillBucket(
			for: medication,
			projection: projection,
			daysUntilRefill: nil
		)

		#expect(bucket == .needsRefill(RefillInfo(name: "Ibuprofen", daysUntil: 3, quantity: 20)))
	}

	@Test("Well-stocked medications have no refill bucket")
	func wellStockedMedicationHasNoBucket() {
		let medication = ANMedicationConcept(clinicalName: "Ibuprofen", quantity: 20)
		let projection = MedicationRefillProjectionService.RefillProjection(
			estimatedDaysRemaining: 10,
			projectedRunOutDate: nil,
			averageDailyUsage: 2,
			lowStock: false,
			refillSoon: false,
			urgent: false,
			statusMessage: "Well stocked"
		)

		let bucket = CheckRefillStatusIntent.refillBucket(
			for: medication,
			projection: projection,
			daysUntilRefill: nil
		)

		#expect(bucket == nil)
	}
}

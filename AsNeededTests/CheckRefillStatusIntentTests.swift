import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("CheckRefillStatusIntent Tests", .tags(.intent, .unit))
struct CheckRefillStatusIntentTests {
	@Test("Low-stock medications stay in the low-quantity bucket")
	func lowStockMedicationUsesLowQuantityBucket() {
		let medication = ANMedicationConcept(clinicalName: "Ibuprofen")
		let projection = MedicationDoseGuidanceService.RefillProjection(
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
}

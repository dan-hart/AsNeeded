import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationStatusSummaryService Tests", .tags(.unit))
struct MedicationStatusSummaryServiceTests {
	private let calendar = Calendar(identifier: .gregorian)

	private var referenceDate: Date {
		DateComponents(calendar: calendar, year: 2026, month: 6, day: 5, hour: 12).date ?? Date(timeIntervalSince1970: 1_780_685_200)
	}

	private func medication(
		quantity: Double? = 12,
		nextRefillDate: Date? = nil
	) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: "Ibuprofen",
			nickname: "Pain Relief",
			quantity: quantity,
			initialQuantity: 30,
			lastRefillDate: calendar.date(byAdding: .day, value: -10, to: referenceDate),
			nextRefillDate: nextRefillDate ?? calendar.date(byAdding: .day, value: 10, to: referenceDate),
			prescribedUnit: .tablet,
			prescribedDoseAmount: 2
		)
	}

	private func event(medication: ANMedicationConcept, date: Date) -> ANEventConcept {
		ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 2, unit: .tablet),
			date: date
		)
	}

	@Test("Last-dose text covers no history, today, and an older date")
	func lastDoseFormatting() {
		let medication = medication()
		let service = MedicationStatusSummaryService(calendar: calendar)
		let none = service.summary(for: medication, at: referenceDate, events: [], profile: .empty)
		let today = service.summary(
			for: medication,
			at: referenceDate,
			events: [event(medication: medication, date: referenceDate.addingTimeInterval(-2 * 3600))],
			profile: .empty
		)
		let older = service.summary(
			for: medication,
			at: referenceDate,
			events: [event(medication: medication, date: referenceDate.addingTimeInterval(-26 * 3600))],
			profile: .empty
		)

		#expect(none.timingText == "No doses logged yet")
		#expect(today.timingText == "Last taken 10:00 AM")
		#expect(older.timingText.contains("Last taken"))
		#expect(older.timingText.contains("Jun 4, 2026"))
		#expect(older.timingText.contains("10:00 AM"))
	}

	@Test("Normal stock summary has neutral refill status")
	func normalStockSummary() {
		let medication = medication(quantity: 30)
		let summary = MedicationStatusSummaryService(calendar: calendar).summary(
			for: medication,
			at: referenceDate,
			events: [],
			profile: .empty
		)

		#expect(summary.headline == "Refill status")
		#expect(summary.refillText == "Log more doses to estimate your run-out date.")
		#expect(!summary.isLowStock)
		#expect(!summary.refillSoon)
	}

	@Test("Upcoming refill date creates refill-soon-only summary")
	func refillSoonOnlySummary() {
		let refillDate = calendar.date(byAdding: .day, value: 4, to: referenceDate)
		let medication = medication(quantity: 30, nextRefillDate: refillDate)
		let summary = MedicationStatusSummaryService(calendar: calendar).summary(
			for: medication,
			at: referenceDate,
			events: [],
			profile: .empty
		)

		#expect(summary.headline == "Refill soon")
		#expect(summary.refillText == "You’re approaching your refill window.")
		#expect(!summary.isLowStock)
		#expect(summary.refillSoon)
	}

	@Test("Custom low-stock profile creates low-stock summary without duplicate wording")
	func customLowStockProfileDrivesRefillStatus() {
		let medication = medication(quantity: 12)
		let summary = MedicationStatusSummaryService(calendar: calendar).summary(
			for: medication,
			at: referenceDate,
			events: [],
			profile: MedicationRefillProfile(lowStockThreshold: 15)
		)

		#expect(summary.headline == "Low stock")
		#expect(summary.refillText == "Refill prep would be timely.")
		#expect(summary.accessibilityLabel.components(separatedBy: "Low stock").count - 1 == 1)
		#expect(summary.isLowStock)
		#expect(summary.refillSoon)
	}

	@Test("Missing quantity prompts quantity tracking")
	func missingQuantityPromptsQuantityTracking() {
		let summary = MedicationStatusSummaryService(calendar: calendar).summary(
			for: medication(quantity: nil),
			at: referenceDate,
			events: [],
			profile: .empty
		)

		#expect(summary.refillText == "Add or update the quantity to see refill estimates.")
	}

	@Test("Summary strings contain refill and history facts only")
	func summaryStringsContainRefillAndHistoryFactsOnly() {
		let medication = medication()
		let summary = MedicationStatusSummaryService(calendar: calendar).summary(
			for: medication,
			at: referenceDate,
			events: [],
			profile: .empty
		)
		let strings = [summary.headline, summary.timingText, summary.refillText, summary.accessibilityLabel]
		let forbiddenClaims = ["guardrail", "guidance", "next window", "daily limit", "eligible", "available now"]

		#expect(summary.accessibilityLabel.contains("Pain Relief"))
		#expect(summary.accessibilityLabel.contains("No doses logged yet"))
		for string in strings {
			for claim in forbiddenClaims {
				#expect(!string.localizedCaseInsensitiveContains(claim))
			}
		}
	}
}

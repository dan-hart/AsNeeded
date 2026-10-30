import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationStatusSummaryService Tests", .tags(.unit))
struct MedicationStatusSummaryServiceTests {
	private let calendar = Calendar(identifier: .gregorian)

	private var referenceDate: Date {
		DateComponents(calendar: calendar, year: 2026, month: 6, day: 5, hour: 12, minute: 0).date ?? Date(timeIntervalSince1970: 1_780_685_200)
	}

	private func medication(quantity: Double? = 12) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: "Ibuprofen",
			nickname: "Pain Relief",
			quantity: quantity,
			initialQuantity: 30,
			lastRefillDate: calendar.date(byAdding: .day, value: -10, to: referenceDate),
			nextRefillDate: calendar.date(byAdding: .day, value: 2, to: referenceDate),
			prescribedUnit: .tablet,
			prescribedDoseAmount: 2
		)
	}

	private func event(
		medication: ANMedicationConcept,
		hoursAgo: Double,
		amount: Double = 2
	) -> ANEventConcept {
		ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: amount, unit: .tablet),
			date: referenceDate.addingTimeInterval(-(hoursAgo * 3600))
		)
	}

	@Test("Summary includes last dose and next saved window")
	func summaryIncludesLastDoseAndNextWindow() {
		let medication = medication()
		let profile = MedicationSafetyProfile(minimumHoursBetweenDoses: 4)
		let summary = MedicationStatusSummaryService().summary(
			for: medication,
			at: referenceDate,
			events: [event(medication: medication, hoursAgo: 2)],
			profile: profile
		)

		#expect(summary.timingText.contains("Last taken"))
		let expectedLastTime = DateFormatter.localizedString(from: referenceDate.addingTimeInterval(-2 * 3600), dateStyle: .none, timeStyle: .short)
		#expect(summary.timingText.contains(expectedLastTime))
		#expect(summary.nextWindowText?.contains("Next dose window") == true)
		let expectedNextTime = DateFormatter.localizedString(from: referenceDate.addingTimeInterval(2 * 3600), dateStyle: .none, timeStyle: .short)
		#expect(summary.nextWindowText?.contains(expectedNextTime) == true)
		#expect(summary.severity == .warning)
		#expect(summary.badgeText == "Waiting")
	}

	@Test("Summary includes daily limit and refill pressure text")
	func summaryIncludesDailyLimitAndRefillPressure() {
		let medication = medication(quantity: 4)
		let profile = MedicationSafetyProfile(maxDailyAmount: 6, lowStockThreshold: 5, refillLeadDays: 3)
		let summary = MedicationStatusSummaryService().summary(
			for: medication,
			at: referenceDate,
			events: [
				event(medication: medication, hoursAgo: 3),
				event(medication: medication, hoursAgo: 8)
			],
			profile: profile
		)

		#expect(summary.dailyText == "With this dose: 6 tablets of 6 tablets in 24 hours")
		#expect(summary.refillText.contains("Low stock"))
		#expect(summary.refillText.contains("Refill prep"))
	}

	@Test("Accessibility summary contains medication name and non-color status")
	func accessibilitySummaryContainsMedicationNameAndStatus() {
		let medication = medication()
		let summary = MedicationStatusSummaryService().summary(
			for: medication,
			at: referenceDate,
			events: [],
			profile: .empty
		)

		#expect(summary.accessibilityLabel.contains("Pain Relief"))
		#expect(summary.accessibilityLabel.contains("No doses logged yet"))
		#expect(summary.accessibilityLabel.contains("No dose limits saved"))
	}
}

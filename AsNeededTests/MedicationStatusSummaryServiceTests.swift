import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationStatusSummaryService Tests", .tags(.unit))
struct MedicationStatusSummaryServiceTests {
	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}()
	private let locale = Locale(identifier: "en_US_POSIX")

	private var referenceDate: Date {
		DateComponents(calendar: calendar, year: 2026, month: 6, day: 5, hour: 12).date ?? Date(timeIntervalSince1970: 1_780_685_200)
	}

	private func service(locale: Locale? = nil) -> MedicationStatusSummaryService {
		MedicationStatusSummaryService(calendar: calendar, locale: locale ?? self.locale)
	}

	/// Mirrors the service's formatter configuration so expectations stay valid across ICU updates
	/// (for example the narrow no-break space newer ICU data inserts before AM/PM).
	private func formatted(
		_ date: Date,
		dateStyle: DateFormatter.Style,
		timeStyle: DateFormatter.Style,
		locale: Locale? = nil
	) -> String {
		let formatter = DateFormatter()
		formatter.locale = locale ?? self.locale
		formatter.calendar = calendar
		formatter.timeZone = calendar.timeZone
		formatter.dateStyle = dateStyle
		formatter.timeStyle = timeStyle
		return formatter.string(from: date)
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
		let summaryService = service()
		let todayDoseDate = referenceDate.addingTimeInterval(-2 * 3600)
		let olderDoseDate = referenceDate.addingTimeInterval(-26 * 3600)
		let none = summaryService.summary(for: medication, at: referenceDate, events: [], profile: .empty)
		let today = summaryService.summary(
			for: medication,
			at: referenceDate,
			events: [event(medication: medication, date: todayDoseDate)],
			profile: .empty
		)
		let older = summaryService.summary(
			for: medication,
			at: referenceDate,
			events: [event(medication: medication, date: olderDoseDate)],
			profile: .empty
		)
		let todayTimeText = formatted(todayDoseDate, dateStyle: .none, timeStyle: .short)
		let olderTimeText = formatted(olderDoseDate, dateStyle: .none, timeStyle: .short)
		let olderDateText = formatted(olderDoseDate, dateStyle: .medium, timeStyle: .none)

		#expect(none.timingText == "No doses logged yet")
		#expect(today.timingText == "Last taken \(todayTimeText)")
		#expect(today.timingText.contains("10:00"))
		#expect(today.timingText.contains("AM"))
		#expect(older.timingText == "Last taken \(olderDateText) at \(olderTimeText)")
		#expect(older.timingText.contains("Jun"))
		#expect(older.timingText.contains("2026"))
		#expect(older.timingText.contains("10:00"))
	}

	@Test("Twenty-four-hour locale renders the last-dose time without AM/PM")
	func lastDoseFormattingRespectsTwentyFourHourLocale() {
		let medication = medication()
		let doseDate = referenceDate.addingTimeInterval(-2 * 3600)
		let events = [event(medication: medication, date: doseDate)]
		let twelveHour = service().summary(for: medication, at: referenceDate, events: events, profile: .empty)
		let twentyFourHour = service(locale: Locale(identifier: "en_GB")).summary(
			for: medication,
			at: referenceDate,
			events: events,
			profile: .empty
		)

		#expect(twelveHour.timingText.contains("AM"))
		#expect(twentyFourHour.timingText == "Last taken 10:00")
		#expect(!twentyFourHour.timingText.contains("AM"))
		#expect(!twentyFourHour.timingText.contains("PM"))
	}

	@Test("Normal stock summary has neutral refill status")
	func normalStockSummary() {
		let medication = medication(quantity: 30)
		let summary = service().summary(
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
		let summary = service().summary(
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
		let summary = service().summary(
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
		let summary = service().summary(
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
		let summary = service().summary(
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

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("System clock format")
struct ClockFormatRegressionTests {
	@Test("Confirmation and availability follow 12/24-hour locale preferences", arguments: ["en_US", "en_GB"])
	func clockFormat(_ identifier: String) throws {
		let zone = try #require(TimeZone(secondsFromGMT: 0))
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = zone
		let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 18, minute: 5)))
		var med = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet, prescribedDoseAmount: 1)
		med.minimumHoursBetweenDoses = 1
		let dose = ANDoseConcept(amount: 1, unit: .tablet)
		let event = ANEventConcept(eventType: .doseTaken, medication: med, dose: dose, date: date)
		let assessment = MedicationDoseGuidanceService(calendar: calendar).assessment(for: med,
			proposedDose: dose, at: date, events: [], profile: .empty)
		let feedback = QuickLogFeedbackService(locale: Locale(identifier: identifier), timeZone: zone).feedback(
			medication: med, dose: dose, loggedEvent: event, assessment: assessment,
			nextDoseDate: date.addingTimeInterval(3600), at: date)
		let summary = MedicationStatusSummaryService(calendar: calendar, locale: Locale(identifier: identifier))
			.summary(for: med, at: date, events: [event], profile: .empty)
		if identifier == "en_GB" {
			#expect(feedback.message.contains("18:05"))
			#expect(feedback.nextWindowText?.contains("19:05") == true)
			#expect(summary.nextWindowText?.contains("19:05") == true)
			#expect(!feedback.message.contains("PM"))
		} else {
			#expect(feedback.message.contains("6:05"))
			#expect(feedback.message.contains("PM"))
			#expect(feedback.nextWindowText?.contains("7:05") == true)
			#expect(summary.nextWindowText?.contains("7:05") == true)
		}
	}
	@Test("The next-day date uses the injected zone at midnight")
	func midnightBoundary() throws {
		let zone = try #require(TimeZone(secondsFromGMT: 14 * 3600))
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = zone
		let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 23, minute: 50)))
		let next = date.addingTimeInterval(1200)
		let med = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet)
		let dose = ANDoseConcept(amount: 1, unit: .tablet)
		let event = ANEventConcept(eventType: .doseTaken, medication: med, dose: dose, date: date)
		let assessment = MedicationDoseGuidanceService().assessment(for: med, proposedDose: dose, at: date, events: [], profile: .empty)
		let feedback = QuickLogFeedbackService(locale: Locale(identifier: "en_GB"), timeZone: zone)
			.feedback(medication: med, dose: dose, loggedEvent: event, assessment: assessment, nextDoseDate: next, at: date)
		#expect(feedback.nextWindowText?.contains("29 Oct 2026") == true)
		#expect(feedback.nextWindowText?.contains("00:10") == true)
	}

}

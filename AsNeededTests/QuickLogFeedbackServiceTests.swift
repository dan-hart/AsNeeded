import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("QuickLogFeedbackService Tests", .tags(.unit))
struct QuickLogFeedbackServiceTests {
	private let calendar = Calendar(identifier: .gregorian)

	private var referenceDate: Date {
		DateComponents(calendar: calendar, year: 2026, month: 6, day: 5, hour: 12, minute: 0).date ?? Date(timeIntervalSince1970: 1_780_685_200)
	}

	private func medication() -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: "Ibuprofen",
			nickname: nil,
			quantity: 20,
			prescribedUnit: .tablet,
			prescribedDoseAmount: 2
		)
	}

	private func event(medication: ANMedicationConcept) -> ANEventConcept {
		ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 2, unit: .tablet),
			date: referenceDate
		)
	}

	@Test("Feedback uses success tone for clear guidance")
	func feedbackUsesSuccessToneForClearGuidance() {
		let medication = medication()
		let dose = ANDoseConcept(amount: 2, unit: .tablet)
		let assessment = MedicationDoseGuidanceService().assessment(
			for: medication,
			proposedDose: dose,
			at: referenceDate,
			events: [],
			profile: .empty
		)

		let feedback = QuickLogFeedbackService().feedback(
			medication: medication,
			dose: dose,
			loggedEvent: event(medication: medication),
			assessment: assessment,
			nextDoseDate: nil,
			at: referenceDate
		)

		#expect(feedback.tone == .success)
		#expect(feedback.title == "Dose logged")
		let expectedTime = DateFormatter.localizedString(from: referenceDate, dateStyle: .none, timeStyle: .short)
		#expect(feedback.message == "Logged 2 tab of Ibuprofen at \(expectedTime).")
		#expect(feedback.undoEventID != nil)
		#expect(feedback.nextDoseDate == nil)
	}

	@Test("Feedback preserves the warning while displaying the newly logged dose window")
	func feedbackUsesPostLogWindowAndPreLogWarning() {
		let medication = medication()
		let dose = ANDoseConcept(amount: 2, unit: .tablet)
		let priorEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: dose,
			date: referenceDate.addingTimeInterval(-2 * 3600)
		)
		let assessment = MedicationDoseGuidanceService().assessment(
			for: medication,
			proposedDose: dose,
			at: referenceDate,
			events: [priorEvent],
			profile: MedicationSafetyProfile(minimumHoursBetweenDoses: 4)
		)

		let feedback = QuickLogFeedbackService().feedback(
			medication: medication,
			dose: dose,
			loggedEvent: event(medication: medication),
			assessment: assessment,
			nextDoseDate: referenceDate.addingTimeInterval(4 * 3600),
			at: referenceDate
		)

		#expect(feedback.tone == .warning)
		#expect(feedback.title == "Dose logged. Review limits.")
		#expect(feedback.detail == assessment.detail)
		#expect(assessment.nextEligibleDate == referenceDate.addingTimeInterval(2 * 3600))
		#expect(feedback.nextDoseDate == referenceDate.addingTimeInterval(4 * 3600))
		let expectedTime = DateFormatter.localizedString(from: referenceDate.addingTimeInterval(4 * 3600), dateStyle: .none, timeStyle: .short)
		#expect(feedback.nextWindowText == "Next dose window: \(expectedTime)")
	}

	@Test("An absent or elapsed post-log window does not reuse the earlier assessment")
	func feedbackOmitsAbsentOrElapsedPostLogWindow() {
		let medication = medication()
		let dose = ANDoseConcept(amount: 2, unit: .tablet)
		let priorEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: dose,
			date: referenceDate.addingTimeInterval(-2 * 3600)
		)
		let assessment = MedicationDoseGuidanceService().assessment(
			for: medication,
			proposedDose: dose,
			at: referenceDate,
			events: [priorEvent],
			profile: MedicationSafetyProfile(minimumHoursBetweenDoses: 4)
		)
		for nextDate in [nil, referenceDate, referenceDate.addingTimeInterval(-60)] {
			let feedback = QuickLogFeedbackService().feedback(
				medication: medication,
				dose: dose,
				loggedEvent: event(medication: medication),
				assessment: assessment,
				nextDoseDate: nextDate,
				at: referenceDate
			)
			#expect(feedback.nextWindowText == nil)
			#expect(feedback.nextDoseDate == nextDate)
			#expect(feedback.tone == .warning)
			#expect(feedback.detail == assessment.detail)
		}
	}
	@Test("A next-day window includes the calendar date")
	func feedbackIncludesDateAcrossMidnight() {
		let med = medication()
		let dose = ANDoseConcept(amount: 2, unit: .tablet)
		let assessment = MedicationDoseGuidanceService().assessment(
			for: med, proposedDose: dose, at: referenceDate, events: [], profile: .empty
		)
		let nextDate = referenceDate.addingTimeInterval(24 * 3600)
		let feedback = QuickLogFeedbackService().feedback(
			medication: med, dose: dose, loggedEvent: event(medication: med),
			assessment: assessment, nextDoseDate: nextDate, at: referenceDate
		)
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .short
		#expect(feedback.nextWindowText == "Next dose window: \(formatter.string(from: nextDate))")
	}

}

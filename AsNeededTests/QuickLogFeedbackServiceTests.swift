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
			at: referenceDate
		)

		#expect(feedback.tone == .success)
		#expect(feedback.title == "Dose logged")
		#expect(feedback.message == "Logged 2 tab of Ibuprofen at 12:00 PM.")
		#expect(feedback.undoEventID != nil)
	}

	@Test("Feedback uses warning tone and next window for guardrail warnings")
	func feedbackUsesWarningToneAndNextWindowForGuardrailWarnings() {
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
			at: referenceDate
		)

		#expect(feedback.tone == .warning)
		#expect(feedback.title == "Logged - review saved guidance")
		#expect(feedback.detail.contains("minimum interval"))
		#expect(feedback.nextWindowText == "Next saved window 2:00 PM")
	}
}

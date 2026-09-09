import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("QuickLogFeedbackService Tests", .tags(.unit))
struct QuickLogFeedbackServiceTests {
	private let calendar = Calendar(identifier: .gregorian)

	private var referenceDate: Date {
		DateComponents(calendar: calendar, year: 2026, month: 6, day: 5, hour: 12).date ?? Date(timeIntervalSince1970: 1_780_685_200)
	}

	@Test("Feedback is a neutral success confirmation with undo identity")
	func feedbackIsNeutralSuccessConfirmationWithUndoIdentity() {
		let medication = ANMedicationConcept(
			clinicalName: "Ibuprofen",
			quantity: 20,
			prescribedUnit: .tablet,
			prescribedDoseAmount: 2
		)
		let dose = ANDoseConcept(amount: 2, unit: .tablet)
		let event = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: dose,
			date: referenceDate
		)

		let feedback = QuickLogFeedbackService().feedback(
			medication: medication,
			dose: dose,
			loggedEvent: event
		)

		#expect(feedback.title == "Dose logged")
		#expect(feedback.message == "Logged 2 tab of Ibuprofen at 12:00 PM.")
		#expect(feedback.detail == "Ibuprofen")
		#expect(feedback.undoEventID == event.id)

		let strings = [feedback.title, feedback.message, feedback.detail]
		let forbiddenClaims = ["caution", "warning", "guardrail", "guidance", "next window", "daily limit", "eligible"]
		for string in strings {
			for claim in forbiddenClaims {
				#expect(!string.localizedCaseInsensitiveContains(claim))
			}
		}
	}
}

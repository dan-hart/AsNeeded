import ANModelKit
import Foundation

struct QuickLogFeedbackService {
	struct Feedback: Equatable {
		let title: String
		let message: String
		let detail: String
		let undoEventID: UUID?
	}

	func feedback(
		medication: ANMedicationConcept,
		dose: ANDoseConcept,
		loggedEvent: ANEventConcept
	) -> Feedback {
		Feedback(
			title: "Dose logged",
			message: "Logged \(dose.amount.formattedAmount) \(dose.unit.abbreviation) of \(medication.displayName) at \(timeFormatter.string(from: loggedEvent.date)).",
			detail: medication.displayName,
			undoEventID: loggedEvent.id
		)
	}

	private var timeFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "h:mm a"
		return formatter
	}
}

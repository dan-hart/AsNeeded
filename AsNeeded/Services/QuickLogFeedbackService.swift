import ANModelKit
import Foundation

struct QuickLogFeedbackService {
	enum Tone: Equatable {
		case success
		case caution
		case warning
	}

	struct Feedback: Equatable {
		let tone: Tone
		let title: String
		let message: String
		let detail: String
		let nextWindowText: String?
		let undoEventID: UUID?
	}

	func feedback(
		medication: ANMedicationConcept,
		dose: ANDoseConcept,
		loggedEvent: ANEventConcept,
		assessment: MedicationDoseGuidanceService.Assessment,
		at date: Date = .now
	) -> Feedback {
		let tone = tone(for: assessment.severity)
		let title = title(for: tone)
		let message = "Logged \(dose.amount.formattedAmount) \(dose.unit.abbreviation) of \(medication.displayName) at \(timeFormatter.string(from: loggedEvent.date))."
		let nextWindowText = nextWindowText(from: assessment, at: date)

		return Feedback(
			tone: tone,
			title: title,
			message: message,
			detail: assessment.detail,
			nextWindowText: nextWindowText,
			undoEventID: loggedEvent.id
		)
	}

	private func tone(for severity: MedicationDoseGuidanceService.Severity) -> Tone {
		switch severity {
		case .clear:
			return .success
		case .caution:
			return .caution
		case .warning:
			return .warning
		}
	}

	private func title(for tone: Tone) -> String {
		switch tone {
		case .success:
			return "Dose logged"
		case .caution:
			return "Logged - close to guardrail"
		case .warning:
			return "Logged - review saved guidance"
		}
	}

	private func nextWindowText(
		from assessment: MedicationDoseGuidanceService.Assessment,
		at date: Date
	) -> String? {
		guard let nextEligibleDate = assessment.nextEligibleDate, nextEligibleDate > date else {
			return nil
		}

		return "Next saved window \(timeFormatter.string(from: nextEligibleDate))"
	}

	private var timeFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "h:mm a"
		return formatter
	}
}

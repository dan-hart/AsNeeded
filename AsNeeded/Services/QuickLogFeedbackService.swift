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
		let nextDoseDate: Date?
		let nextWindowText: String?
		let undoEventID: UUID?
	}

	func feedback(
		medication: ANMedicationConcept,
		dose: ANDoseConcept,
		loggedEvent: ANEventConcept,
		assessment: MedicationDoseGuidanceService.Assessment,
		nextDoseDate: Date?,
		at date: Date = .now
	) -> Feedback {
		let tone = tone(for: assessment.severity)
		let title = title(for: tone)
		let message = "Logged \(dose.amount.formattedAmount) \(dose.unit.abbreviation) of \(medication.displayName) at \(timeFormatter.string(from: loggedEvent.date))."
		let nextWindowText = nextWindowText(from: nextDoseDate, at: date)

		return Feedback(
			tone: tone,
			title: title,
			message: message,
			detail: assessment.detail,
			nextDoseDate: nextDoseDate,
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
			return "Dose logged. Check timing."
		case .warning:
			return "Dose logged. Review limits."
		}
	}

	private func nextWindowText(
		from nextDoseDate: Date?,
		at date: Date
	) -> String? {
		guard let nextDoseDate, nextDoseDate > date else {
			return nil
		}

		if Calendar.current.isDate(nextDoseDate, inSameDayAs: date) {
			return "Next dose window: \(timeFormatter.string(from: nextDoseDate))"
		}
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .short
		return "Next dose window: \(formatter.string(from: nextDoseDate))"
	}

	private var timeFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "h:mm a"
		return formatter
	}
}

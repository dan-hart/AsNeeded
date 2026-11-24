import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct LogDoseSessionTests {
	@Test("Dose preview follows amount, unit, and selected time")
	func dosePreview() {
		let locale = Locale(identifier: "en_US")
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		let now = Date(timeIntervalSince1970: 1_700_582_400)
		let draft = LogDoseView.Draft(
			medication: ANMedicationConcept(clinicalName: "Example", prescribedUnit: .milligram, prescribedDoseAmount: 1),
			at: now
		)

		#expect(draft.previewText(at: now, calendar: calendar, locale: locale) == "1 mg · now")

		draft.amount = 2
		draft.selectQuickTime(label: "15 min ago", secondsAgo: 900, at: now)
		#expect(draft.previewText(at: now, calendar: calendar, locale: locale) == "2 mg · 15 minutes ago")
		draft.selectDate(now.addingTimeInterval(-7_200))
		#expect(draft.previewText(at: now, calendar: calendar, locale: locale) == "2 mg · 2 hours ago")

		draft.amount = 1
		draft.selectedUnit = .bowl
		let yesterday = now.addingTimeInterval(-86_400)
		let yesterdayAtNoon = calendar.startOfDay(for: yesterday).addingTimeInterval(43_200)
		draft.selectDate(yesterdayAtNoon)
		#expect(draft.previewText(at: now, calendar: calendar, locale: locale) == "1 bowl · yesterday at noon")

		draft.selectDate(now.addingTimeInterval(60))
		#expect(draft.previewText(at: now, calendar: calendar, locale: locale)?.hasPrefix("1 bowl · today at ") == true)
	}

	@Test("Dose preview handles invalid and very small amounts")
	func dosePreviewAmountBounds() {
		let locale = Locale(identifier: "en_US")
		let now = Date(timeIntervalSince1970: 1_700_582_400)
		let draft = LogDoseView.Draft(
			medication: ANMedicationConcept(clinicalName: "Example", prescribedUnit: .milligram, prescribedDoseAmount: 0.001),
			at: now
		)

		#expect(draft.previewText(at: now, locale: locale) == "<0.01 mg · now")
		draft.amount = 0
		#expect(draft.previewText(at: now, locale: locale) == nil)
		draft.amount = .infinity
		#expect(draft.previewText(at: now, locale: locale) == nil)
	}

	@Test("A rehosted dose form retains inputs and its in-flight save guard")
	func retainedDoseDraft() {
		let medication = ANMedicationConcept(clinicalName: "Example", prescribedUnit: .tablet, prescribedDoseAmount: 0.5)
		let session = LogDoseView.Session()
		let draft = session.draft(for: medication)
		#expect(draft.amount == 0.5)
		#expect(draft.selectedUnit == .tablet)
		draft.amount = 1.5
		draft.reason = "Demo reason"
		draft.note = "Demo note"
		draft.selectedDate = Date(timeIntervalSince1970: 1_700_000_000)
		draft.symptomSeverityBefore = 3
		draft.symptomSeverityAfter = 2
		draft.effectiveness = 4
		draft.sideEffectsText = "Synthetic effect"
		draft.isLogging = true
		let rehosted = session.draft(for: medication)
		#expect(rehosted === draft)
		#expect(rehosted.amount == 1.5)
		#expect(rehosted.reason == "Demo reason")
		#expect(rehosted.note == "Demo note")
		#expect(rehosted.selectedDate == Date(timeIntervalSince1970: 1_700_000_000))
		#expect(rehosted.symptomSeverityBefore == 3)
		#expect(rehosted.symptomSeverityAfter == 2)
		#expect(rehosted.effectiveness == 4)
		#expect(rehosted.sideEffectsText == "Synthetic effect")
		#expect(rehosted.isLogging)
	}

	@Test("Finishing a dose form or choosing another medication starts fresh")
	func freshDoseDraft() {
		let first = ANMedicationConcept(clinicalName: "First example")
		let second = ANMedicationConcept(clinicalName: "Second example")
		let session = LogDoseView.Session()
		let previous = session.draft(for: first)
		previous.reason = "Previous reason"
		session.reset()
		let next = session.draft(for: first)
		#expect(next !== previous)
		#expect(next.reason.isEmpty)
		#expect(!next.isLogging)
		let different = session.draft(for: second)
		#expect(different !== next)
		#expect(different.note.isEmpty)
	}
}

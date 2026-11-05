import ANModelKit
import Foundation
import Testing
@testable import AsNeeded

@MainActor
@Suite("Backdated dose logging")
struct BackdatedDoseLoggingTests {
	private let now = Date(timeIntervalSince1970: 1_800_000_000)

	private func medication() -> ANMedicationConcept {
		var medication = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		medication.minimumHoursBetweenDoses = 4
		medication.maximumDailyDoseAmount = 2
		return medication
	}

	private func event(_ medication: ANMedicationConcept, hoursAgo: Double) -> ANEventConcept {
		ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 1, unit: .tablet), date: now.addingTimeInterval(-hoursAgo * 3600))
	}

	@Test("Leaving a Now form open does not turn it into historical logging")
	func nowRemainsCurrent() {
		let draft = LogDoseView.Draft(medication: medication(), at: now)
		let later = now.addingTimeInterval(600)
		#expect(!draft.isBackdated(at: later))
		#expect(draft.doseDate(at: later) == later)
		draft.toggleDatePicker(at: later)
		#expect(draft.selectedDate == later)
		#expect(!draft.isBackdated(at: later))
	}

	@Test("Quick times and custom dates carry explicit backdated intent")
	func explicitTimeSelection() {
		let draft = LogDoseView.Draft(medication: medication(), at: now)
		for option in LogDoseView.quickTimeSelections where option.secondsAgo > 0 {
			draft.selectQuickTime(label: option.label, secondsAgo: option.secondsAgo, at: now)
			#expect(draft.isBackdated(at: now))
			#expect(draft.doseDate(at: now) == now.addingTimeInterval(-option.secondsAgo))
		}
		draft.selectDate(now.addingTimeInterval(-60))
		draft.toggleDatePicker(at: now.addingTimeInterval(600))
		#expect(draft.selectedDate == now.addingTimeInterval(-60))
		#expect(draft.isBackdated(at: now))
		draft.selectQuickTime(label: "Now", secondsAgo: 0, at: now)
		#expect(!draft.isBackdated(at: now.addingTimeInterval(600)))
		draft.selectDate(now.addingTimeInterval(3600))
		#expect(!draft.isBackdated(at: now))
	}

	@Test("Historical warning becomes an ordinary confirmation with working Undo", arguments: [true, false])
	func historicalConfirmation(alreadySaved: Bool) async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let medication = medication()
		try await store.addMedication(medication)
		let prior = event(medication, hoursAgo: 49)
		let recent = event(medication, hoursAgo: 6)
		try await store.addEvent(prior)
		try await store.addEvent(recent)
		let historical = event(medication, hoursAgo: 48)
		let dose = try #require(historical.dose)
		let guidance = MedicationDoseGuidanceService()
		#expect(guidance.assessment(for: medication, proposedDose: dose, at: historical.date, events: store.events).severity == .warning)
		let before = guidance.availability(for: medication, at: now, events: store.events)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults, now: { now })
		if alreadySaved {
			try await store.recordDose(historical)
			model.presentDoseConfirmation(med: medication, dose: dose, event: historical, isBackdated: true)
		} else {
			#expect(await model.logDose(med: medication, dose: dose, event: historical, isBackdated: true))
		}
		let feedback = try #require(model.quickLogFeedback)
		#expect(feedback.tone == .success)
		#expect(feedback.title == "Dose logged")
		#expect(feedback.detail.isEmpty)
		#expect(feedback.nextDoseDate == nil)
		#expect(feedback.nextWindowText == nil)
		#expect(feedback.undoEventID == historical.id)
		#expect(store.events.first(where: { $0.id == historical.id })?.date == historical.date)
		#expect(store.medications.first?.quantity == 9)
		#expect(guidance.availability(for: medication, at: now, events: store.events) == before)
		#expect(await model.undoLastQuickLog(eventID: historical.id))
		#expect(!store.events.contains { $0.id == historical.id })
		#expect(store.medications.first?.quantity == 10)
	}

	@Test("Current regular and quick doses retain saved-guidance warnings", arguments: [true, false])
	func currentWarnings(quick: Bool) async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let medication = medication()
		try await store.addMedication(medication)
		try await store.addEvent(event(medication, hoursAgo: 1))
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults, now: { now })
		if quick { #expect(await model.quickLog(medication: medication)) }
		else {
			let dose = ANDoseConcept(amount: 1, unit: .tablet)
			let current = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose, date: now)
			#expect(await model.logDose(med: medication, dose: dose, event: current))
		}
		#expect(model.quickLogFeedback?.tone == .warning)
		#expect(model.quickLogFeedback?.nextDoseDate == now.addingTimeInterval(23 * 3600))
	}

	@Test("A historical flag cannot suppress current or future dose warnings", arguments: [0.0, -1.0])
	func historicalFlagRequiresPastDate(hoursAgo: Double) throws {
		let medication = medication()
		let logged = event(medication, hoursAgo: hoursAgo)
		let dose = try #require(logged.dose)
		let assessment = MedicationDoseGuidanceService().assessment(for: medication, proposedDose: dose, at: now, events: [event(medication, hoursAgo: 1)])
		let next = now.addingTimeInterval(4 * 3600)
		let feedback = QuickLogFeedbackService().feedback(medication: medication, dose: dose, loggedEvent: logged, assessment: assessment, nextDoseDate: next, at: now, isBackdated: true)
		#expect(feedback.tone == .warning)
		#expect(feedback.detail == assessment.detail)
		#expect(feedback.nextDoseDate == next)
	}

	@Test("Recent backlog uses its dose timestamp, not the time it was entered")
	func recentBacklogStillCountsAtActualTime() {
		let medication = medication()
		let guidance = MedicationDoseGuidanceService()
		let backlogged = event(medication, hoursAgo: 1)
		#expect(guidance.availability(for: medication, at: now, events: [backlogged]) == .eligible(now.addingTimeInterval(3 * 3600)))
		var quantityMedication = medication
		quantityMedication.maximumDailyDoseAmount = 1
		let old = event(quantityMedication, hoursAgo: 25)
		let recent = event(quantityMedication, hoursAgo: 2)
		#expect(guidance.availability(for: quantityMedication, at: now, events: [old, recent]) == .eligible(now.addingTimeInterval(22 * 3600)))
	}
}

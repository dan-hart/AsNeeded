import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Dose confirmations")
struct DoseConfirmationTests {
	private final class Clock {
		var durations: [Duration] = []
		private var pending: [Int: CheckedContinuation<Void, Never>] = [:]
		private var waiter: (Int, CheckedContinuation<Void, Never>)?
		func sleep(_ duration: Duration) async {
			await withCheckedContinuation { continuation in
				pending[durations.count] = continuation
				durations.append(duration)
				if let (count, continuation) = waiter, durations.count >= count {
					waiter = nil
					continuation.resume()
				}
			}
		}
		func wait(for count: Int) async {
			if durations.count >= count { return }
			await withCheckedContinuation { waiter = (count, $0) }
		}
		func advance(_ index: Int) { pending.removeValue(forKey: index)?.resume() }
	}

	@Test("Regular and quick doses both confirm with the exact Undo event", arguments: [true, false])
	func undoEveryEntryPath(_ quick: Bool) async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		try await store.addMedication(med)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults)
		if quick {
			#expect(await model.quickLog(medication: med))
		} else {
			let dose = ANDoseConcept(amount: 2, unit: .tablet)
			let event = ANEventConcept(eventType: .doseTaken, medication: med, dose: dose)
			#expect(await model.logDose(med: med, dose: dose, event: event))
		}
		#expect(model.showQuickLogToast)
		#expect(store.events.count == 1)
		let id = try #require(model.quickLogFeedback?.undoEventID)
		#expect(store.events.first?.id == id)
		#expect(store.medications.first?.quantity == 8)
		#expect(await model.undoLastQuickLog(eventID: id))
		#expect(store.events.isEmpty)
		#expect(store.medications.first?.quantity == 10)
	}

	@Test("Detail confirmation never writes the already saved dose twice")
	func alreadyPersistedDose() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet)
		try await store.addMedication(med)
		let dose = ANDoseConcept(amount: 1, unit: .tablet)
		let event = ANEventConcept(eventType: .doseTaken, medication: med, dose: dose)
		try await store.recordDose(event)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults)
		model.presentDoseConfirmation(med: med, dose: dose, event: event)
		#expect(store.events.count == 1)
		#expect(store.medications.first?.quantity == 9)
		#expect(model.quickLogFeedback?.undoEventID == event.id)
		model.dismissQuickLogToast()
		#expect(await model.undoLastQuickLog(eventID: event.id))
		#expect(store.medications.first?.quantity == 10)
	}

	@Test("Four-second expiry clears the toast without undoing the dose")
	func autoDismiss() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet)
		try await store.addMedication(med)
		let clock = Clock()
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults, confirmationSleep: { await clock.sleep($0) })
		#expect(await model.quickLog(medication: med))
		await clock.wait(for: 1)
		#expect(clock.durations == [.seconds(4)])
		#expect(model.showQuickLogToast)
		let dismissal = model.confirmationDismissTask
		clock.advance(0)
		await dismissal?.value
		#expect(!model.showQuickLogToast)
		#expect(model.quickLogFeedback == nil)
		#expect(store.events.count == 1)
	}

	@Test("An older timer cannot dismiss the newer dose confirmation")
	func replacementTimer() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let med = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet)
		try await store.addMedication(med)
		let clock = Clock()
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults, confirmationSleep: { await clock.sleep($0) })
		#expect(await model.quickLog(medication: med))
		await clock.wait(for: 1)
		let previousDismissal = model.confirmationDismissTask
		#expect(await model.quickLog(medication: med))
		await clock.wait(for: 2)
		let latestID = model.quickLogFeedback?.undoEventID
		clock.advance(0)
		await previousDismissal?.value
		#expect(model.showQuickLogToast)
		#expect(model.quickLogFeedback?.undoEventID == latestID)
		let dismissal = model.confirmationDismissTask
		clock.advance(1)
		await dismissal?.value
		#expect(!model.showQuickLogToast)
	}
}

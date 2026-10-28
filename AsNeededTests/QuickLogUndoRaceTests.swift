import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Quick log Undo races")
struct QuickLogUndoRaceTests {
	private final class Gate {
		private var entered = false
		private var entryWaiter: CheckedContinuation<Void, Never>?
		private var releaseWaiter: CheckedContinuation<Void, Never>?
		func pause() async {
			await withCheckedContinuation { continuation in
				releaseWaiter = continuation
				entered = true
				entryWaiter?.resume()
				entryWaiter = nil
			}
		}
		func wait() async {
			if entered { return }
			await withCheckedContinuation { entryWaiter = $0 }
		}
		func release() { releaseWaiter?.resume(); releaseWaiter = nil }
	}

	@Test("An older Undo cannot clear a newer toast or alter its dose stock")
	func replacementToastSurvivesUndo() async throws {
		let store = DataStore(testIdentifier: UUID().uuidString)
		let first = ANMedicationConcept(clinicalName: "Synthetic A", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		let second = ANMedicationConcept(clinicalName: "Synthetic B", quantity: 8, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		try await store.addMedication(first)
		try await store.addMedication(second)
		let gate = Gate()
		let model = MedicationListViewModel(dataStore: store, undoPersistence: { id in
			await gate.pause()
			try await store.deleteEvents(ids: [id])
		})
		#expect(await model.quickLog(medication: first))
		let oldUndo = Task { await model.undoLastQuickLog() }
		await gate.wait()
		#expect(await model.quickLog(medication: second))
		let replacementID = model.quickLogFeedback?.undoEventID
		gate.release()
		#expect(await oldUndo.value)
		#expect(model.showQuickLogToast)
		#expect(model.quickLogFeedback?.undoEventID == replacementID)
		#expect(store.medications.first { $0.id == first.id }?.quantity == 10)
		#expect(store.medications.first { $0.id == second.id }?.quantity == 6)
		#expect(store.events.count == 1)
	}

	@Test("A repeated Undo tap does not start another write for the same dose")
	func repeatUndoDoesNotOverlap() async throws {
		let store = DataStore(testIdentifier: UUID().uuidString)
		let medication = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		try await store.addMedication(medication)
		let gate = Gate()
		var attempts = 0
		let model = MedicationListViewModel(dataStore: store, undoPersistence: { id in
			attempts += 1
			if attempts == 1 { await gate.pause() }
			try await store.deleteEvents(ids: [id])
		})
		#expect(await model.quickLog(medication: medication))
		let firstUndo = Task { await model.undoLastQuickLog() }
		await gate.wait()
		#expect(await model.undoLastQuickLog() == false)
		#expect(attempts == 1)
		gate.release()
		#expect(await firstUndo.value)
		#expect(store.medications.first?.quantity == 10)
		#expect(store.events.isEmpty)
	}

	@Test("An older reminder acknowledgement cannot replace a newer dose confirmation")
	func lateAcknowledgementDoesNotReplaceNewerToast() async throws {
		let first = ANMedicationConcept(clinicalName: "Synthetic A", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		let second = ANMedicationConcept(clinicalName: "Synthetic B", quantity: 8, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		let gate = Gate()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), reminderAcknowledgement: { id in
			if id == first.id { await gate.pause() }
		})
		try await store.addMedication(first)
		try await store.addMedication(second)
		let model = MedicationListViewModel(dataStore: store)
		let older = Task { await model.quickLog(medication: first) }
		await gate.wait()
		#expect(await model.quickLog(medication: second))
		let newestID = model.quickLogFeedback?.undoEventID
		gate.release()
		#expect(await older.value)
		#expect(model.quickLogFeedback?.undoEventID == newestID)
		#expect(model.quickLogMedicationName == second.displayName)
		#expect(await model.undoLastQuickLog())
		#expect(store.medications.first { $0.id == first.id }?.quantity == 9)
		#expect(store.medications.first { $0.id == second.id }?.quantity == 8)
	}

	@Test("Failed Undo retains its confirmation and can be retried")
	func failedUndoCanRetry() async throws {
		enum Failure: Error { case injected }
		let store = DataStore(testIdentifier: UUID().uuidString)
		let medication = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		try await store.addMedication(medication)
		var attempts = 0
		let model = MedicationListViewModel(dataStore: store, undoPersistence: { id in
			attempts += 1
			if attempts == 1 { throw Failure.injected }
			try await store.deleteEvents(ids: [id])
		})
		#expect(await model.quickLog(medication: medication))
		#expect(await model.undoLastQuickLog() == false)
		#expect(model.showQuickLogToast)
		#expect(await model.undoLastQuickLog())
		#expect(!model.showQuickLogToast)
		#expect(store.medications.first?.quantity == 10)
	}
}

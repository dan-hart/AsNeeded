import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Committed data observation")
struct CommittedSnapshotTests {
	@Test("Observers see dose history and stock from the same completed transaction")
	func consistentDoseSnapshot() async throws {
		let store = DataStore(testIdentifier: UUID().uuidString)
		var iterator = store.committedSnapshots().makeAsyncIterator()
		let medication = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		try await store.addMedication(medication)
		let initial = try #require(await iterator.next())
		#expect(initial.medications.first?.quantity == 10)
		#expect(initial.events.isEmpty)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 1, unit: .tablet), date: Date())
		try await store.recordDose(event, shouldRecordForReview: false)
		let saved = try #require(await iterator.next())
		#expect(saved.events.map(\.id) == [event.id])
		#expect(saved.medications.first?.quantity == 9)
		#expect(store.medications == saved.medications)
		#expect(store.events == saved.events)
	}

	@Test("Failed saves publish the recovered state rather than partial record changes")
	func rollbackPublishesRecoveredSnapshot() async throws {
		enum Failure: Error { case injected }
		var shouldFail = false
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let store = DataStore(storageDirectory: directory, transactionFault: { phase in
			if shouldFail && phase == .beforeCommit { throw Failure.injected }
		})
		var iterator = store.committedSnapshots().makeAsyncIterator()
		let medication = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		try await store.addMedication(medication)
		_ = await iterator.next()
		shouldFail = true
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 1, unit: .tablet), date: Date())
		do {
			try await store.recordDose(event, shouldRecordForReview: false)
			Issue.record("Injected save unexpectedly succeeded")
		} catch { }
		let recovered = try #require(await iterator.next())
		#expect(recovered.events.isEmpty)
		#expect(recovered.medications.first?.quantity == 10)
		#expect(store.events == recovered.events)
		#expect(store.medications == recovered.medications)
	}
}

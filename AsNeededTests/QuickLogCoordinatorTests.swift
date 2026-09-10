// QuickLogCoordinatorTests.swift
// Unit tests for the shared quick-log core: compensating writes, undo, toast state, and review recording.

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("QuickLogCoordinator Tests", .tags(.medication, .unit), .serialized)
struct QuickLogCoordinatorTests {
	// MARK: - Test Doubles
	@MainActor
	private final class TestToastScheduler {
		private(set) var actions: [@MainActor @Sendable () -> Void] = []

		func schedule(_ action: @escaping @MainActor @Sendable () -> Void) {
			actions.append(action)
		}

		func fireAll() {
			let pending = actions
			actions.removeAll()
			pending.forEach { $0() }
		}
	}

	@MainActor
	private final class DeliveredReminderAcknowledgementRecorder {
		private(set) var medicationIDs: [UUID] = []

		func acknowledge(_ medicationID: UUID) async {
			medicationIDs.append(medicationID)
		}
	}

	@MainActor
	private final class ReviewRecorder {
		private(set) var recordedEventCount = 0

		func record() {
			recordedEventCount += 1
		}
	}

	private struct TestPersistenceError: Error {}

	// MARK: - Helpers
	private func makeDataStore(_ suffix: String) async throws -> DataStore {
		let dataStore = DataStore(testIdentifier: "QuickLogCoordinatorTests-\(suffix)")
		try await dataStore.clearAllData()
		return dataStore
	}

	private func makeMedication(name: String, quantity: Double? = 20.0) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: name,
			quantity: quantity,
			initialQuantity: 30.0,
			prescribedUnit: .milligram,
			prescribedDoseAmount: 10.0
		)
	}

	// MARK: - Quick Log
	@Test("Quick log success decrements quantity, acknowledges reminders, and shows the toast")
	func quickLogSuccessShowsToast() async throws {
		let dataStore = try await makeDataStore("QuickLogSuccess")
		let medication = makeMedication(name: "Quick Log Med")
		try await dataStore.addMedication(medication)
		let toastScheduler = TestToastScheduler()
		let acknowledgementRecorder = DeliveredReminderAcknowledgementRecorder()
		let reviewRecorder = ReviewRecorder()
		let coordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: toastScheduler.schedule,
			acknowledgeDeliveredReminders: acknowledgementRecorder.acknowledge,
			recordEventForReview: reviewRecorder.record
		)

		let success = await coordinator.quickLog(medication: medication, source: "test_quick_log")

		#expect(success)
		#expect(dataStore.events.count == 1)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 10.0)
		#expect(acknowledgementRecorder.medicationIDs == [medication.id])
		#expect(reviewRecorder.recordedEventCount == 0, "Quick logs do not count toward review eligibility")
		#expect(coordinator.showQuickLogToast)
		#expect(coordinator.quickLogMedicationName == medication.displayName)
		#expect(coordinator.quickLogDoseAmount == 10.0)
		#expect(coordinator.quickLogDoseUnit == ANUnitConcept.milligram.abbreviation)
		#expect(coordinator.quickLogFeedback?.undoEventID == dataStore.events.first?.id)
		#expect(coordinator.quickLogToastGeneration != nil)
		#expect(toastScheduler.actions.count == 1)

		toastScheduler.fireAll()

		#expect(coordinator.showQuickLogToast == false)
		#expect(coordinator.quickLogToastGeneration == nil)
		#expect(coordinator.quickLogFeedback == nil)
	}

	@Test("Quick log restores quantity and shows no toast when the event write fails")
	func quickLogRestoresQuantityWhenEventWriteFails() async throws {
		let dataStore = try await makeDataStore("QuickLogEventFailure")
		let medication = makeMedication(name: "Rollback Med")
		try await dataStore.addMedication(medication)
		var writes = QuickLogWrites.live(dataStore: dataStore)
		writes.addEvent = { _ in throw TestPersistenceError() }
		let toastScheduler = TestToastScheduler()
		let acknowledgementRecorder = DeliveredReminderAcknowledgementRecorder()
		let coordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: toastScheduler.schedule,
			persistence: QuickLogCoordinator.makeQuickLogPersistence(writes: writes),
			acknowledgeDeliveredReminders: acknowledgementRecorder.acknowledge
		)

		let success = await coordinator.quickLog(medication: medication)

		#expect(success == false)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 20.0)
		#expect(acknowledgementRecorder.medicationIDs.isEmpty)
		#expect(coordinator.showQuickLogToast == false)
		#expect(coordinator.quickLogFeedback == nil)
		#expect(toastScheduler.actions.isEmpty)
	}

	@Test("Quick log skips the event write when the medication update fails")
	func quickLogSkipsEventWriteWhenMedicationUpdateFails() async throws {
		let dataStore = try await makeDataStore("QuickLogUpdateFailure")
		let medication = makeMedication(name: "Update Failure Med")
		try await dataStore.addMedication(medication)
		var writes = QuickLogWrites.live(dataStore: dataStore)
		writes.updateMedication = { _ in throw TestPersistenceError() }
		let coordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: TestToastScheduler().schedule,
			persistence: QuickLogCoordinator.makeQuickLogPersistence(writes: writes),
			acknowledgeDeliveredReminders: { _ in }
		)

		let success = await coordinator.quickLog(medication: medication)

		#expect(success == false)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 20.0)
		#expect(coordinator.showQuickLogToast == false)
	}

	// MARK: - Undo
	@Test("Undo removes the event, restores the quantity, and dismisses the toast")
	func undoRestoresEventAndQuantity() async throws {
		let dataStore = try await makeDataStore("UndoSuccess")
		let medication = makeMedication(name: "Undo Med")
		try await dataStore.addMedication(medication)
		let coordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: TestToastScheduler().schedule,
			acknowledgeDeliveredReminders: { _ in }
		)
		#expect(await coordinator.quickLog(medication: medication))
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 10.0)

		let undoSuccess = await coordinator.undoLastQuickLog()

		#expect(undoSuccess)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 20.0)
		#expect(coordinator.showQuickLogToast == false)
		#expect(coordinator.quickLogFeedback == nil)
		#expect(await coordinator.undoLastQuickLog() == false, "Nothing left to undo")
	}

	@Test("Undo after a clamped quick log restores only what was removed")
	func undoAfterClampRestoresRemovedAmount() async throws {
		let dataStore = try await makeDataStore("UndoClamped-\(UUID().uuidString)")
		// Dose is 10 but only 3 remain, so the log clamps to 0 and removes 3.
		let medication = makeMedication(name: "Clamp Med", quantity: 3.0)
		try await dataStore.addMedication(medication)
		let coordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: TestToastScheduler().schedule,
			acknowledgeDeliveredReminders: { _ in }
		)
		#expect(await coordinator.quickLog(medication: medication))
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 0.0)

		#expect(await coordinator.undoLastQuickLog())

		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 3.0, "Undo must not inflate past the pre-log quantity")
	}

	@Test("Undo re-adds the event when the medication restore fails")
	func undoReAddsEventWhenRestoreFails() async throws {
		let dataStore = try await makeDataStore("UndoRestoreFailure")
		let medication = makeMedication(name: "Undo Rollback Med")
		try await dataStore.addMedication(medication)
		var writes = QuickLogWrites.live(dataStore: dataStore)
		writes.updateMedication = { _ in throw TestPersistenceError() }
		let coordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: TestToastScheduler().schedule,
			undoPersistence: QuickLogCoordinator.makeQuickLogUndoPersistence(writes: writes),
			acknowledgeDeliveredReminders: { _ in }
		)
		#expect(await coordinator.quickLog(medication: medication))
		#expect(dataStore.events.count == 1)
		let loggedEventID = dataStore.events.first?.id
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 10.0)

		let undoSuccess = await coordinator.undoLastQuickLog()

		#expect(undoSuccess == false)
		#expect(dataStore.events.count == 1)
		#expect(dataStore.events.first?.id == loggedEventID)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 10.0)
		#expect(coordinator.quickLogFeedback?.undoEventID == loggedEventID)
		#expect(coordinator.showQuickLogToast, "Toast stays so the user can retry the undo")
	}

	// MARK: - Sheet Log
	@Test("Sheet log clamps quantity at zero and records the event for review")
	func logDoseClampsQuantityAndRecordsReview() async throws {
		let dataStore = try await makeDataStore("LogDoseSuccess")
		let medication = makeMedication(name: "Sheet Med", quantity: 3.0)
		try await dataStore.addMedication(medication)
		let reviewRecorder = ReviewRecorder()
		let coordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: TestToastScheduler().schedule,
			acknowledgeDeliveredReminders: { _ in },
			recordEventForReview: reviewRecorder.record
		)
		let dose = ANDoseConcept(amount: 5.0, unit: .milligram)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose, date: Date())

		let success = await coordinator.logDose(
			medication: medication,
			dose: dose,
			event: event,
			source: "test_sheet"
		)

		#expect(success)
		#expect(dataStore.events.count == 1)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 0.0)
		#expect(reviewRecorder.recordedEventCount == 1)
		#expect(coordinator.showQuickLogToast == false, "Callers decide which confirmation to show")
	}

	@Test("Sheet log rolls back the quantity and skips review recording when the event write fails")
	func logDoseRollsBackOnEventFailure() async throws {
		let dataStore = try await makeDataStore("LogDoseEventFailure")
		let medication = makeMedication(name: "Sheet Rollback Med")
		try await dataStore.addMedication(medication)
		var writes = QuickLogWrites.live(dataStore: dataStore)
		writes.addEvent = { _ in throw TestPersistenceError() }
		let reviewRecorder = ReviewRecorder()
		let coordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: TestToastScheduler().schedule,
			persistence: QuickLogCoordinator.makeQuickLogPersistence(writes: writes),
			acknowledgeDeliveredReminders: { _ in },
			recordEventForReview: reviewRecorder.record
		)
		let dose = ANDoseConcept(amount: 5.0, unit: .milligram)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose, date: Date())

		let success = await coordinator.logDose(
			medication: medication,
			dose: dose,
			event: event,
			source: "test_sheet"
		)

		#expect(success == false)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 20.0)
		#expect(reviewRecorder.recordedEventCount == 0)
	}

	// MARK: - Toast Generations
	@Test("Replacement toast ignores the previous toast's auto-dismissal")
	func replacementToastIgnoresStaleAutoDismissal() async throws {
		let dataStore = try await makeDataStore("ToastGenerations")
		let firstMedication = makeMedication(name: "First")
		let secondMedication = makeMedication(name: "Second")
		try await dataStore.addMedication(firstMedication)
		try await dataStore.addMedication(secondMedication)
		let toastScheduler = TestToastScheduler()
		let coordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: toastScheduler.schedule,
			acknowledgeDeliveredReminders: { _ in }
		)

		#expect(await coordinator.quickLog(medication: firstMedication))
		#expect(await coordinator.quickLog(medication: secondMedication))
		let secondGeneration = coordinator.quickLogToastGeneration
		#expect(toastScheduler.actions.count == 2)

		toastScheduler.actions.first?()

		#expect(coordinator.showQuickLogToast)
		#expect(coordinator.quickLogMedicationName == "Second")
		#expect(coordinator.quickLogToastGeneration == secondGeneration)

		toastScheduler.actions.last?()

		#expect(coordinator.showQuickLogToast == false)
		#expect(coordinator.quickLogToastGeneration == nil)
	}
}

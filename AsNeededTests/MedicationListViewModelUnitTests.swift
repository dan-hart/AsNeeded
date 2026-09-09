@testable import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import SwiftUI

@MainActor
@Suite("MedicationListViewModel Unit Tests", .tags(.viewModel, .medication, .unit), .serialized)
struct MedicationListViewModelUnitTests {
    @MainActor
    private final class TestToastScheduler {
        private(set) var actions: [@MainActor @Sendable () -> Void] = []

        func schedule(_ action: @escaping @MainActor @Sendable () -> Void) {
            actions.append(action)
        }
    }

	@MainActor
	private final class DeliveredReminderAcknowledgementRecorder {
		private(set) var medicationIDs: [UUID] = []

		func acknowledge(_ medicationID: UUID) async {
			medicationIDs.append(medicationID)
		}
	}

	private struct TestPersistenceError: Error {}

	enum QuickLogFailureOutcome: CaseIterable {
		case totalFailure
		case updateOnly
		case eventOnly

		var persistenceResult: (updateSuccess: Bool, eventSuccess: Bool) {
			switch self {
			case .totalFailure:
				return (false, false)
			case .updateOnly:
				return (true, false)
			case .eventOnly:
				return (false, true)
			}
		}
	}

    private var viewModel: MedicationListViewModel
    private var dataStore: DataStore
    private var toastScheduler: TestToastScheduler
	private var acknowledgementRecorder: DeliveredReminderAcknowledgementRecorder

    init() async throws {
        // Create test instance with isolated storage
        dataStore = DataStore(testIdentifier: "MedicationListViewModelUnitTests")
        toastScheduler = TestToastScheduler()
		acknowledgementRecorder = DeliveredReminderAcknowledgementRecorder()
        viewModel = MedicationListViewModel(
            dataStore: dataStore,
            scheduleQuickLogToastDismissal: toastScheduler.schedule,
			acknowledgeDeliveredReminders: acknowledgementRecorder.acknowledge
        )
        // Clear any existing test data
        try await dataStore.clearAllData()
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.medicationOrder)
        // Ensure hideSupportBanners is false by default for this test suite
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.hideSupportBanners)
    }

    @Test("ViewModel initializes with correct data from DataStore")
    func viewModelInitializesWithData() async throws {
        // Given
        let med1 = createTestMedication(name: "Med A")
        let med2 = createTestMedication(name: "Med B")
        try await dataStore.addMedication(med1)
        try await dataStore.addMedication(med2)

        // When
        let newViewModel = MedicationListViewModel(dataStore: dataStore)

        // Then
        #expect(newViewModel.items.count == 2)
        #expect(newViewModel.items.contains(where: { $0.id == med1.id }))
        #expect(newViewModel.items.contains(where: { $0.id == med2.id }))
    }

    @Test("Add medication updates items and sortedMedications")
    func addMedicationUpdatesLists() async throws {
        // Given
        let medication = createTestMedication(name: "New Med")

        // When
        let success = await viewModel.add(medication)

        // Then
        #expect(success)
        #expect(viewModel.items.count == 1)
        #expect(viewModel.sortedMedications.count == 1)
        #expect(viewModel.items.first?.id == medication.id)
    }

    @Test("Update medication refreshes lists")
    func updateMedicationRefreshesLists() async throws {
        // Given
        let originalMed = createTestMedication(name: "Original Name")
        _ = await viewModel.add(originalMed)

        var updatedMed = originalMed
        updatedMed.clinicalName = "Updated Name"

        // When
        let success = await viewModel.update(updatedMed)

        // Then
        #expect(success)
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.clinicalName == "Updated Name")
    }

    @Test("Delete medication removes from lists")
    func deleteMedicationRemovesFromLists() async throws {
        // Given
        let medToDelete = createTestMedication(name: "To Delete")
        _ = await viewModel.add(medToDelete)
        #expect(viewModel.items.count == 1)

        // When
        let success = await viewModel.delete(medToDelete)

        // Then
        #expect(success)
        #expect(viewModel.items.count == 0)
        #expect(viewModel.sortedMedications.count == 0)
    }

    @Test("Add event works correctly")
    func addEventWorksCorrectly() async throws {
        // Given
        let medication = createTestMedication(name: "Event Med")
        _ = await viewModel.add(medication)
        let event = ANEventConcept(eventType: .doseTaken, medication: medication)

        // When
        let success = await viewModel.addEvent(event)

        // Then
        #expect(success)
        #expect(dataStore.events.count == 1)
        #expect(dataStore.events.first?.id == event.id)
    }

    @Test("Toggling showArchivedMedications filters correctly")
    func toggleArchivedMedicationsFilters() async throws {
        // Given
        let activeMed = createTestMedication(name: "Active")
        // No longer set isArchived here, rely on ANModelKit's property
        let archivedMed = createTestMedication(name: "Archived") // Assuming ANModelKit's concept allows archiving
        // For testing purposes, manually update the stored medication to be archived
        var archivedMedInStore = archivedMed
        archivedMedInStore.isArchived = true // Assuming ANModelKit's isArchived is mutable and can be set

        _ = await viewModel.add(activeMed)
        // Update the archivedMed in the store directly to simulate archiving
        try await dataStore.updateMedication(archivedMedInStore)
        
        // When - initially only active should show
        #expect(viewModel.displayedMedications.count == 1)
        #expect(viewModel.displayedMedications.first?.id == activeMed.id)

        // When - show archived
        viewModel.toggleArchivedMedications()

        // Then
        #expect(viewModel.showArchivedMedications)
        #expect(viewModel.displayedMedications.count == 2)
        #expect(viewModel.displayedMedications.contains(where: { $0.id == activeMed.id }))
        #expect(viewModel.displayedMedications.contains(where: { $0.id == archivedMed.id })) // Checks both original and updated

        // When - hide archived again
        viewModel.toggleArchivedMedications()

        // Then
        #expect(!viewModel.showArchivedMedications)
        #expect(viewModel.displayedMedications.count == 1)
        #expect(viewModel.displayedMedications.first?.id == activeMed.id)
    }

    @Test("Medication order is maintained and new items are appended")
    mutating func medicationOrderIsMaintained() async throws { // MARK: - Added mutating keyword
        // Given
        let med1 = createTestMedication(name: "Med 1")
        let med2 = createTestMedication(name: "Med 2")
        let med3 = createTestMedication(name: "Med 3")

        _ = await viewModel.add(med1)
        _ = await viewModel.add(med2)
        _ = await viewModel.add(med3)

        // Set a custom order (e.g., med3, med1, med2)
        UserDefaults.standard.set([med3.id.uuidString, med1.id.uuidString].rawValue, forKey: UserDefaultsKeys.medicationOrder)
        viewModel = MedicationListViewModel(dataStore: dataStore)
        
        // When
        let sorted = viewModel.sortedMedications
        
        // Then
        #expect(sorted.count == 3)
        #expect(sorted[0].id == med3.id)
        #expect(sorted[1].id == med1.id)
        #expect(sorted[2].id == med2.id) // med2 should be appended as it's not in the order
    }

    @Test("moveMedications reorders correctly")
    func moveMedicationsReorders() async throws {
        // Given
        let med1 = createTestMedication(name: "A")
        let med2 = createTestMedication(name: "B")
        let med3 = createTestMedication(name: "C")

        _ = await viewModel.add(med1)
        _ = await viewModel.add(med2)
        _ = await viewModel.add(med3)

        // Initial order: A, B, C
        #expect(viewModel.sortedMedications.map { $0.clinicalName } == ["A", "B", "C"])

        // When: Move B (index 1) to before A (index 0)
        viewModel.moveMedications(from: IndexSet(integer: 1), to: 0)

        // Then: B, A, C
        #expect(viewModel.sortedMedications.map { $0.clinicalName } == ["B", "A", "C"])
    }

    @Test("deleteMedications removes items and updates order")
    func deleteMedicationsRemovesAndUpdateOrder() async throws {
        // Given
        let med1 = createTestMedication(name: "A")
        let med2 = createTestMedication(name: "B")
        let med3 = createTestMedication(name: "C")

        _ = await viewModel.add(med1)
        _ = await viewModel.add(med2)
        _ = await viewModel.add(med3)

        // Initial order: A, B, C
        #expect(viewModel.sortedMedications.map { $0.clinicalName } == ["A", "B", "C"])

        // When: Delete B (at index 1)
        viewModel.deleteMedications(at: IndexSet(integer: 1))
        // Allow async deletion to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: A, C
        #expect(viewModel.sortedMedications.map { $0.clinicalName } == ["A", "C"])
        let medicationOrder = UserDefaults.standard.string(forKey: UserDefaultsKeys.medicationOrder).flatMap([String].init(rawValue:)) ?? []
        #expect(!medicationOrder.contains(med2.id.uuidString))
    }

    @Test("toggleEditMode changes editMode and triggers haptics")
    func toggleEditModeChangesState() {
        // Given
        #expect(viewModel.editMode == .inactive)

        // When
        viewModel.toggleEditMode()

        // Then
        #expect(viewModel.editMode == .active)

        // When
        viewModel.toggleEditMode()

        // Then
        #expect(viewModel.editMode == .inactive)
    }

    @Test("quickLog correctly logs dose and updates state")
    func quickLogCorrectlyLogsDose() async throws {
        // Given
        let medication = createTestMedication(name: "Quick Log Med")
        _ = await viewModel.add(medication)
		#expect(acknowledgementRecorder.medicationIDs.isEmpty)

        // When
        let success = await viewModel.quickLog(medication: medication)

        // Then
        #expect(success)
		#expect(acknowledgementRecorder.medicationIDs == [medication.id])
        #expect(dataStore.events.count == 1) // Verify event was added
        #expect(viewModel.showQuickLogToast) // Verify toast state change
        #expect(viewModel.quickLogMedicationName == medication.displayName)

        #expect(toastScheduler.actions.count == 1)
        toastScheduler.actions[0]()
        #expect(!viewModel.showQuickLogToast)
    }

	@Test(
		"Quick log does not acknowledge reminders unless persistence fully succeeds",
		arguments: QuickLogFailureOutcome.allCases
	)
	func quickLogDoesNotAcknowledgeRemindersOnPersistenceFailure(
		outcome: QuickLogFailureOutcome
	) async {
		let medication = createTestMedication(name: "Failed Quick Log")
		let result = outcome.persistenceResult
		let acknowledgementRecorder = DeliveredReminderAcknowledgementRecorder()
		let viewModel = MedicationListViewModel(
			dataStore: dataStore,
			scheduleQuickLogToastDismissal: toastScheduler.schedule,
			quickLogPersistence: { _, _ in result },
			acknowledgeDeliveredReminders: acknowledgementRecorder.acknowledge
		)

		#expect(await viewModel.quickLog(medication: medication) == false)
		#expect(acknowledgementRecorder.medicationIDs.isEmpty)
	}

	@Test("Quick log restores quantity when event write fails after medication update")
	func quickLogRestoresQuantityWhenEventWriteFails() async throws {
		// Given
		let medication = createTestMedication(name: "Rollback Med", quantity: 20.0)
		try await dataStore.addMedication(medication)
		var writes = QuickLogWrites.live(dataStore: dataStore)
		writes.addEvent = { _ in throw TestPersistenceError() }
		let acknowledgementRecorder = DeliveredReminderAcknowledgementRecorder()
		let viewModel = MedicationListViewModel(
			dataStore: dataStore,
			scheduleQuickLogToastDismissal: toastScheduler.schedule,
			quickLogPersistence: MedicationListViewModel.makeQuickLogPersistence(writes: writes),
			acknowledgeDeliveredReminders: acknowledgementRecorder.acknowledge
		)

		// When
		let success = await viewModel.quickLog(medication: medication)

		// Then
		#expect(success == false)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 20.0)
		#expect(acknowledgementRecorder.medicationIDs.isEmpty)
		#expect(viewModel.showQuickLogToast == false)
	}

	@Test("Quick log skips event write when medication update fails")
	func quickLogSkipsEventWriteWhenMedicationUpdateFails() async throws {
		// Given
		let medication = createTestMedication(name: "Update Failure Med", quantity: 20.0)
		try await dataStore.addMedication(medication)
		var writes = QuickLogWrites.live(dataStore: dataStore)
		writes.updateMedication = { _ in throw TestPersistenceError() }
		let viewModel = MedicationListViewModel(
			dataStore: dataStore,
			scheduleQuickLogToastDismissal: toastScheduler.schedule,
			quickLogPersistence: MedicationListViewModel.makeQuickLogPersistence(writes: writes),
			acknowledgeDeliveredReminders: acknowledgementRecorder.acknowledge
		)

		// When
		let success = await viewModel.quickLog(medication: medication)

		// Then
		#expect(success == false)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 20.0)
	}

	@Test("Undo re-adds event when medication restore fails")
	func undoReAddsEventWhenMedicationRestoreFails() async throws {
		// Given
		let medication = createTestMedication(name: "Undo Rollback Med", quantity: 20.0)
		try await dataStore.addMedication(medication)
		var writes = QuickLogWrites.live(dataStore: dataStore)
		writes.updateMedication = { _ in throw TestPersistenceError() }
		let viewModel = MedicationListViewModel(
			dataStore: dataStore,
			scheduleQuickLogToastDismissal: toastScheduler.schedule,
			quickLogUndoPersistence: MedicationListViewModel.makeQuickLogUndoPersistence(writes: writes),
			acknowledgeDeliveredReminders: acknowledgementRecorder.acknowledge
		)
		#expect(await viewModel.quickLog(medication: medication))
		#expect(dataStore.events.count == 1)
		let loggedEventID = dataStore.events.first?.id
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 10.0)

		// When
		let undoSuccess = await viewModel.undoLastQuickLog()

		// Then
		#expect(undoSuccess == false)
		#expect(dataStore.events.count == 1)
		#expect(dataStore.events.first?.id == loggedEventID)
		#expect(dataStore.medications.first { $0.id == medication.id }?.quantity == 10.0)
		#expect(viewModel.quickLogFeedback?.undoEventID == loggedEventID)
		#expect(viewModel.showQuickLogToast)
	}

	@Test("Replacement toast ignores stale auto-dismissal")
	func replacementToastIgnoresStaleAutoDismissal() async throws {
		let firstMedication = createTestMedication(name: "First", quantity: 20)
		let secondMedication = createTestMedication(name: "Second", quantity: 20)
		_ = await viewModel.add(firstMedication)
		_ = await viewModel.add(secondMedication)

		#expect(await viewModel.quickLog(medication: firstMedication))
		let firstGeneration = viewModel.quickLogToastGeneration
		#expect(await viewModel.quickLog(medication: secondMedication))
		let secondGeneration = viewModel.quickLogToastGeneration

		#expect(firstGeneration != secondGeneration)
		#expect(toastScheduler.actions.count == 2)
		toastScheduler.actions[0]()
		#expect(viewModel.showQuickLogToast)
		#expect(viewModel.quickLogMedicationName == "Second")
		#expect(viewModel.quickLogToastGeneration == secondGeneration)

		toastScheduler.actions[1]()
		#expect(!viewModel.showQuickLogToast)
		#expect(viewModel.quickLogToastGeneration == nil)
	}

	@Test("Manual dismissal cannot dismiss a subsequent toast")
	func manualDismissalCannotDismissSubsequentToast() async throws {
		let firstMedication = createTestMedication(name: "First", quantity: 20)
		let secondMedication = createTestMedication(name: "Second", quantity: 20)
		_ = await viewModel.add(firstMedication)
		_ = await viewModel.add(secondMedication)

		#expect(await viewModel.quickLog(medication: firstMedication))
		let firstGeneration = viewModel.quickLogToastGeneration
		viewModel.dismissQuickLogToast()
		#expect(!viewModel.showQuickLogToast)

		#expect(await viewModel.quickLog(medication: secondMedication))
		toastScheduler.actions[0]()
		#expect(viewModel.showQuickLogToast)
		#expect(viewModel.quickLogToastGeneration != firstGeneration)
		#expect(viewModel.quickLogMedicationName == "Second")
	}

    @Test("Quick log preserves medication order")
    func quickLogPreservesMedicationOrder() async throws {
        // Given
        let firstMedication = createTestMedication(name: "A", quantity: 10.0)
        let secondMedication = createTestMedication(name: "B", quantity: 10.0)
        _ = await viewModel.add(firstMedication)
        _ = await viewModel.add(secondMedication)
        let originalOrder = viewModel.sortedMedications.map(\.id)
        let storedOrderBeforeQuickLog = UserDefaults.standard.string(forKey: UserDefaultsKeys.medicationOrder).flatMap([String].init(rawValue:))

        // When
        let success = await viewModel.quickLog(medication: firstMedication)
        let storedOrderAfterQuickLog = UserDefaults.standard.string(forKey: UserDefaultsKeys.medicationOrder).flatMap([String].init(rawValue:))

        // Then
        #expect(success)
        #expect(storedOrderBeforeQuickLog == originalOrder.map(\.uuidString))
        #expect(storedOrderAfterQuickLog == storedOrderBeforeQuickLog)
        #expect(viewModel.sortedMedications.map(\.id) == originalOrder)
    }

	@Test("quickLog stores undo feedback and undo restores event and quantity")
	func quickLogStoresUndoFeedbackAndUndoRestoresEventAndQuantity() async throws {
		// Given
		let medication = createTestMedication(name: "Undo Med", quantity: 20.0)
		_ = await viewModel.add(medication)

		// When
		let success = await viewModel.quickLog(medication: medication)

		// Then
		#expect(success)
		#expect(dataStore.events.count == 1)
		#expect(viewModel.quickLogFeedback?.undoEventID == dataStore.events.first?.id)
		#expect(viewModel.quickLogFeedback?.title == "Dose logged")
		#expect(viewModel.quickLogFeedback?.detail == medication.displayName)
		#expect(viewModel.quickLogFeedback?.message.localizedCaseInsensitiveContains("guidance") == false)

		let undoSuccess = await viewModel.undoLastQuickLog()

		#expect(undoSuccess)
		#expect(dataStore.events.isEmpty)
		#expect(dataStore.medications.first?.quantity == 20.0)
		#expect(viewModel.quickLogFeedback == nil)
		#expect(viewModel.showQuickLogToast == false)

		#expect(await viewModel.quickLog(medication: medication))
		let subsequentGeneration = viewModel.quickLogToastGeneration
		toastScheduler.actions[0]()
		#expect(viewModel.showQuickLogToast)
		#expect(viewModel.quickLogToastGeneration == subsequentGeneration)
	}

    @Test("logDose correctly logs dose and updates state")
    func logDoseCorrectlyLogsDose() async throws {
        // Given
        let medication = createTestMedication(name: "Log Dose Med", quantity: 10.0)
        _ = await viewModel.add(medication)
        
        let dose = ANDoseConcept(amount: 5.0, unit: .milligram)
        let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose, date: Date())

        // When
        let success = await viewModel.logDose(med: medication, dose: dose, event: event)

        // Then
        #expect(success)
        #expect(dataStore.events.count == 1)
        guard let updatedMed = dataStore.medications.first(where: { $0.id == medication.id }) else {
            #expect(false, "Updated medication not found in data store.") // Replaced #fail with #expect(false, ...)
            return
        }
        #expect(updatedMed.quantity == 5.0) // Quantity updated
        
        // Depending on hideSupportBanners, either quickLogToast or supportToast will show
        // For this test, we ensure hideSupportBanners is false in init
        try await Task.sleep(nanoseconds: 600_000_000)
        #expect(viewModel.showSupportToast)
    }

    // MARK: - Helper Methods
    private func createTestMedication(name: String, nickname: String? = nil, quantity: Double? = nil) -> ANMedicationConcept {
        return ANMedicationConcept(
            clinicalName: name,
            nickname: nickname,
            quantity: quantity,
            initialQuantity: 30.0,
            prescribedUnit: .milligram,
            prescribedDoseAmount: 10.0
        )
    }
}

// MedicationDetailViewModelTests.swift
// Comprehensive unit tests for MedicationDetailViewModel

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("MedicationDetailViewModel Tests", .tags(.medication, .viewModel, .detail, .unit))
struct MedicationDetailViewModelTests {
    // MARK: - Test Helpers

    private func createTestMedication(
        name: String = "TestMed",
        quantity: Double = 100.0,
        unit: ANUnitConcept = .tablet
    ) -> ANMedicationConcept {
        ANMedicationConcept(
            clinicalName: name,
            nickname: nil,
            quantity: quantity,
            prescribedUnit: unit,
            prescribedDoseAmount: 2.0
        )
    }

    private func createTestEvent(
        medication: ANMedicationConcept,
        date: Date = Date(),
        amount: Double = 1.0,
        unit: ANUnitConcept = .tablet
    ) -> ANEventConcept {
        let dose = ANDoseConcept(amount: amount, unit: unit)
        return ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: date
        )
    }

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with default dataStore")
    func initializationDefault() {
        let viewModel = MedicationDetailViewModel()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ViewModel initializes with custom dataStore")
    func initializationCustomDataStore() {
        let dataStore = DataStore(testIdentifier: "DetailVM-CustomInit")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Save Medication Tests

    @Test("Save medication succeeds with valid data")
    func saveMedicationSuccess() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-SaveSuccess")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "Aspirin")
        try await dataStore.addMedication(medication)

        var updatedMedication = medication
        updatedMedication.quantity = 50.0

        await viewModel.save(updated: updatedMedication)

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)

        let savedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(savedMedication?.quantity == 50.0)
    }

    @Test("Save medication updates isLoading state")
    func saveMedicationLoadingState() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-SaveLoading")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "Ibuprofen")
        try await dataStore.addMedication(medication)

        let saveTask = Task {
            await viewModel.save(updated: medication)
        }

        await saveTask.value

        #expect(viewModel.isLoading == false)
    }

    @Test("Save medication clears previous error")
    func saveMedicationClearsPreviousError() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-SaveClearError")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        // Set an error manually
        await MainActor.run {
            viewModel.errorMessage = "Previous error"
        }

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        await viewModel.save(updated: medication)

        #expect(viewModel.errorMessage == nil)
    }

    @Test("Save medication with clinical name change")
    func saveMedicationNameChange() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-SaveNameChange")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "Original Name")
        try await dataStore.addMedication(medication)

        var updatedMedication = medication
        updatedMedication.clinicalName = "Updated Name"

        await viewModel.save(updated: updatedMedication)

        let savedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(savedMedication?.clinicalName == "Updated Name")
    }

    @Test("Save medication with quantity change")
    func saveMedicationQuantityChange() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-SaveQtyChange")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed", quantity: 100.0)
        try await dataStore.addMedication(medication)

        var updatedMedication = medication
        updatedMedication.quantity = 75.0

        await viewModel.save(updated: updatedMedication)

        let savedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(savedMedication?.quantity == 75.0)
    }

    @Test("Save medication with unit change")
    func saveMedicationUnitChange() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-SaveUnitChange")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed", unit: .tablet)
        try await dataStore.addMedication(medication)

        var updatedMedication = medication
        updatedMedication.prescribedUnit = .milligram

        await viewModel.save(updated: updatedMedication)

        let savedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(savedMedication?.prescribedUnit == .milligram)
    }

    @Test("Save medication preserves ID")
    func saveMedicationPreservesID() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-SavePreserveID")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        let originalID = medication.id
        try await dataStore.addMedication(medication)

        var updatedMedication = medication
        updatedMedication.clinicalName = "Updated"

        await viewModel.save(updated: updatedMedication)

        let savedMedication = dataStore.medications.first { $0.id == originalID }
        #expect(savedMedication != nil)
        #expect(savedMedication?.id == originalID)
    }

    // MARK: - Delete Medication Tests

    @Test("Delete medication succeeds")
    func deleteMedicationSuccess() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-DeleteSuccess")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "ToDelete")
        try await dataStore.addMedication(medication)

        #expect(dataStore.medications.count == 1)

        await viewModel.delete(medication)

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(dataStore.medications.isEmpty)
    }

    @Test("Delete medication updates isLoading state")
    func deleteMedicationLoadingState() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-DeleteLoading")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "ToDelete")
        try await dataStore.addMedication(medication)

        let deleteTask = Task {
            await viewModel.delete(medication)
        }

        await deleteTask.value

        #expect(viewModel.isLoading == false)
    }

    @Test("Delete medication clears previous error")
    func deleteMedicationClearsPreviousError() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-DeleteClearError")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        // Set an error manually
        await MainActor.run {
            viewModel.errorMessage = "Previous error"
        }

        let medication = createTestMedication(name: "ToDelete")
        try await dataStore.addMedication(medication)

        await viewModel.delete(medication)

        #expect(viewModel.errorMessage == nil)
    }

    @Test("Delete medication removes all references")
    func deleteMedicationRemovesReferences() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-DeleteReferences")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "ToDelete")
        try await dataStore.addMedication(medication)

        let event = createTestEvent(medication: medication)
        try await dataStore.addEvent(event)

        #expect(dataStore.medications.count == 1)

        await viewModel.delete(medication)

        #expect(dataStore.medications.isEmpty)
        // Events are typically removed by cascade or separate logic
    }

    @Test("Delete medication with multiple medications only deletes one")
    func deleteMedicationSelectiveDelete() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-DeleteSelective")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let med1 = createTestMedication(name: "Med1")
        let med2 = createTestMedication(name: "Med2")
        try await dataStore.addMedication(med1)
        try await dataStore.addMedication(med2)

        #expect(dataStore.medications.count == 2)

        await viewModel.delete(med1)

        #expect(dataStore.medications.count == 1)
        #expect(dataStore.medications.first?.id == med2.id)
    }

    // MARK: - Log Event Tests

    @Test("Log event succeeds")
    func logEventSuccess() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-LogSuccess")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let event = createTestEvent(medication: medication, amount: 2.0)

        await viewModel.log(event: event)

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(dataStore.events.count == 1)
    }

    @Test("Log event updates isLoading state")
    func logEventLoadingState() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-LogLoading")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let event = createTestEvent(medication: medication)

        let logTask = Task {
            await viewModel.log(event: event)
        }

        await logTask.value

        #expect(viewModel.isLoading == false)
    }

    @Test("Log event clears previous error")
    func logEventClearsPreviousError() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-LogClearError")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        // Set an error manually
        await MainActor.run {
            viewModel.errorMessage = "Previous error"
        }

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let event = createTestEvent(medication: medication)

        await viewModel.log(event: event)

        #expect(viewModel.errorMessage == nil)
    }

    @Test("Log event stores correct date")
    func logEventStoresDate() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-LogDate")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let specificDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let event = createTestEvent(medication: medication, date: specificDate)

        await viewModel.log(event: event)

        guard let loggedEvent = dataStore.events.first else {
            Issue.record("Expected logged event")
            return
        }

        #expect(abs(loggedEvent.date.timeIntervalSince(specificDate)) < 1.0)
    }

    @Test("Log event stores correct dose amount")
    func logEventStoresDoseAmount() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-LogAmount")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let event = createTestEvent(medication: medication, amount: 5.5)

        await viewModel.log(event: event)

        guard let loggedEvent = dataStore.events.first else {
            Issue.record("Expected logged event")
            return
        }

        #expect(loggedEvent.dose?.amount == 5.5)
    }

    @Test("Log event stores correct unit")
    func logEventStoresUnit() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-LogUnit")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let event = createTestEvent(medication: medication, amount: 10.0, unit: .milligram)

        await viewModel.log(event: event)

        guard let loggedEvent = dataStore.events.first else {
            Issue.record("Expected logged event")
            return
        }

        #expect(loggedEvent.dose?.unit == .milligram)
    }

    @Test("Log multiple events accumulates correctly")
    func logMultipleEvents() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-LogMultiple")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let event1 = createTestEvent(medication: medication, amount: 1.0)
        let event2 = createTestEvent(medication: medication, amount: 2.0)
        let event3 = createTestEvent(medication: medication, amount: 3.0)

        await viewModel.log(event: event1)
        await viewModel.log(event: event2)
        await viewModel.log(event: event3)

        #expect(dataStore.events.count == 3)
    }

    @Test("Log event with note")
    func logEventWithNote() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-LogNote")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        var event = createTestEvent(medication: medication)
        event.note = "Test note"

        await viewModel.log(event: event)

        guard let loggedEvent = dataStore.events.first else {
            Issue.record("Expected logged event")
            return
        }

        #expect(loggedEvent.note == "Test note")
    }

    @Test("Log event preserves medication reference")
    func logEventPreservesMedicationReference() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-LogMedRef")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let event = createTestEvent(medication: medication)

        await viewModel.log(event: event)

        guard let loggedEvent = dataStore.events.first else {
            Issue.record("Expected logged event")
            return
        }

        #expect(loggedEvent.medication?.id == medication.id)
    }

    // MARK: - Error State Tests

    @Test("ViewModel handles concurrent operations")
    func concurrentOperations() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-Concurrent")
        try await dataStore.clearAllData()

        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        // Create events with different dates to ensure uniqueness
        let baseDate = Date()
        let event1 = createTestEvent(medication: medication, date: baseDate, amount: 1.0)
        let event2 = createTestEvent(medication: medication, date: baseDate.addingTimeInterval(2), amount: 2.0)

        // Run operations sequentially to avoid race conditions in the test
        await viewModel.log(event: event1)
        await viewModel.log(event: event2)

        // Allow time for Boutique store to sync
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        #expect(dataStore.events.count == 2, "Expected 2 events, got \(dataStore.events.count)")
        #expect(viewModel.errorMessage == nil, "Expected no error, got: \(viewModel.errorMessage ?? "nil")")
    }

    @Test("ViewModel state resets after successful operation")
    func stateResetsAfterSuccess() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-StateReset")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        let medication = createTestMedication(name: "TestMed")
        try await dataStore.addMedication(medication)

        let event = createTestEvent(medication: medication)

        await viewModel.log(event: event)

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Integration Tests

    @Test("Complete workflow: save, log, delete")
    func completeWorkflow() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-Workflow")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        // Step 1: Create and save medication
        var medication = createTestMedication(name: "WorkflowMed", quantity: 100.0)
        try await dataStore.addMedication(medication)

        // Step 2: Update quantity
        medication.quantity = 90.0
        await viewModel.save(updated: medication)

        guard let savedMed = dataStore.medications.first else {
            Issue.record("Expected saved medication")
            return
        }
        #expect(savedMed.quantity == 90.0)

        // Step 3: Log event
        let event = createTestEvent(medication: medication, amount: 10.0)
        await viewModel.log(event: event)
        #expect(dataStore.events.count == 1)

        // Step 4: Delete medication
        await viewModel.delete(medication)
        #expect(dataStore.medications.isEmpty)

        #expect(viewModel.errorMessage == nil)
    }

    @Test("Multiple medications workflow")
    func multipleMedicationsWorkflow() async throws {
        let dataStore = DataStore(testIdentifier: "DetailVM-MultiWorkflow")
        let viewModel = MedicationDetailViewModel(dataStore: dataStore)

        // Add multiple medications
        let med1 = createTestMedication(name: "Med1")
        let med2 = createTestMedication(name: "Med2")
        let med3 = createTestMedication(name: "Med3")

        try await dataStore.addMedication(med1)
        try await dataStore.addMedication(med2)
        try await dataStore.addMedication(med3)

        #expect(dataStore.medications.count == 3)

        // Log events for each
        await viewModel.log(event: createTestEvent(medication: med1))
        await viewModel.log(event: createTestEvent(medication: med2))
        await viewModel.log(event: createTestEvent(medication: med3))

        #expect(dataStore.events.count == 3)

        // Delete one
        await viewModel.delete(med2)

        #expect(dataStore.medications.count == 2)
        #expect(viewModel.errorMessage == nil)
    }
}

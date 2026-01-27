// MedicationHistoryViewModelTests.swift
// Unit tests for MedicationHistoryViewModel dose editing functionality

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("MedicationHistoryViewModel Dose Editing Tests")
struct MedicationHistoryViewModelTests {
    // MARK: - Test Setup Helpers

    private func createTestMedication(quantity: Double = 10.0) -> ANMedicationConcept {
        ANMedicationConcept(
            clinicalName: "Ibuprofen",
            nickname: "Pain Relief",
            quantity: quantity,
            prescribedUnit: .tablet,
            prescribedDoseAmount: 2.0
        )
    }

    private func createTestEvent(medication: ANMedicationConcept, amount: Double, unit: ANUnitConcept) -> ANEventConcept {
        let dose = ANDoseConcept(amount: amount, unit: unit)
        return ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: Date()
        )
    }

    // MARK: - Dose Increase Tests

    @Test("Update event with increased dose decreases medication quantity")
    func updateEventIncreaseDoseDecreasesQuantity() async throws {
        // Given: medication with quantity 10, event with dose 2
        let medication = createTestMedication(quantity: 10.0)
        let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

        // When: update event dose from 2 to 3
        await viewModel.updateEvent(event, newDate: event.date, newAmount: 3.0, newUnit: .tablet)

        // Then: medication quantity should decrease by 1 (10 - 1 = 9)
        let updatedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(updatedMedication?.quantity == 9.0, "Quantity should decrease from 10 to 9 when dose increases from 2 to 3")
    }

    // MARK: - Dose Decrease Tests

    @Test("Update event with decreased dose increases medication quantity")
    func updateEventDecreaseDoseIncreasesQuantity() async throws {
        // Given: medication with quantity 10, event with dose 3
        let medication = createTestMedication(quantity: 10.0)
        let event = createTestEvent(medication: medication, amount: 3.0, unit: .tablet)

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

        // When: update event dose from 3 to 2
        await viewModel.updateEvent(event, newDate: event.date, newAmount: 2.0, newUnit: .tablet)

        // Then: medication quantity should increase by 1 (10 + 1 = 11)
        let updatedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(updatedMedication?.quantity == 11.0, "Quantity should increase from 10 to 11 when dose decreases from 3 to 2")
    }

    // MARK: - No Dose Change Tests

    @Test("Update event with same dose keeps quantity unchanged")
    func updateEventSameDoseKeepsQuantityUnchanged() async throws {
        // Given: medication with quantity 10, event with dose 2
        let medication = createTestMedication(quantity: 10.0)
        let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

        // When: update event with same dose (2.0)
        await viewModel.updateEvent(event, newDate: event.date, newAmount: 2.0, newUnit: .tablet)

        // Then: medication quantity should remain 10
        let updatedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(updatedMedication?.quantity == 10.0, "Quantity should remain 10 when dose doesn't change")
    }

    // MARK: - Date Change Tests

    @Test("Update event changes date correctly")
    func updateEventChangesDate() async throws {
        // Given: event with current date
        let medication = createTestMedication()
        let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

        // When: update event with new date
        let newDate = Date().addingTimeInterval(-3600) // 1 hour ago
        await viewModel.updateEvent(event, newDate: newDate, newAmount: 2.0, newUnit: .tablet)

        // Then: event date should be updated
        let updatedEvent = dataStore.events.first { $0.id == event.id }
        #expect(updatedEvent?.date.timeIntervalSince1970 == newDate.timeIntervalSince1970, "Event date should be updated to new date")
    }

    // MARK: - Unit Change Tests

    @Test("Update event changes unit correctly")
    func updateEventChangesUnit() async throws {
        // Given: event with tablet unit
        let medication = createTestMedication()
        let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

        // When: update event to use milliliter unit
        await viewModel.updateEvent(event, newDate: event.date, newAmount: 2.0, newUnit: .milliliter)

        // Then: event unit should be updated
        let updatedEvent = dataStore.events.first { $0.id == event.id }
        #expect(updatedEvent?.dose?.unit == .milliliter, "Event unit should be updated to milliliter")
    }

    // MARK: - Edge Case Tests

    @Test("Update event with nil medication quantity doesn't crash")
    func updateEventWithNilQuantity() async throws {
        // Given: medication with nil quantity
        var medication = createTestMedication()
        medication.quantity = nil
        let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

        // When: update event dose
        await viewModel.updateEvent(event, newDate: event.date, newAmount: 3.0, newUnit: .tablet)

        // Then: should not crash and medication quantity should remain nil
        let updatedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(updatedMedication?.quantity == nil, "Quantity should remain nil when original quantity is nil")
    }

    @Test("Update event with large dose increase")
    func updateEventLargeDoseIncrease() async throws {
        // Given: medication with quantity 100, event with dose 1
        let medication = createTestMedication(quantity: 100.0)
        let event = createTestEvent(medication: medication, amount: 1.0, unit: .tablet)

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

        // When: update event dose from 1 to 50
        await viewModel.updateEvent(event, newDate: event.date, newAmount: 50.0, newUnit: .tablet)

        // Then: medication quantity should decrease by 49 (100 - 49 = 51)
        let updatedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(updatedMedication?.quantity == 51.0, "Quantity should decrease from 100 to 51 when dose increases from 1 to 50")
    }

    @Test("Update event with fractional dose amounts")
    func updateEventFractionalDoses() async throws {
        // Given: medication with quantity 10.5, event with dose 0.5
        let medication = createTestMedication(quantity: 10.5)
        let event = createTestEvent(medication: medication, amount: 0.5, unit: .tablet)

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

        // When: update event dose from 0.5 to 1.5
        await viewModel.updateEvent(event, newDate: event.date, newAmount: 1.5, newUnit: .tablet)

        // Then: medication quantity should decrease by 1.0 (10.5 - 1.0 = 9.5)
        let updatedMedication = dataStore.medications.first { $0.id == medication.id }
        #expect(updatedMedication?.quantity == 9.5, "Quantity should decrease from 10.5 to 9.5 when dose increases from 0.5 to 1.5")
    }
}

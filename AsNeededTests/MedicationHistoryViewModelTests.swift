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

    private func clearStoredSelection() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.historySelectedMedicationID)
    }

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

    @Test("EnsureValidSelection defaults to all medications")
    func ensureValidSelectionDefaultsToAll() async throws {
        clearStoredSelection()
        let medication = createTestMedication()
        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-SelectionAll")
        try? await dataStore.addMedication(medication)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)

        #expect(viewModel.selectedMedicationID == "all")
        #expect(viewModel.isShowingAllMedications)
    }

    @Test("Selected medication resolves when a medication ID is provided")
    func selectedMedicationResolvesProvidedID() async throws {
        clearStoredSelection()
        let medication = createTestMedication()
        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-SelectionSpecific")
        try? await dataStore.addMedication(medication)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)

        #expect(viewModel.selectedMedication?.id == medication.id)
        #expect(viewModel.isShowingAllMedications == false)
    }

    @Test("Grouped history filters to selected medication and sorts newest day first")
    func groupedHistoryFiltersAndSorts() async throws {
        clearStoredSelection()
        let med1 = createTestMedication(quantity: 8)
        let med2 = ANMedicationConcept(
            clinicalName: "Cetirizine",
            quantity: 20,
            prescribedUnit: .tablet,
            prescribedDoseAmount: 1
        )

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-GroupedHistory")
        try? await dataStore.addMedication(med1)
        try? await dataStore.addMedication(med2)

        let todayEvent = createTestEvent(medication: med1, amount: 1.0, unit: .tablet)
        let yesterdayEvent = ANEventConcept(
            eventType: .doseTaken,
            medication: med1,
            dose: ANDoseConcept(amount: 1.0, unit: .tablet),
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        )
        let otherMedicationEvent = createTestEvent(medication: med2, amount: 1.0, unit: .tablet)

        try? await dataStore.addEvent(todayEvent)
        try? await dataStore.addEvent(yesterdayEvent)
        try? await dataStore.addEvent(otherMedicationEvent)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: med1.id.uuidString)

        #expect(viewModel.groupedHistory.count == 2)
        #expect(viewModel.groupedHistory.first?.entries.first?.medication?.id == med1.id)
        #expect(viewModel.groupedHistory.allSatisfy { $0.entries.allSatisfy { $0.medication?.id == med1.id } })
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

    @Test("Updating a history note preserves structured reflection data")
    func updateEventNotePreservesStructuredReflectionData() async throws {
        clearStoredSelection()
        let medication = createTestMedication(quantity: 10.0)
        var event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)
        event.note = try DoseReflectionCodec.encode(
            DoseReflection(
                reason: "Headache",
                symptomSeverityBefore: 6,
                symptomSeverityAfter: 2,
                effectiveness: 4,
                sideEffects: ["Sleepy"],
                note: "Original note"
            )
        )

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-StructuredNote")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore)
        let updatedNote = try DoseReflectionCodec.updatingNote(in: event.note, with: "Updated note")
        var updatedEvent = event
        updatedEvent.note = updatedNote

        await viewModel.updateEventNote(updatedEvent)

        let storedEvent = try #require(dataStore.events.first { $0.id == event.id })
        let reflection = try #require(DoseReflectionCodec.reflection(from: storedEvent.note))
        #expect(reflection.reason == "Headache")
        #expect(reflection.effectiveness == 4)
        #expect(reflection.note == "Updated note")
    }

    @Test("Deleting an event restores medication quantity")
    func deleteEventRestoresMedicationQuantity() async throws {
        clearStoredSelection()
        let medication = createTestMedication(quantity: 5.0)
        let event = createTestEvent(medication: medication, amount: 2.0, unit: .tablet)

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-DeleteEvent")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(event)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)

        await viewModel.deleteEvent(event)

        #expect(dataStore.events.isEmpty)
        #expect(dataStore.medications.first?.quantity == 7.0)
    }

    @Test("Deleting events by offset restores only the targeted event quantities")
    func deleteEventsByOffsetRestoresTargetedQuantities() async throws {
        clearStoredSelection()
        let medication = createTestMedication(quantity: 10.0)
        let today = Calendar.current.startOfDay(for: .now)
        let firstEvent = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: ANDoseConcept(amount: 1.0, unit: .tablet),
            date: today.addingTimeInterval(3600)
        )
        let secondEvent = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: ANDoseConcept(amount: 2.0, unit: .tablet),
            date: today.addingTimeInterval(7200)
        )

        let dataStore = DataStore(testIdentifier: "MedicationHistoryViewModelTests-DeleteOffsets")
        try? await dataStore.addMedication(medication)
        try? await dataStore.addEvent(firstEvent)
        try? await dataStore.addEvent(secondEvent)

        let viewModel = MedicationHistoryViewModel(dataStore: dataStore, selectedMedicationID: medication.id.uuidString)

        await viewModel.deleteEvents(at: IndexSet(integer: 0), in: today)

        #expect(dataStore.events.count == 1)
        #expect(dataStore.medications.first?.quantity == 12.0)
    }
}

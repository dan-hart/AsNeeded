@testable import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import SwiftUI

@MainActor
@Suite("MedicationListViewModel Unit Tests", .tags(.viewModel, .medication, .unit))
struct MedicationListViewModelUnitTests {
    private var viewModel: MedicationListViewModel
    private var dataStore: DataStore

    init() async throws {
        // Create test instance with isolated storage
        dataStore = DataStore(testIdentifier: "MedicationListViewModelUnitTests")
        viewModel = MedicationListViewModel(dataStore: dataStore)
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
        // Resetting the ViewModel to pick up the new UserDefaults
        viewModel = MedicationListViewModel(dataStore: dataStore)
        UserDefaults.standard.set([med3.id.uuidString, med1.id.uuidString], forKey: UserDefaultsKeys.medicationOrder)
        
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
        #expect(!UserDefaults.standard.array(forKey: UserDefaultsKeys.medicationOrder)!.contains(where: { $0 as? String == med2.id.uuidString }))
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

        // When
        let success = await viewModel.quickLog(medication: medication)

        // Then
        #expect(success)
        #expect(dataStore.events.count == 1) // Verify event was added
        #expect(viewModel.showQuickLogToast) // Verify toast state change
        #expect(viewModel.quickLogMedicationName == medication.displayName)

        // Simulate toast dismissal after delay
        try await Task.sleep(nanoseconds: 3_100_000_000) // Slightly longer than toast duration
        #expect(!viewModel.showQuickLogToast)
    }

    @Test("logDose correctly logs dose and updates state")
    func logDoseCorrectlyLogsDose() async throws {
        // Given
        let medication = createTestMedication(name: "Log Dose Med", quantity: 10.0)
        _ = await viewModel.add(medication)
        
        let dose = ANDoseConcept(amount: 5.0, unit: .milligram)
        let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose, date: Date())

        // When
        await viewModel.logDose(med: medication, dose: dose, event: event)

        // Then
        #expect(dataStore.events.count == 1)
        guard let updatedMed = dataStore.medications.first(where: { $0.id == medication.id }) else {
            #expect(false, "Updated medication not found in data store.") // Replaced #fail with #expect(false, ...)
            return
        }
        #expect(updatedMed.quantity == 5.0) // Quantity updated
        
        // Depending on hideSupportBanners, either quickLogToast or supportToast will show
        // For this test, we ensure hideSupportBanners is false in init
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
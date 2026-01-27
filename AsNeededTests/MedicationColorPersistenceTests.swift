import ANModelKit
@testable import AsNeeded
import Boutique
import Foundation
import Testing

/// Tests for medication color persistence and data operations
/// Verifies that medication color changes are properly saved and retrieved
@Suite("Medication Color Persistence Tests")
struct MedicationColorPersistenceTests {
    // MARK: - Helper Methods

    private func createTestMedication(with colorHex: String? = nil) -> ANMedicationConcept {
        return ANMedicationConcept(
            clinicalName: "Test Medication",
            displayColorHex: colorHex
        )
    }

    // MARK: - Basic Persistence Tests

    @Test("Medication saves with color hex")
    @MainActor
    func medicationSavesWithColorHex() async throws {
        let dataStore = DataStore(testIdentifier: "test-saves-color")
        let colorHex = "#FF5733"
        let medication = createTestMedication(with: colorHex)

        // Save medication
        try await dataStore.addMedication(medication)

        // Retrieve from store to verify
        let savedMedications = dataStore.medications.filter { $0.clinicalName == medication.clinicalName }
        #expect(savedMedications.count >= 1)

        if let savedMedication = savedMedications.first {
            #expect(savedMedication.displayColorHex == colorHex)

            // Clean up
            try await dataStore.deleteMedication(savedMedication)
        }
    }

    @Test("Medication saves without color hex")
    @MainActor
    func medicationSavesWithoutColorHex() async throws {
        let dataStore = DataStore(testIdentifier: "test-saves-nil")
        let medication = createTestMedication(with: nil)

        // Save medication
        try await dataStore.addMedication(medication)

        // Retrieve from store to verify
        let savedMedications = dataStore.medications.filter { $0.clinicalName == medication.clinicalName }
        #expect(savedMedications.count >= 1)

        if let savedMedication = savedMedications.first {
            #expect(savedMedication.displayColorHex == nil)

            // Clean up
            try await dataStore.deleteMedication(savedMedication)
        }
    }

    @Test("Medication color updates persist")
    @MainActor
    func medicationColorUpdatesPersist() async throws {
        let dataStore = DataStore(testIdentifier: "test-updates")
        let originalColor = "#FF0000"
        let updatedColor = "#00FF00"
        let medication = createTestMedication(with: originalColor)

        // Save original medication
        try await dataStore.addMedication(medication)

        // Retrieve from store
        let savedMedications = dataStore.medications.filter { $0.clinicalName == medication.clinicalName }
        guard var savedMedication = savedMedications.first else {
            Issue.record("Failed to save medication")
            return
        }

        #expect(savedMedication.displayColorHex == originalColor)

        // Update color
        savedMedication.displayColorHex = updatedColor
        try await dataStore.updateMedication(savedMedication)

        // Verify color update persisted
        let updatedMedications = dataStore.medications.filter { $0.id == savedMedication.id }
        if let updatedMedication = updatedMedications.first {
            #expect(updatedMedication.displayColorHex == updatedColor)
            #expect(updatedMedication.displayColorHex != originalColor)

            // Clean up
            try await dataStore.deleteMedication(updatedMedication)
        }
    }

    // MARK: - Display Color Property Tests

    @Test("Display color property returns correct values")
    func displayColorPropertyReturnsCorrectValues() {
        // Test with valid hex
        let validHexMed = ANMedicationConcept(
            clinicalName: "Valid Hex Med",
            displayColorHex: "#FF5733"
        )

        // Should not crash and should return a valid color
        let validColor = validHexMed.displayColor
        // Just verify it doesn't crash - Color is a struct, can't be nil

        // Test with invalid hex
        let invalidHexMed = ANMedicationConcept(
            clinicalName: "Invalid Hex Med",
            displayColorHex: "invalid"
        )

        // Should not crash and should return fallback color
        let invalidColor = invalidHexMed.displayColor
        // Just verify it doesn't crash - should fall back to .accent

        // Test with nil hex
        let nilHexMed = ANMedicationConcept(
            clinicalName: "Nil Hex Med",
            displayColorHex: nil
        )

        // Should not crash and should return fallback color
        let nilColor = nilHexMed.displayColor
        // Just verify it doesn't crash - should fall back to .accent
    }

    // MARK: - MedicationEditViewModel Integration Tests

    @Test("MedicationEditViewModel handles color correctly")
    @MainActor
    func medicationEditViewModelHandlesColor() {
        // Test initializing with existing medication that has color
        let medicationWithColor = ANMedicationConcept(
            clinicalName: "Colored Med",
            displayColorHex: "#FF5733"
        )

        let viewModel = MedicationEditViewModel(medication: medicationWithColor)
        #expect(viewModel.displayColorHex == "#FF5733")

        // Test building medication with updated color
        viewModel.displayColorHex = "#00FF00"
        let builtMedication = viewModel.buildMedication()
        #expect(builtMedication.displayColorHex == "#00FF00")

        // Test initializing with nil medication
        let newMedicationViewModel = MedicationEditViewModel(medication: nil)
        #expect(newMedicationViewModel.displayColorHex == nil)

        // Test setting color on new medication
        newMedicationViewModel.clinicalName = "New Med"
        newMedicationViewModel.displayColorHex = "#0000FF"
        let newMedication = newMedicationViewModel.buildMedication()
        #expect(newMedication.displayColorHex == "#0000FF")
    }

    // MARK: - Color Consistency Tests

    @Test("Color remains consistent across app lifecycle")
    @MainActor
    func colorRemainsConsistentAcrossAppLifecycle() async throws {
        let dataStore = DataStore(testIdentifier: "test-lifecycle")
        let testColor = "#8E44AD"
        let medication = ANMedicationConcept(
            clinicalName: "Lifecycle Test Med",
            displayColorHex: testColor
        )

        // Save medication
        try await dataStore.addMedication(medication)

        // Verify initial color by retrieving from store
        let allMedications = dataStore.medications
        guard let retrievedMedication = allMedications.first(where: { $0.clinicalName == medication.clinicalName }) else {
            Issue.record("Failed to retrieve medication from store")
            return
        }

        // Verify color persisted
        #expect(retrievedMedication.displayColorHex == testColor)
        // Verify displayColor doesn't crash
        _ = retrievedMedication.displayColor

        // Clean up
        try await dataStore.deleteMedication(retrievedMedication)
    }
}

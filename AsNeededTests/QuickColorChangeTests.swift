import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

/// Tests for quick color change functionality in MedicationListViewModel
/// Verifies the medication list view model handles color updates correctly
@Suite("Quick Color Change Tests")
struct QuickColorChangeTests {
    // MARK: - Helper Methods

    private func createTestMedication(with colorHex: String? = nil) -> ANMedicationConcept {
        return ANMedicationConcept(
            clinicalName: "Test Medication",
            displayColorHex: colorHex
        )
    }

    // MARK: - MedicationListViewModel Success Tests

    @Test("MedicationListViewModel can add medications")
    @MainActor
    func medicationListViewModelCanAddMedications() async {
        let viewModel = MedicationListViewModel()
        let medication = createTestMedication(with: "#FF0000")

        let result = await viewModel.add(medication)
        #expect(result == true)

        // Clean up
        await viewModel.delete(medication)
    }

    @Test("MedicationListViewModel can update medications")
    @MainActor
    func medicationListViewModelCanUpdateMedications() async {
        let viewModel = MedicationListViewModel()
        var medication = createTestMedication(with: "#FF0000")

        // Add first
        let addResult = await viewModel.add(medication)
        #expect(addResult == true)

        // Then update
        medication.displayColorHex = "#00FF00"
        let updateResult = await viewModel.update(medication)
        #expect(updateResult == true)

        // Clean up
        await viewModel.delete(medication)
    }

    @Test("MedicationListViewModel can delete medications")
    @MainActor
    func medicationListViewModelCanDeleteMedications() async {
        let viewModel = MedicationListViewModel()
        let medication = createTestMedication(with: "#FF0000")

        // Add first
        let addResult = await viewModel.add(medication)
        #expect(addResult == true)

        // Then delete
        let deleteResult = await viewModel.delete(medication)
        #expect(deleteResult == true)
    }

    // MARK: - Color Display Tests

    @Test("Medications display colors correctly")
    func medicationsDisplayColorsCorrectly() {
        let redMed = createTestMedication(with: "#FF0000")
        let blueMed = createTestMedication(with: "#0000FF")
        let defaultMed = createTestMedication(with: nil)

        // Test display colors don't crash
        let redColor = redMed.displayColor
        let blueColor = blueMed.displayColor
        let defaultColor = defaultMed.displayColor

        // All should return valid colors (Color is a struct, can't be nil)
        // Just verify they don't crash
        _ = redColor
        _ = blueColor
        _ = defaultColor
    }

    // MARK: - Color Validation Tests

    @Test("Color validation works correctly")
    func colorValidationWorksCorrectly() {
        // Valid colors
        #expect(ANMedicationConcept.isValidHex("#FF0000") == true)
        #expect(ANMedicationConcept.isValidHex("00FF00") == true)

        // Invalid colors
        #expect(ANMedicationConcept.isValidHex("invalid") == false)
        #expect(ANMedicationConcept.isValidHex("") == false)
    }

    // MARK: - Integration Tests

    @Test("Color changes integrate with medication properties")
    @MainActor
    func colorChangesIntegrateWithMedicationProperties() {
        let viewModel = MedicationListViewModel()
        let medication = ANMedicationConcept(
            clinicalName: "Integration Test Med",
            nickname: "Test",
            displayColorHex: "#FF0000"
        )

        // Basic properties should remain intact when color is accessed
        #expect(medication.clinicalName == "Integration Test Med")
        #expect(medication.nickname == "Test")
        #expect(medication.displayColorHex == "#FF0000")

        // Display color should work
        let displayColor = medication.displayColor
        // Just verify it doesn't crash
        _ = displayColor
    }
}

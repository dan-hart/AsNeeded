@testable import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite(.tags(.intent, .unit))
struct ListMedicationsIntentTests {
    @Test("formatMedicationList handles empty array")
    func formatMedicationListHandlesEmptyArray() {
        let intent = ListMedicationsIntent()
        let result = intent.formatMedicationList([])
        #expect(result == "")
    }

    @Test("formatMedicationList handles single medication")
    func formatMedicationListHandlesSingleMedication() {
        let intent = ListMedicationsIntent()
        let result = intent.formatMedicationList(["Aspirin"])
        #expect(result == "Aspirin")
    }

    @Test("formatMedicationList handles two medications")
    func formatMedicationListHandlesTwoMedications() {
        let intent = ListMedicationsIntent()
        let result = intent.formatMedicationList(["Aspirin", "Tylenol"])
        #expect(result == "Aspirin and Tylenol")
    }

    @Test("formatMedicationList handles three medications")
    func formatMedicationListHandlesThreeMedications() {
        let intent = ListMedicationsIntent()
        let result = intent.formatMedicationList(["Aspirin", "Tylenol", "Ibuprofen"])
        #expect(result == "Aspirin, Tylenol, and Ibuprofen")
    }

    @Test("formatMedicationList handles four medications")
    func formatMedicationListHandlesFourMedications() {
        let intent = ListMedicationsIntent()
        let result = intent.formatMedicationList(["Aspirin", "Tylenol", "Ibuprofen", "Motrin"])
        #expect(result == "Aspirin, Tylenol, Ibuprofen, and Motrin")
    }

    @Test("formatMedicationList handles many medications")
    func formatMedicationListHandlesManyMedications() {
        let intent = ListMedicationsIntent()
        let medications = ["A", "B", "C", "D", "E", "F"]
        let result = intent.formatMedicationList(medications)
        #expect(result == "A, B, C, D, E, and F")
    }

    @Test("Intent has correct metadata")
    func intentHasCorrectMetadata() {
        #expect(ListMedicationsIntent.title == "List My Medications")
        #expect(ListMedicationsIntent.openAppWhenRun == false)
    }
}

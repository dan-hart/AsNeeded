@testable import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite(.tags(.intent, .unit))
struct GetDailyUsageIntentTests {
    @Test("Intent has correct metadata")
    func intentHasCorrectMetadata() {
        #expect(GetDailyUsageIntent.title == "Get Daily Medication Usage")
        #expect(GetDailyUsageIntent.openAppWhenRun == false)
    }

    @Test("calculateTodayUsage returns zero for medication with no events")
    func calculateTodayUsageReturnsZeroForMedicationWithNoEvents() {
        let intent = GetDailyUsageIntent()
        let medication = ANMedicationConcept(clinicalName: "Test Med", prescribedUnit: .tablet)

        let result = intent.calculateTodayUsage(for: medication)

        #expect(result.totalAmount == 0.0)
        #expect(result.unit == .tablet)
        #expect(result.doseCount == 0)
    }

    @Test("calculateTodayUsage uses default unit when no prescribed unit")
    func calculateTodayUsageUsesDefaultUnitWhenNoPrescribedUnit() {
        let intent = GetDailyUsageIntent()
        let medication = ANMedicationConcept(clinicalName: "Test Med")

        let result = intent.calculateTodayUsage(for: medication)

        #expect(result.totalAmount == 0.0)
        #expect(result.unit == .unit)
        #expect(result.doseCount == 0)
    }

    @Test("Intent can be initialized")
    func intentCanBeInitialized() {
        let intent = GetDailyUsageIntent()
        #expect(intent.medication == nil)
        #expect(intent.medicationName == nil)
    }

    @Test("Intent parameters can be set")
    func intentParametersCanBeSet() {
        var intent = GetDailyUsageIntent()
        intent.medicationName = "Aspirin"

        #expect(intent.medicationName == "Aspirin")
        #expect(intent.medication == nil)
    }
}

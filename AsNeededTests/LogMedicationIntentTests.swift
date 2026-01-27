@testable import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite(.tags(.intent, .unit))
struct LogMedicationIntentTests {
    @Test("Intent has correct metadata")
    func intentHasCorrectMetadata() {
        #expect(LogMedicationIntent.title == "Log Medication")
        #expect(LogMedicationIntent.openAppWhenRun == false)
    }

    @Test("Intent can be initialized with default values")
    func intentCanBeInitializedWithDefaultValues() {
        let intent = LogMedicationIntent()
        #expect(intent.medication == nil)
        #expect(intent.medicationName == nil)
        #expect(intent.amount == 1.0)
        #expect(intent.unit == nil)
    }

    @Test("Intent parameters can be set")
    func intentParametersCanBeSet() {
        var intent = LogMedicationIntent()
        intent.medicationName = "Aspirin"
        intent.amount = 2.0

        #expect(intent.medicationName == "Aspirin")
        #expect(intent.amount == 2.0)
        #expect(intent.medication == nil)
        #expect(intent.unit == nil)
    }

    @Test("Amount parameter has correct default value")
    func amountParameterHasCorrectDefaultValue() {
        let intent = LogMedicationIntent()
        #expect(intent.amount == 1.0)
    }
}

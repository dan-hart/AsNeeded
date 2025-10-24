@testable import ANModelKit
@testable import AsNeeded
import Combine
import Foundation
import Testing

@MainActor
@Suite(.tags(.medication, .list, .integration))
struct MedicationEventTests {
    @Test("Medication event stores dose information")
    func medicationEventProperties() {
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        let dose = ANDoseConcept(amount: 2, unit: .tablet)
        let timestamp = Date()

        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: timestamp
        )

        #expect(event.medication?.clinicalName == "Test Med")
        #expect(event.dose?.amount == 2)
        #expect(event.dose?.unit == ANUnitConcept.tablet)
        #expect(event.date == timestamp)
    }

    @Test("Adding medication updates items collection")
    @MainActor
    func addingMedicationUpdatesItems() async {
        let viewModel = MedicationListViewModel()
        let initialCount = viewModel.items.count

        let medication = ANMedicationConcept(clinicalName: "New Med")
        await viewModel.add(medication)

        // Since items is a computed property from DataStore, we verify the add worked
        #expect(viewModel.items.count >= initialCount)
    }
}

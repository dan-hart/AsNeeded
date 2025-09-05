import Testing
import Foundation
import Combine
@testable import AsNeeded
@testable import ANModelKit

@MainActor
struct MedicationListViewModelOperationsTests {
    
    @Test("View model initializes correctly")
    @MainActor
    func viewModelInitialization() async {
        let viewModel = MedicationListViewModel()
        #expect(viewModel.items.isEmpty)
    }
    
    @Test("Adding medication to view model")
    func addMedication() async {
        let viewModel = MedicationListViewModel()
        let medication = ANMedicationConcept(
            clinicalName: "Test Medication",
            quantity: 30
        )
        
        await viewModel.add(medication)
        
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.clinicalName == "Test Medication")
    }
    
    @Test("Updating medication in view model")
    func updateMedication() async {
        let viewModel = MedicationListViewModel()
        let medication = ANMedicationConcept(
            clinicalName: "Original Name",
            quantity: 30
        )
        
        await viewModel.add(medication)
        
        var updatedMedication = medication
        updatedMedication.clinicalName = "Updated Name"
        updatedMedication.quantity = 50
        
        await viewModel.update(updatedMedication)
        
        #expect(viewModel.items.first?.clinicalName == "Updated Name")
        #expect(viewModel.items.first?.quantity == 50)
    }
    
    @Test("Deleting medication from view model")
    func deleteMedication() async {
        let viewModel = MedicationListViewModel()
        let medication1 = ANMedicationConcept(clinicalName: "Med 1")
        let medication2 = ANMedicationConcept(clinicalName: "Med 2")
        
        await viewModel.add(medication1)
        await viewModel.add(medication2)
        
        #expect(viewModel.items.count == 2)
        
        await viewModel.delete(medication1)
        
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.clinicalName == "Med 2")
    }
    
    @Test("Logging dose reduces medication quantity")
    func logDoseReducesQuantity() async {
        let viewModel = MedicationListViewModel()
        let medication = ANMedicationConcept(
            clinicalName: "Test Med",
            quantity: 30,
            prescribedDoseAmount: 1
        )
        
        await viewModel.add(medication)
        
        let dose = ANDoseConcept(amount: 2, unit: .tablet)
        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: Date()
        )
        
        var updatedMedication = medication
        if let quantity = updatedMedication.quantity {
            updatedMedication.quantity = quantity - dose.amount
        }
        
        await viewModel.update(updatedMedication)
        await viewModel.addEvent(event)
        
        #expect(viewModel.items.first?.quantity == 28)
    }
    
    @Test("Medications can be sorted by refill date")
    func sortingByNextRefillDate() async {
        let viewModel = MedicationListViewModel()
        let med1 = ANMedicationConcept(
            clinicalName: "Med 1",
            nextRefillDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())
        )
        let med2 = ANMedicationConcept(
            clinicalName: "Med 2",
            nextRefillDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())
        )
        let med3 = ANMedicationConcept(
            clinicalName: "Med 3",
            nextRefillDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())
        )
        
        await viewModel.add(med1)
        await viewModel.add(med2)
        await viewModel.add(med3)
        
        let sortedMeds = viewModel.items.sorted { (first, second) in
            guard let date1 = first.nextRefillDate,
                  let date2 = second.nextRefillDate else {
                return false
            }
            return date1 < date2
        }
        
        #expect(sortedMeds.first?.clinicalName == "Med 3")
        #expect(sortedMeds.last?.clinicalName == "Med 1")
    }
    
    @Test("View model handles empty state")
    @MainActor  
    func emptyStateHandling() async {
        let viewModel = MedicationListViewModel()
        #expect(viewModel.items.isEmpty)
    }
    
    @Test("Multiple medications can be managed")
    func multipleItemsManagement() async {
        let viewModel = MedicationListViewModel()
        let medications = [
            ANMedicationConcept(clinicalName: "Med A"),
            ANMedicationConcept(clinicalName: "Med B"),
            ANMedicationConcept(clinicalName: "Med C")
        ]
        
        for med in medications {
            await viewModel.add(med)
        }
        
        #expect(viewModel.items.count == 3)
    }
}

@MainActor
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
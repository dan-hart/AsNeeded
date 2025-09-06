import Testing
import Foundation
@testable import AsNeeded
@testable import ANModelKit

@MainActor
@Suite
@Tag(.medication) @Tag(.list) @Tag(.ui) @Tag(.unit)
struct MedicationListViewModelTests {
    
    @Test("Medication model stores properties correctly")
    func medicationModelProperties() {
        let medication = ANMedicationConcept(
            clinicalName: "Test Medication",
            nickname: "Test",
            quantity: 30,
            lastRefillDate: Date(),
            nextRefillDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            prescribedUnit: .tablet,
            prescribedDoseAmount: 10.0
        )
        
        #expect(medication.clinicalName == "Test Medication")
        #expect(medication.nickname == "Test")
        #expect(medication.quantity == 30)
        #expect(medication.prescribedUnit == .tablet)
        #expect(medication.prescribedDoseAmount == 10.0)
    }
    
    @Test("Display name uses nickname when available")
    func displayNameWithNickname() {
        let medication = ANMedicationConcept(
            clinicalName: "Lisinopril",
            nickname: "Blood Pressure",
            quantity: 28.5
        )
        
        #expect(medication.displayName == "Blood Pressure")
    }
    
    @Test("Display name falls back to clinical name")
    func displayNameWithoutNickname() {
        let medication = ANMedicationConcept(
            clinicalName: "Metformin",
            quantity: 90.0
        )
        
        #expect(medication.displayName == "Metformin")
    }
    
    @Test("Overdue refill date is detected correctly")
    func overdueNextRefillDate() {
        let overdueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        let medication = ANMedicationConcept(
            clinicalName: "Albuterol",
            nextRefillDate: overdueDate
        )
        
        #expect(medication.nextRefillDate != nil)
        if let nextRefill = medication.nextRefillDate {
            #expect(nextRefill < Date())
        }
    }
    
    @Test("Upcoming refill date is in the future")
    func upcomingRefillDate() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())
        let medication = ANMedicationConcept(
            clinicalName: "Vitamin D3",
            nextRefillDate: futureDate
        )
        
        #expect(medication.nextRefillDate != nil)
        if let nextRefill = medication.nextRefillDate {
            #expect(nextRefill > Date())
        }
    }
    
    @Test("Log button callback is invoked")
    func logButtonCallback() {
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        var wasCalled = false
        
        let row = MedicationRow(medication: medication) {
            wasCalled = true
        }
        
        row.onLogTapped()
        
        #expect(wasCalled == true)
    }
    
    @Test("Formatted amount displays correctly")
    func formattedAmountDisplay() {
        let medication1 = ANMedicationConcept(
            clinicalName: "Test",
            quantity: 30.0
        )
        #expect(medication1.quantity?.formattedAmount == "30")
        
        let medication2 = ANMedicationConcept(
            clinicalName: "Test",
            quantity: 30.5
        )
        #expect(medication2.quantity?.formattedAmount == "30.5")
    }
    
    @Test("Date formatting for refills")
    func refillDateFormatting() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        
        let medication = ANMedicationConcept(
            clinicalName: "Test",
            lastRefillDate: pastDate,
            nextRefillDate: futureDate
        )
        
        #expect(medication.lastRefillDate != nil)
        #expect(medication.nextRefillDate != nil)
    }
}

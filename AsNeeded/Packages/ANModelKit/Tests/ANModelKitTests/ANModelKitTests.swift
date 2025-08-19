import Foundation
import Testing
@testable import ANModelKit

@Suite("ANModelKit Model Tests")
struct ANModelKitModelTests {
    @Test("ANMedicationConcept initialization")
    func testMedicationConceptInit() async throws {
        let med = ANMedicationConcept(clinicalName: "Albuterol", nickname: "Rescue Inhaler")
        #expect(med.clinicalName == "Albuterol")
        #expect(med.nickname == "Rescue Inhaler")
        #expect(type(of: med.id) == UUID.self)
    }
    
    @Test("ANDoseConcept initialization")
    func testDoseConceptInit() async throws {
        let dose = ANDoseConcept(amount: 2, unit: ANUnitConcept.puff)
        #expect(dose.amount == 2)
        #expect(dose.unit == ANUnitConcept.puff)
        #expect(type(of: dose.id) == UUID.self)
    }
    
    @Test("ANEventConcept initialization and relationships")
    func testEventConceptInit() async throws {
        let med = ANMedicationConcept(clinicalName: "Ibuprofen", nickname: nil)
        let dose = ANDoseConcept(amount: 400, unit: ANUnitConcept.milligram)
        let event = ANEventConcept(eventType: .doseTaken, medication: med, dose: dose, date: Date())
        #expect(event.eventType == .doseTaken)
        #expect(event.medication?.clinicalName == "Ibuprofen")
        #expect(event.dose?.amount == 400)
        #expect(event.dose?.unit == ANUnitConcept.milligram)
        #expect(type(of: event.id) == UUID.self)
    }
    
    @Test("ANDoseConcept Equatable and Hashable behavior")
    func testDoseConceptEquatableHashable() async throws {
        let dose1 = ANDoseConcept(amount: 5, unit: ANUnitConcept.tablet)
        let dose2 = ANDoseConcept(amount: 5, unit: ANUnitConcept.tablet)
        let dose3 = ANDoseConcept(amount: 10, unit: ANUnitConcept.tablet)
        let dose4 = ANDoseConcept(amount: 5, unit: ANUnitConcept.milliliter)
        
        #expect(dose1 == dose2)
        #expect(dose1 != dose3)
        #expect(dose1 != dose4)
        
        var set = Set<ANDoseConcept>()
        set.insert(dose1)
        set.insert(dose2)
        set.insert(dose3)
        set.insert(dose4)
        #expect(set.count == 3)
    }
}

@Suite("ANUnitConcept Tests")
struct ANUnitConceptTests {
    @Test("All cases are present and CaseIterable works correctly")
    func testAllCases() async throws {
        let allCases = ANUnitConcept.allCases
        // Expected known units to be present (ANUnitConcept enum cases)
        let expectedUnits: Set<ANUnitConcept> = [.milligram, .tablet, .liter, .puff, .milliliter]
        for unit in expectedUnits {
            #expect(allCases.contains(unit))
        }
        #expect(allCases.count >= expectedUnits.count)
    }
    
    @Test("displayName returns correct string for units") 
    func testDisplayName() async throws {
        #expect(ANUnitConcept.milligram.displayName == "mg")
        #expect(ANUnitConcept.tablet.displayName == "tablet")
        #expect(ANUnitConcept.liter.displayName == "L")
        #expect(ANUnitConcept.puff.displayName == "puff")
        #expect(ANUnitConcept.milliliter.displayName == "mL")
    }
    
    @Test("selectableUnits returns all cases") 
    func testSelectableUnits() async throws {
        let selectable = ANUnitConcept.selectableUnits
        #expect(Set(selectable) == Set(ANUnitConcept.allCases))
    }
    
    @Test("Codable round-trip retains correct unit") 
    func testCodableRoundTrip() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for unit in ANUnitConcept.allCases {
            let data = try encoder.encode(unit)
            let decoded = try decoder.decode(ANUnitConcept.self, from: data)
            #expect(decoded == unit)
        }
    }
}


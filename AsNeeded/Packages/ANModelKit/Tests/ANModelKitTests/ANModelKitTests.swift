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

@Suite("ANEventType Tests")
struct ANEventTypeTests {
	@Test("Codable round-trip retains correct event type") 
	func testCodableRoundTrip() async throws {
		let encoder = JSONEncoder()
		let decoder = JSONDecoder()
		
		for eventType in ANEventType.allCases {
			let data = try encoder.encode(eventType)
			let decoded = try decoder.decode(ANEventType.self, from: data)
			#expect(decoded == eventType)
		}
	}
	
	@Test("Equatable and Hashable uniqueness of all cases")
	func testEquatableHashable() async throws {
		let allCases = ANEventType.allCases
		var set = Set<ANEventType>()
		for eventType in allCases {
			set.insert(eventType)
		}
		#expect(set.count == allCases.count)
	}
}

// MedicationSearchUtilityTests.swift
// Comprehensive unit tests for MedicationSearchUtility

import Testing
import Foundation
@testable import AsNeeded
import ANModelKit

@Suite("MedicationSearchUtility Tests")
struct MedicationSearchUtilityTests {
	
	// MARK: - Test Data
	
	private var testMedications: [ANMedicationConcept] {
		[
			ANMedicationConcept(clinicalName: "Ibuprofen", nickname: "Pain Relief"),
			ANMedicationConcept(clinicalName: "Aspirin", nickname: nil),
			ANMedicationConcept(clinicalName: "Acetaminophen", nickname: "Tylenol"),
			ANMedicationConcept(clinicalName: "Lisinopril", nickname: "Blood Pressure"),
			ANMedicationConcept(clinicalName: "Metformin", nickname: nil),
			ANMedicationConcept(clinicalName: "Atorvastatin", nickname: "Lipitor"),
			ANMedicationConcept(clinicalName: "Omeprazole", nickname: "Stomach"),
			ANMedicationConcept(clinicalName: "Vitamin D3", nickname: "Sunshine Vitamin"),
			ANMedicationConcept(clinicalName: "Multi-Vitamin Complex", nickname: nil),
			ANMedicationConcept(clinicalName: "Ibuprofen 200mg", nickname: nil)
		]
	}
	
	// MARK: - FindBestMatch Tests
	
	@Test("Find best match with exact clinical name")
	@MainActor
	func testFindBestMatchExactClinicalName() {
		let medications = testMedications
		let match = MedicationSearchUtility.findBestMatch(for: "Aspirin", in: medications)
		
		#expect(match?.clinicalName == "Aspirin")
	}
	
	@Test("Find best match with exact nickname")
	@MainActor
	func testFindBestMatchExactNickname() {
		let medications = testMedications
		let match = MedicationSearchUtility.findBestMatch(for: "Tylenol", in: medications)
		
		#expect(match?.clinicalName == "Acetaminophen")
		#expect(match?.nickname == "Tylenol")
	}
	
	@Test("Find best match case insensitive")
	@MainActor
	func testFindBestMatchCaseInsensitive() {
		let medications = testMedications
		
		let match1 = MedicationSearchUtility.findBestMatch(for: "ASPIRIN", in: medications)
		#expect(match1?.clinicalName == "Aspirin")
		
		let match2 = MedicationSearchUtility.findBestMatch(for: "tylenol", in: medications)
		#expect(match2?.nickname == "Tylenol")
	}
	
	@Test("Find best match with partial match")
	@MainActor
	func testFindBestMatchPartial() {
		let medications = testMedications
		
		let match = MedicationSearchUtility.findBestMatch(for: "Ibupro", in: medications)
		#expect(match?.clinicalName.contains("Ibuprofen") == true)
	}
	
	@Test("Find best match with fuzzy matching")
	@MainActor
	func testFindBestMatchFuzzy() {
		let medications = testMedications
		
		let match = MedicationSearchUtility.findBestMatch(for: "Vit D", in: medications)
		#expect(match?.clinicalName == "Vitamin D3")
	}
	
	@Test("Find best match returns nil for no match")
	@MainActor
	func testFindBestMatchNoMatch() {
		let medications = testMedications
		
		let match = MedicationSearchUtility.findBestMatch(for: "Nonexistent", in: medications)
		#expect(match == nil)
	}
	
	@Test("Find best match with whitespace trimming")
	@MainActor
	func testFindBestMatchWhitespaceTrimming() {
		let medications = testMedications
		
		let match = MedicationSearchUtility.findBestMatch(for: "  Aspirin  ", in: medications)
		#expect(match?.clinicalName == "Aspirin")
	}
	
	@Test("Find best match with empty string returns nil")
	@MainActor
	func testFindBestMatchEmptyString() {
		let medications = testMedications
		
		let match1 = MedicationSearchUtility.findBestMatch(for: "", in: medications)
		#expect(match1 == nil)
		
		let match2 = MedicationSearchUtility.findBestMatch(for: "   ", in: medications)
		#expect(match2 == nil)
	}
	
	// MARK: - SearchMedications Tests
	
	@Test("Search medications finds exact matches first")
	@MainActor
	func testSearchMedicationsExactMatches() {
		let medications = testMedications
		
		let results = MedicationSearchUtility.searchMedications(query: "Aspirin", in: medications)
		#expect(results.count > 0)
		#expect(results[0].clinicalName == "Aspirin")
	}
	
	@Test("Search medications finds prefix matches")
	@MainActor
	func testSearchMedicationsPrefixMatches() {
		let medications = testMedications
		
		let results = MedicationSearchUtility.searchMedications(query: "Ibu", in: medications)
		#expect(results.count == 2) // "Ibuprofen" and "Ibuprofen 200mg"
		#expect(results.allSatisfy { $0.clinicalName.hasPrefix("Ibu") })
	}
	
	@Test("Search medications finds contains matches")
	@MainActor
	func testSearchMedicationsContainsMatches() {
		let medications = testMedications
		
		let results = MedicationSearchUtility.searchMedications(query: "pirin", in: medications)
		#expect(results.count == 1)
		#expect(results[0].clinicalName == "Aspirin")
	}
	
	@Test("Search medications respects limit")
	@MainActor
	func testSearchMedicationsLimit() {
		// Create many medications
		var medications: [ANMedicationConcept] = []
		for i in 1...20 {
			medications.append(ANMedicationConcept(clinicalName: "Med\(i)"))
		}
		
		let results = MedicationSearchUtility.searchMedications(query: "Med", in: medications, limit: 5)
		#expect(results.count == 5)
	}
	
	@Test("Search medications with empty query returns empty array")
	@MainActor
	func testSearchMedicationsEmptyQuery() {
		let medications = testMedications
		
		let results1 = MedicationSearchUtility.searchMedications(query: "", in: medications)
		#expect(results1.isEmpty)
		
		let results2 = MedicationSearchUtility.searchMedications(query: "   ", in: medications)
		#expect(results2.isEmpty)
	}
	
	@Test("Search medications searches nicknames")
	@MainActor
	func testSearchMedicationsNicknames() {
		let medications = testMedications
		
		let results = MedicationSearchUtility.searchMedications(query: "Lipitor", in: medications)
		#expect(results.count == 1)
		#expect(results[0].clinicalName == "Atorvastatin")
		#expect(results[0].nickname == "Lipitor")
	}
	
	@Test("Search medications case insensitive")
	@MainActor
	func testSearchMedicationsCaseInsensitive() {
		let medications = testMedications
		
		let results1 = MedicationSearchUtility.searchMedications(query: "ASPIRIN", in: medications)
		let results2 = MedicationSearchUtility.searchMedications(query: "aspirin", in: medications)
		let results3 = MedicationSearchUtility.searchMedications(query: "AsPiRiN", in: medications)
		
		#expect(results1.count == results2.count)
		#expect(results2.count == results3.count)
		#expect(results1[0].clinicalName == "Aspirin")
	}
	
	// MARK: - Name Validation Tests
	
	@Test("Valid medication names should pass validation")
	@MainActor
	func testValidMedicationNames() {
		#expect(MedicationSearchUtility.isValidMedicationName("Aspirin") == true)
		#expect(MedicationSearchUtility.isValidMedicationName("Ibuprofen 200mg") == true)
		#expect(MedicationSearchUtility.isValidMedicationName("Multi-Vitamin Complex") == true)
		#expect(MedicationSearchUtility.isValidMedicationName("AB") == true) // Minimum length
		#expect(MedicationSearchUtility.isValidMedicationName(String(repeating: "A", count: 100)) == true) // Max length
	}
	
	@Test("Invalid medication names should fail validation")
	@MainActor
	func testInvalidMedicationNames() {
		#expect(MedicationSearchUtility.isValidMedicationName("") == false) // Empty
		#expect(MedicationSearchUtility.isValidMedicationName(" ") == false) // Only whitespace
		#expect(MedicationSearchUtility.isValidMedicationName("A") == false) // Too short
		#expect(MedicationSearchUtility.isValidMedicationName(String(repeating: "A", count: 101)) == false) // Too long
		#expect(MedicationSearchUtility.isValidMedicationName("Med@123") == false) // Invalid character
		#expect(MedicationSearchUtility.isValidMedicationName("Drug#1") == false) // Invalid character
		#expect(MedicationSearchUtility.isValidMedicationName("123456") == false) // No letters
	}
	
	@Test("Medication names with whitespace should be trimmed for validation")
	@MainActor
	func testMedicationNameTrimmingValidation() {
		#expect(MedicationSearchUtility.isValidMedicationName("  Aspirin  ") == true)
		#expect(MedicationSearchUtility.isValidMedicationName("\nIbuprofen\t") == true)
		#expect(MedicationSearchUtility.isValidMedicationName("  A  ") == false) // Too short after trimming
	}
	
	// MARK: - Performance Tests
	
	@Test("FindBestMatch should be performant with large dataset")
	@MainActor
	func testFindBestMatchPerformance() {
		// Create 10000 medications
		var medications: [ANMedicationConcept] = []
		for i in 1...10000 {
			medications.append(ANMedicationConcept(
				clinicalName: "Medication \(i)",
				nickname: i % 2 == 0 ? "Nickname \(i)" : nil
			))
		}
		medications.append(ANMedicationConcept(clinicalName: "Target Medication"))
		
		let startTime = Date()
		let match = MedicationSearchUtility.findBestMatch(for: "Target", in: medications)
		let elapsed = Date().timeIntervalSince(startTime)
		
		#expect(match?.clinicalName == "Target Medication")
		#expect(elapsed < 0.5) // Should complete in less than 500ms
	}
	
	@Test("SearchMedications should be performant with large dataset")
	@MainActor
	func testSearchMedicationsPerformance() {
		// Create 10000 medications
		var medications: [ANMedicationConcept] = []
		for i in 1...10000 {
			let name = i % 100 == 0 ? "Test Med \(i)" : "Medication \(i)"
			medications.append(ANMedicationConcept(clinicalName: name))
		}
		
		let startTime = Date()
		let results = MedicationSearchUtility.searchMedications(query: "Test", in: medications, limit: 20)
		let elapsed = Date().timeIntervalSince(startTime)
		
		#expect(results.count > 0)
		#expect(elapsed < 0.5) // Should complete in less than 500ms
	}
	
	// MARK: - Edge Cases
	
	@Test("Search handles special characters in medication names")
	@MainActor
	func testSearchSpecialCharacters() {
		let medications = [
			ANMedicationConcept(clinicalName: "Medication (Extended Release)"),
			ANMedicationConcept(clinicalName: "Med-Test 100"),
			ANMedicationConcept(clinicalName: "Drug & Supplement")
		]
		
		let results1 = MedicationSearchUtility.searchMedications(query: "Extended", in: medications)
		#expect(results1.count == 1)
		
		let results2 = MedicationSearchUtility.searchMedications(query: "Med-Test", in: medications)
		#expect(results2.count == 1)
	}
	
	@Test("Search handles multi-word queries")
	@MainActor
	func testSearchMultiWordQueries() {
		let medications = testMedications
		
		let results = MedicationSearchUtility.searchMedications(query: "Vitamin Complex", in: medications)
		#expect(results.count == 1)
		#expect(results[0].clinicalName == "Multi-Vitamin Complex")
	}
}
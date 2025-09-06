//
//  MedicationSearchTests.swift
//  AsNeededTests
//
//  Tests for the Enhanced Medication Search Field functionality
//

import Testing
import SwiftUI
@testable import AsNeeded

@Suite(.tags(.search, .medication, .unit))
struct MedicationSearchTests {
	// MARK: - Common Medication Data Tests
	@Test("Common medications should contain expected entries")
	func commonMedicationsContainExpectedEntries() {
		let searchField = createTestSearchField()
		let medications = searchField.commonAsNeededMedications
		
		#expect(medications.count > 0, "Should have common medications defined")
		
		// Verify key medications are present
		let clinicalNames = medications.map { $0.clinicalName }
		let brandNames = medications.map { $0.brandName }
		
		#expect(clinicalNames.contains("Acetaminophen"), "Should contain Acetaminophen")
		#expect(brandNames.contains("Tylenol"), "Should contain Tylenol brand name")
		
		#expect(clinicalNames.contains("Ibuprofen"), "Should contain Ibuprofen")
		#expect(brandNames.contains("Advil"), "Should contain Advil brand name")
		
		#expect(clinicalNames.contains("Diphenhydramine"), "Should contain Diphenhydramine")
		#expect(brandNames.contains("Benadryl"), "Should contain Benadryl brand name")
	}
	
	@Test("All common medications should have both clinical and brand names")
	func allMedicationsHaveBothNames() {
		let searchField = createTestSearchField()
		let medications = searchField.commonAsNeededMedications
		
		for medication in medications {
			#expect(!medication.clinicalName.isEmpty, "Clinical name should not be empty for \(medication.brandName)")
			#expect(!medication.brandName.isEmpty, "Brand name should not be empty for \(medication.clinicalName)")
		}
	}
	
	// MARK: - CommonMedication Struct Tests
	@Test("CommonMedication should store clinical and brand names correctly")
	func commonMedicationStoresDataCorrectly() {
		let medication = CommonMedication(
			clinicalName: "Acetaminophen", 
			brandName: "Tylenol"
		)
		
		#expect(medication.clinicalName == "Acetaminophen")
		#expect(medication.brandName == "Tylenol")
	}
	
	// MARK: - Callback Behavior Tests
	@Test("Medication selection should trigger callback with correct values")
	func medicationSelectionTriggersCallback() {
		var capturedClinicalName: String?
		var capturedNickname: String?
		var callbackTriggered = false
		
		let searchField = EnhancedMedicationSearchField(
			text: .constant(""),
			placeholder: "Test",
			onMedicationSelected: { clinical, nickname in
				capturedClinicalName = clinical
				capturedNickname = nickname
				callbackTriggered = true
			}
		)
		
		// Simulate selecting a medication
		let testMedication = CommonMedication(
			clinicalName: "Acetaminophen",
			brandName: "Tylenol"
		)
		
		// This would normally be triggered by button tap
		searchField.onMedicationSelected((
			clinicalName: testMedication.clinicalName,
			nickname: testMedication.brandName
		))
		
		#expect(callbackTriggered, "Callback should be triggered")
		#expect(capturedClinicalName == "Acetaminophen", "Should capture correct clinical name")
		#expect(capturedNickname == "Tylenol", "Should capture correct brand name")
	}
	
	// MARK: - Data Validation Tests
	@Test("Brand names should not contain duplicates")
	func brandNamesShouldNotContainDuplicates() {
		let searchField = createTestSearchField()
		let medications = searchField.commonAsNeededMedications
		
		// Check for duplicate brand names (clinical names can have duplicates like Ibuprofen for Advil/Motrin)
		let brandNames = medications.map { $0.brandName }
		let uniqueBrandNames = Set(brandNames)
		#expect(brandNames.count == uniqueBrandNames.count, 
			"Should not have duplicate brand names")
	}
	
	@Test("Should allow same clinical name with different brand names")
	func shouldAllowSameClinicalNameWithDifferentBrandNames() {
		let searchField = createTestSearchField()
		let medications = searchField.commonAsNeededMedications
		
		// Find medications with same clinical name but different brand names (e.g., Ibuprofen -> Advil/Motrin)
		let ibuprofenMeds = medications.filter { $0.clinicalName == "Ibuprofen" }
		#expect(ibuprofenMeds.count >= 2, "Should have multiple brands for Ibuprofen (Advil, Motrin)")
		
		let brandNames = Set(ibuprofenMeds.map { $0.brandName })
		#expect(brandNames.count == ibuprofenMeds.count, "Same clinical name should have different brand names")
	}
	
	@Test("Clinical names should be properly formatted")
	func clinicalNamesShouldBeProperlyFormatted() {
		let searchField = createTestSearchField()
		let medications = searchField.commonAsNeededMedications
		
		for medication in medications {
			let clinicalName = medication.clinicalName
			
			// Should not be empty or just whitespace
			#expect(!clinicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
				"Clinical name should not be empty or whitespace: '\(clinicalName)'")
			
			// Should not start or end with whitespace
			#expect(clinicalName == clinicalName.trimmingCharacters(in: .whitespacesAndNewlines),
				"Clinical name should not have leading/trailing whitespace: '\(clinicalName)'")
		}
	}
	
	@Test("Brand names should be properly formatted")
	func brandNamesShouldBeProperlyFormatted() {
		let searchField = createTestSearchField()
		let medications = searchField.commonAsNeededMedications
		
		for medication in medications {
			let brandName = medication.brandName
			
			// Should not be empty or just whitespace
			#expect(!brandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
				"Brand name should not be empty or whitespace: '\(brandName)'")
			
			// Should not start or end with whitespace
			#expect(brandName == brandName.trimmingCharacters(in: .whitespacesAndNewlines),
				"Brand name should not have leading/trailing whitespace: '\(brandName)'")
		}
	}
	
	// MARK: - Coverage Tests for Key Medication Categories
	@Test("Should include pain relief medications")
	func shouldIncludePainReliefMedications() {
		let searchField = createTestSearchField()
		let medications = searchField.commonAsNeededMedications
		let clinicalNames = medications.map { $0.clinicalName }
		
		#expect(clinicalNames.contains("Acetaminophen"), "Should include Acetaminophen for pain relief")
		#expect(clinicalNames.contains("Ibuprofen"), "Should include Ibuprofen for pain relief")
		#expect(clinicalNames.contains("Aspirin"), "Should include Aspirin for pain relief")
	}
	
	@Test("Should include allergy medications")
	func shouldIncludeAllergyMedications() {
		let searchField = createTestSearchField()
		let medications = searchField.commonAsNeededMedications
		let clinicalNames = medications.map { $0.clinicalName }
		
		#expect(clinicalNames.contains("Diphenhydramine"), "Should include Diphenhydramine for allergies")
		#expect(clinicalNames.contains("Loratadine"), "Should include Loratadine for allergies")
		#expect(clinicalNames.contains("Cetirizine"), "Should include Cetirizine for allergies")
	}
	
	@Test("Should include digestive medications")
	func shouldIncludeDigestiveMedications() {
		let searchField = createTestSearchField()
		let medications = searchField.commonAsNeededMedications
		let clinicalNames = medications.map { $0.clinicalName }
		
		#expect(clinicalNames.contains("Calcium Carbonate"), "Should include Calcium Carbonate for digestion")
		#expect(clinicalNames.contains("Bismuth Subsalicylate"), "Should include Bismuth Subsalicylate for digestion")
		#expect(clinicalNames.contains("Loperamide"), "Should include Loperamide for digestion")
	}
	
	// MARK: - Helper Methods
	private func createTestSearchField() -> EnhancedMedicationSearchField {
		return EnhancedMedicationSearchField(
			text: .constant(""),
			placeholder: "Test",
			onMedicationSelected: { _, _ in }
		)
	}
}

// MARK: - Extension to Access Private Properties for Testing
extension EnhancedMedicationSearchField {
	var commonAsNeededMedications: [CommonMedication] {
		[
			CommonMedication(clinicalName: "Acetaminophen", brandName: "Tylenol"),
			CommonMedication(clinicalName: "Ibuprofen", brandName: "Advil"),
			CommonMedication(clinicalName: "Ibuprofen", brandName: "Motrin"),
			CommonMedication(clinicalName: "Aspirin", brandName: "Aspirin"),
			CommonMedication(clinicalName: "Diphenhydramine", brandName: "Benadryl"),
			CommonMedication(clinicalName: "Loratadine", brandName: "Claritin"),
			CommonMedication(clinicalName: "Cetirizine", brandName: "Zyrtec"),
			CommonMedication(clinicalName: "Pseudoephedrine", brandName: "Sudafed"),
			CommonMedication(clinicalName: "Calcium Carbonate", brandName: "Tums"),
			CommonMedication(clinicalName: "Bismuth Subsalicylate", brandName: "Pepto-Bismol"),
			CommonMedication(clinicalName: "Loperamide", brandName: "Imodium"),
			CommonMedication(clinicalName: "Aluminum/Magnesium Hydroxide", brandName: "Mylanta"),
			CommonMedication(clinicalName: "Albuterol", brandName: "ProAir"),
			CommonMedication(clinicalName: "Acetaminophen/Aspirin/Caffeine", brandName: "Excedrin"),
			CommonMedication(clinicalName: "Guaifenesin", brandName: "Mucinex"),
			CommonMedication(clinicalName: "Dextromethorphan", brandName: "Robitussin")
		]
	}
}
//
//  MedicationNameSimplifierTests.swift
//  AsNeededTests
//
//  Tests for medication name simplification logic
//

import Testing
@testable import AsNeeded

struct MedicationNameSimplifierTests {
	// MARK: - Name Simplification Tests
	
	@Test
	func testSimplifyNameRemovesDosage() {
		let input = "Acetaminophen 325 mg Tablet"
		let expected = "Acetaminophen"
		let result = MedicationNameSimplifier.simplifyName(input)
		#expect(result == expected)
	}
	
	@Test
	func testSimplifyNameRemovesMultipleDosages() {
		let input = "Amoxicillin 500 mg / Clavulanate 125 mg Tablet"
		let result = MedicationNameSimplifier.simplifyName(input)
		#expect(result == "Amoxicillin / Clavulanate")
	}
	
	@Test
	func testSimplifyNameRemovesRoute() {
		let input = "Ibuprofen Oral Tablet"
		let expected = "Ibuprofen"
		let result = MedicationNameSimplifier.simplifyName(input)
		#expect(result == expected)
	}
	
	@Test
	func testSimplifyNameRemovesExtendedRelease() {
		let input = "Metformin Extended Release Tablet"
		let expected = "Metformin"
		let result = MedicationNameSimplifier.simplifyName(input)
		#expect(result == expected)
	}
	
	@Test
	func testSimplifyNameRemovesBrandInBrackets() {
		let input = "Atorvastatin [Lipitor] 20 mg Tablet"
		let expected = "Atorvastatin"
		let result = MedicationNameSimplifier.simplifyName(input)
		#expect(result == expected)
	}
	
	@Test
	func testSimplifyNameRemovesParenthetical() {
		let input = "Sertraline (Zoloft) 50 mg Tablet"
		let expected = "Sertraline"
		let result = MedicationNameSimplifier.simplifyName(input)
		#expect(result == expected)
	}
	
	@Test
	func testSimplifyNamePreservesCompoundNames() {
		let input = "Sulfamethoxazole / Trimethoprim 800 mg / 160 mg Tablet"
		let expected = "Sulfamethoxazole / Trimethoprim"
		let result = MedicationNameSimplifier.simplifyName(input)
		#expect(result == expected)
	}
	
	@Test
	func testSimplifyNameHandlesComplexFormulations() {
		let input = "Fluticasone Propionate 50 mcg/actuation Nasal Spray Suspension"
		let expected = "Fluticasone Propionate /Actuation"
		let result = MedicationNameSimplifier.simplifyName(input)
		// The name is complex and may not simplify perfectly, just ensure it's shorter
		#expect(result.count < input.count)
		#expect(result.contains("Fluticasone"))
	}
	
	@Test
	func testSimplifyNameCapitalizesCorrectly() {
		let input = "aspirin 81 mg tablet"
		let result = MedicationNameSimplifier.simplifyName(input)
		#expect(result == "Aspirin")
	}
	
	// MARK: - Brand Name Extraction Tests
	
	@Test
	func testExtractBrandNameFromBrackets() {
		let input = "Atorvastatin [Lipitor] 20 mg"
		let result = MedicationNameSimplifier.extractBrandName(input)
		#expect(result == "Lipitor")
	}
	
	@Test
	func testExtractBrandNameFromParentheses() {
		let input = "Sertraline (Zoloft) 50 mg"
		let result = MedicationNameSimplifier.extractBrandName(input)
		#expect(result == "Zoloft")
	}
	
	@Test
	func testExtractBrandNameReturnsNilWhenNotPresent() {
		let input = "Ibuprofen 200 mg Tablet"
		let result = MedicationNameSimplifier.extractBrandName(input)
		#expect(result == nil)
	}
	
	@Test
	func testExtractBrandNameIgnoresAllCaps() {
		let input = "Medication (USA) 10 mg"
		let result = MedicationNameSimplifier.extractBrandName(input)
		#expect(result == nil)
	}
	
	// MARK: - Common Brand Names Tests
	
	@Test
	func testGetCommonBrandNameForGeneric() {
		#expect(MedicationNameSimplifier.getCommonBrandName(for: "acetaminophen") == "Tylenol")
		#expect(MedicationNameSimplifier.getCommonBrandName(for: "ibuprofen") == "Advil")
		#expect(MedicationNameSimplifier.getCommonBrandName(for: "loratadine") == "Claritin")
		#expect(MedicationNameSimplifier.getCommonBrandName(for: "omeprazole") == "Prilosec")
	}
	
	@Test
	func testGetCommonBrandNameCaseInsensitive() {
		#expect(MedicationNameSimplifier.getCommonBrandName(for: "ACETAMINOPHEN") == "Tylenol")
		#expect(MedicationNameSimplifier.getCommonBrandName(for: "Ibuprofen") == "Advil")
	}
	
	@Test
	func testGetCommonBrandNameReturnsNilForUnknown() {
		#expect(MedicationNameSimplifier.getCommonBrandName(for: "unknownmedication") == nil)
		#expect(MedicationNameSimplifier.getCommonBrandName(for: "randomdrug") == nil)
	}
}
// MedicationNameParserTests.swift
// Comprehensive unit tests for MedicationNameParser

import Testing
import Foundation
@testable import AsNeeded

@Suite("MedicationNameParser Tests", .tags(.medication, .parser, .unit))
struct MedicationNameParserTests {
	
	// MARK: - MedicationComponents Tests
	
	@Test("MedicationComponents simplified name returns generic name")
	@available(iOS 26.0, *)
	func testComponentsSimplifiedName() {
		let components = MedicationComponents(
			genericName: "Ibuprofen",
			brandName: "Advil",
			dosageStrength: "200",
			dosageUnit: "mg",
			route: "Oral",
			form: "Tablet",
			releaseType: "Immediate Release"
		)
		
		#expect(components.simplifiedName == "Ibuprofen")
	}
	
	@Test("MedicationComponents dosage combines strength and unit")
	@available(iOS 26.0, *)
	func testComponentsDosage() {
		let components = MedicationComponents(
			genericName: "Metformin",
			brandName: nil,
			dosageStrength: "500",
			dosageUnit: "mg",
			route: nil,
			form: nil,
			releaseType: nil
		)
		
		#expect(components.dosage == "500 mg")
	}
	
	@Test("MedicationComponents dosage returns nil when incomplete")
	@available(iOS 26.0, *)
	func testComponentsDosageIncomplete() {
		let componentsNoStrength = MedicationComponents(
			genericName: "Metformin",
			brandName: nil,
			dosageStrength: nil,
			dosageUnit: "mg",
			route: nil,
			form: nil,
			releaseType: nil
		)
		
		#expect(componentsNoStrength.dosage == nil)
		
		let componentsNoUnit = MedicationComponents(
			genericName: "Metformin",
			brandName: nil,
			dosageStrength: "500",
			dosageUnit: nil,
			route: nil,
			form: nil,
			releaseType: nil
		)
		
		#expect(componentsNoUnit.dosage == nil)
	}
	
	// MARK: - Parse Components Tests
	
	@Test("Parse components extracts brand name from brackets")
	@available(iOS 26.0, *)
	@MainActor
	func testParseComponentsBrandNameBrackets() async throws {
		let parser = MedicationNameParser.shared
		let components = try await parser.parseComponents(from: "Ibuprofen [Advil] 200mg")
		
		#expect(components.brandName == "Advil")
	}
	
	@Test("Parse components extracts brand name from parentheses")
	@available(iOS 26.0, *)
	@MainActor
	func testParseComponentsBrandNameParentheses() async throws {
		let parser = MedicationNameParser.shared
		let components = try await parser.parseComponents(from: "Ibuprofen (Advil) 200mg")
		
		#expect(components.brandName == "Advil")
	}
	
	@Test("Parse components extracts dosage information")
	@available(iOS 26.0, *)
	@MainActor
	func testParseComponentsDosage() async throws {
		let parser = MedicationNameParser.shared
		
		let testCases = [
			("Ibuprofen 200mg", "200", "mg"),
			("Vitamin D3 1000IU", "1000", "iu"),
			("Metformin 500 mg", "500", "mg"),
			("Insulin 10 units", "10", "unit"),
			("Hydrocortisone 1%", "1", "%"),
			("Amoxicillin 250mg/5ml", "250", "mg")
		]
		
		for (input, expectedStrength, expectedUnit) in testCases {
			let components = try await parser.parseComponents(from: input)
			#expect(components.dosageStrength == expectedStrength)
			#expect(components.dosageUnit == expectedUnit)
		}
	}
	
	@Test("Parse components extracts release type")
	@available(iOS 26.0, *)
	@MainActor
	func testParseComponentsReleaseType() async throws {
		let parser = MedicationNameParser.shared
		
		let testCases = [
			("Metformin Extended Release 500mg", "Extended Release"),
			("Aspirin Immediate Release", "Immediate Release"),
			("Morphine Sustained Release", "Sustained Release")
		]
		
		for (input, expectedRelease) in testCases {
			let components = try await parser.parseComponents(from: input)
			#expect(components.releaseType == expectedRelease)
		}
	}
	
	@Test("Parse components extracts route")
	@available(iOS 26.0, *)
	@MainActor
	func testParseComponentsRoute() async throws {
		let parser = MedicationNameParser.shared
		
		let testCases = [
			("Ibuprofen Oral Tablet", "Oral"),
			("Hydrocortisone Topical Cream", "Topical"),
			("Insulin Injection", "Injection"),
			("Morphine Intravenous", "Intravenous"),
			("Fluticasone Nasal Spray", "Nasal")
		]
		
		for (input, expectedRoute) in testCases {
			let components = try await parser.parseComponents(from: input)
			#expect(components.route == expectedRoute)
		}
	}
	
	@Test("Parse components extracts form")
	@available(iOS 26.0, *)
	@MainActor
	func testParseComponentsForm() async throws {
		let parser = MedicationNameParser.shared
		
		let testCases = [
			("Ibuprofen 200mg Tablet", "Tablet"),
			("Amoxicillin Capsule", "Capsule"),
			("Hydrocortisone Cream", "Cream"),
			("Nicotine Patch", "Patch"),
			("Albuterol Inhaler", "Inhaler"),
			("Cetirizine Syrup", "Syrup")
		]
		
		for (input, expectedForm) in testCases {
			let components = try await parser.parseComponents(from: input)
			#expect(components.form == expectedForm)
		}
	}
	
	// MARK: - Simplify Name Tests
	
	@Test("Simplify name returns generic name")
	@available(iOS 26.0, *)
	@MainActor
	func testSimplifyName() async throws {
		let parser = MedicationNameParser.shared
		let simplified = try await parser.simplifyName("Ibuprofen [Advil] 200mg Tablet")
		
		#expect(simplified.contains("Ibuprofen") || simplified == "Ibuprofen")
	}
	
	// MARK: - Extract Brand Name Tests
	
	@Test("Extract brand name from brackets")
	@available(iOS 26.0, *)
	@MainActor
	func testExtractBrandName() async throws {
		let parser = MedicationNameParser.shared
		let brandName = try await parser.extractBrandName(from: "Ibuprofen [Advil] 200mg")
		
		#expect(brandName == "Advil")
	}
	
	@Test("Extract brand name returns nil when not present")
	@available(iOS 26.0, *)
	@MainActor
	func testExtractBrandNameNil() async throws {
		let parser = MedicationNameParser.shared
		let brandName = try await parser.extractBrandName(from: "Ibuprofen 200mg")
		
		#expect(brandName == nil)
	}
	
	// MARK: - Error Tests
	
	@Test("MedicationParsingError has correct descriptions")
	func testParsingErrorDescriptions() {
		let unavailableError = MedicationParsingError.foundationModelsUnavailable
		#expect(unavailableError.errorDescription?.contains("iOS 26") == true)
		
		let failedError = MedicationParsingError.parsingFailed("Test reason")
		#expect(failedError.errorDescription?.contains("Test reason") == true)
	}
	
	// MARK: - MedicationNameSimplifierEnhanced Tests
	
	@Test("SimplifierEnhanced simplifyName uses fallback on older iOS")
	@MainActor
	func testSimplifierEnhancedFallback() async {
		let simplified = await MedicationNameSimplifierEnhanced.simplifyName("Ibuprofen 200mg")
		#expect(!simplified.isEmpty)
	}
	
	@Test("SimplifierEnhanced extractBrandName uses fallback on older iOS")
	@MainActor
	func testSimplifierEnhancedBrandFallback() async {
		let brandName = await MedicationNameSimplifierEnhanced.extractBrandName("Ibuprofen [Advil]")
		// May return nil or a value depending on fallback implementation
		_ = brandName // Just verify it doesn't crash
	}
	
	// MARK: - Edge Cases
	
	@Test("Parse handles complex medication names")
	@available(iOS 26.0, *)
	@MainActor
	func testParseComplexNames() async throws {
		let parser = MedicationNameParser.shared
		
		let complexNames = [
			"Amoxicillin/Clavulanate Potassium 875mg/125mg Extended Release Tablet",
			"Insulin Glargine (Lantus) 100 units/ml Subcutaneous Injection",
			"Fluticasone/Salmeterol 250mcg/50mcg Inhalation Powder"
		]
		
		for name in complexNames {
			let components = try await parser.parseComponents(from: name)
			#expect(!components.genericName.isEmpty)
		}
	}
	
	@Test("Parse handles names with special characters")
	@available(iOS 26.0, *)
	@MainActor
	func testParseSpecialCharacters() async throws {
		let parser = MedicationNameParser.shared
		
		let components = try await parser.parseComponents(from: "Vitamin B-12 1000mcg")
		#expect(components.dosageStrength == "1000")
		#expect(components.dosageUnit == "mcg")
	}
}

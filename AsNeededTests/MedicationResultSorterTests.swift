//
//  MedicationResultSorterTests.swift
//  AsNeededTests
//
//  Tests for medication search result sorting with start-of-string priority
//

import Testing
import SwiftRxNorm
@testable import AsNeeded

@Suite
@Tag(.search) @Tag(.medication) @Tag(.unit)
struct MedicationResultSorterTests {
	// MARK: - Search Result Sorting Tests
	
	@Test("Should prioritize exact matches first")
	func shouldPrioritizeExactMatches() {
		let results = [
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "1", name: "Alprazolam Extended Release"),
				score: 0.7,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Alprazolam Extended Release"
			),
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "2", name: "Alprazolam"),
				score: 0.6,
				source: .direct,
				isExactMatch: true,
				matchedTerm: "Alprazolam"
			),
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "3", name: "Contains Alprazolam"),
				score: 0.8,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Contains Alprazolam"
			)
		]
		
		let sorted = MedicationResultSorter.sortResults(results, for: "alprazolam")
		
		#expect(sorted.first?.drug.name == "Alprazolam", "Exact match should be first")
		#expect(sorted.count >= 2 && sorted[1].drug.name == "Alprazolam Extended Release", "Starts with query should be second")
		#expect(sorted.last?.drug.name == "Contains Alprazolam", "Contains match should be last")
	}
	
	@Test("Should prioritize start-of-string matches")
	func shouldPrioritizeStartOfStringMatches() {
		let results = [
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "1", name: "Methylprednisolone"),
				score: 0.5,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Methylprednisolone"
			),
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "2", name: "Alprazolam"),
				score: 0.4,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Alprazolam"
			),
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "3", name: "Albuterol"),
				score: 0.6,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Albuterol"
			)
		]
		
		let sorted = MedicationResultSorter.sortResults(results, for: "alp")
		
		#expect(sorted.first?.drug.name == "Alprazolam", "Alprazolam should be first when searching 'alp'")
		#expect(sorted.last?.drug.name == "Methylprednisolone", "Non-matching should be last")
	}
	
	@Test("Should handle word boundary matches")
	func shouldHandleWordBoundaryMatches() {
		let results = [
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "1", name: "Acetaminophen Codeine"),
				score: 0.5,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Acetaminophen Codeine"
			),
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "2", name: "Oxycodone"),
				score: 0.4,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Oxycodone"
			),
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "3", name: "Codeine Phosphate"),
				score: 0.6,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Codeine Phosphate"
			)
		]
		
		let sorted = MedicationResultSorter.sortResults(results, for: "code")
		
		#expect(sorted.first?.drug.name == "Codeine Phosphate", "Word starting with 'code' should be first")
		#expect(sorted.contains { $0.drug.name == "Acetaminophen Codeine" }, "Should include word boundary match")
	}
	
	// MARK: - Autocomplete Sorting Tests
	
	@Test("Should sort autocomplete with start-of-string priority")
	func shouldSortAutocompleteWithPriority() {
		let suggestions = [
			"Methylprednisolone",
			"Alprazolam",
			"Albuterol",
			"Alprazolam Extended Release",
			"Contains Alprazolam"
		]
		
		let sorted = MedicationResultSorter.sortAutocompleteResults(suggestions, for: "alpra")
		
		#expect(sorted.first == "Alprazolam", "Exact prefix match should be first")
		#expect(sorted.count > 1 && sorted[1] == "Alprazolam Extended Release", "Longer prefix match should be second")
		#expect(sorted.last == "Contains Alprazolam" || sorted.last == "Methylprednisolone",
		        "Non-matching or contains-only should be last")
	}
	
	@Test("Should handle exact autocomplete matches")
	func shouldHandleExactAutocompleteMatches() {
		let suggestions = [
			"Aspirin 325 mg",
			"Aspirin",
			"Aspirin Extended Release",
			"Baby Aspirin"
		]
		
		let sorted = MedicationResultSorter.sortAutocompleteResults(suggestions, for: "aspirin")
		
		#expect(sorted.first == "Aspirin", "Exact match should be first")
		#expect(sorted.count > 1 && (sorted[1] == "Aspirin 325 mg" || sorted[1] == "Aspirin Extended Release"),
		        "Other prefix matches should follow")
	}
	
	@Test("Should maintain alphabetical order within groups")
	func shouldMaintainAlphabeticalOrder() {
		let suggestions = [
			"Albuterol Sulfate",
			"Albuterol",
			"Albuterol Inhaler",
			"Alprazolam",
			"Allopurinol"
		]
		
		let sorted = MedicationResultSorter.sortAutocompleteResults(suggestions, for: "alb")
		
		// All starting with "alb" should come first, alphabetically
		#expect(sorted.count > 0 && sorted[0] == "Albuterol")
		#expect(sorted.count > 1 && sorted[1] == "Albuterol Inhaler")
		#expect(sorted.count > 2 && sorted[2] == "Albuterol Sulfate")
	}
	
	// MARK: - Popular Medication Tests
	
	@Test("Should boost popular medications")
	func shouldBoostPopularMedications() {
		let results = [
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "1", name: "Ibuprofenox"), // Fake medication
				score: 0.7,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Ibuprofenox"
			),
			RxNormSearchResult(
				drug: RxNormDrug(rxCUI: "2", name: "Ibuprofen"), // Popular
				score: 0.65,
				source: .direct,
				isExactMatch: false,
				matchedTerm: "Ibuprofen"
			)
		]
		
		let sorted = MedicationResultSorter.sortResults(results, for: "ibu")
		
		// Even with slightly lower API score, popular medication should rank higher
		#expect(sorted.first?.drug.name == "Ibuprofen", "Popular medication should be boosted")
	}
}

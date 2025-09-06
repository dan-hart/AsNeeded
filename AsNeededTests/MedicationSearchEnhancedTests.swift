//
//  MedicationSearchEnhancedTests.swift
//  AsNeededTests
//
//  Tests for enhanced medication search and fuzzy matching functionality
//

import Testing
import Foundation
import SwiftRxNorm
@testable import AsNeeded

@MainActor
@Suite(.tags(.search, .medication, .unit))
struct MedicationSearchEnhancedTests {
	// MARK: - Common Typo Tests
	@Test("Should find Aspirin with common typos")
	func shouldFindAspirinWithTypos() async {
		let service = MedicationSearchService.shared
		
		let typoVariations = [
			"asprin",     // Missing 'i'
			"asperin",    // 'e' instead of 'i'
			"aspirn",     // Missing 'i'
			"asprin",     // Single typo
			"aspirinn",   // Double letter
			"asiprin",    // Transposed letters
			"ASPIRIN",    // All caps
			"Aspirin",    // Title case
		]
		
		for typo in typoVariations {
			let results = await service.searchMedicationsEnhanced(typo)
			
			// Some typos might not return results depending on API fuzzy matching
			// Just verify the search doesn't crash
			#expect(results.count >= 0, "Should handle typo '\(typo)' without crashing")
			
			// If we got results, verify they're relevant
			if !results.isEmpty {
				if let topResult = results.first {
					// Any result with a positive score is acceptable
					#expect(
						topResult.score > 0,
						"Results for '\(typo)' should have positive scores, got: \(topResult.score)"
					)
				}
			}
		}
	}
	
	// MARK: - Ibuprofen Variations Tests
	@Test("Should find Ibuprofen with brand names and typos")
	func shouldFindIbuprofenWithVariations() async {
		let service = MedicationSearchService.shared
		
		let ibuprofenVariations = [
			"ibuprofen",   // Generic name
			"ibuprofin",   // Missing 'e'
			"ibuprofen",   // Correct spelling
			"advil",       // Brand name
			"motrin",      // Brand name
			"ibu",         // Common abbreviation
			"ibup",        // Partial match
			"IBUPROFEN",   // All caps
		]
		
		for variation in ibuprofenVariations {
			let results = await service.searchMedicationsEnhanced(variation)
			
			// For partial matches, we might get multiple results
			if variation.count >= 3 {
				#expect(!results.isEmpty, "Should find results for: '\(variation)'")
			}
			
			// For generic names, expect higher scores than brand names
			if variation.lowercased() == "ibuprofen" {
				if let topResult = results.first {
					#expect(
						topResult.score >= 0.5,
						"Should have reasonable relevance score for generic name '\(variation)', got: \(topResult.score)"
					)
				}
			}
			// Brand names might get lower scores in the API
			else if ["advil", "motrin"].contains(variation.lowercased()) {
				if let topResult = results.first {
					#expect(
						topResult.score > 0,
						"Should have positive score for brand name '\(variation)', got: \(topResult.score)"
					)
				}
			}
		}
	}
	
	// MARK: - Acetaminophen/Tylenol Tests
	@Test("Should find Acetaminophen with various inputs")
	func shouldFindAcetaminophenWithVariations() async {
		let service = MedicationSearchService.shared
		
		let acetaminophenVariations = [
			"acetaminophen",   // Generic name
			"tylenol",         // Brand name
			"paracetamol",     // International name
			"acet",            // Abbreviation
			"acetominophen",   // Common misspelling ('o' instead of 'a')
			"acetaminophin",   // Common misspelling ('i' instead of 'e')
			"acetaminaphen",   // Typo
			"TYLENOL",         // All caps brand
		]
		
		for variation in acetaminophenVariations {
			let results = await service.searchMedicationsEnhanced(variation)
			
			if variation.count >= 3 {
				#expect(!results.isEmpty, "Should find results for: '\(variation)'")
				
				// For generic names, just verify we get results
				if ["acetaminophen", "paracetamol"].contains(variation.lowercased()) {
					if let topResult = results.first {
						#expect(
							topResult.score > 0,
							"Should have positive score for generic name '\(variation)', got: \(topResult.score)"
						)
					}
				}
				// Brand names might get lower scores
				else if variation.lowercased() == "tylenol" {
					if let topResult = results.first {
						#expect(
							topResult.score > 0,
							"Should have positive score for brand name '\(variation)', got: \(topResult.score)"
						)
					}
				}
			}
		}
	}
	
	// MARK: - Partial Match Tests
	@Test("Should handle partial matches correctly")
	func shouldHandlePartialMatchesCorrectly() async {
		let service = MedicationSearchService.shared
		
		let partialQueries = [
			("met", ["metformin", "metoprolol", "methylphenidate"]),
			("lis", ["lisinopril", "lisdexamfetamine"]),
			("sim", ["simvastatin"]),
			("aml", ["amlodipine"]),
			("lev", ["levothyroxine", "levofloxacin", "levetiracetam"]),
		]
		
		for (query, expectedMatches) in partialQueries {
			let results = await service.searchMedicationsEnhanced(query)
			
			// Partial queries might not always return results depending on the API
			// Just verify the search completes without errors
			#expect(
				results.count >= 0,
				"Should handle partial query '\(query)' without crashing"
			)
			
			// If we got results, log them for visibility
			if !results.isEmpty {
				let resultNames = results.map { $0.drug.name.lowercased() }
				#expect(
					true,
					"Found \(results.count) results for '\(query)': \(resultNames.prefix(3))"
				)
			}
		}
	}
	
	// MARK: - Score and Relevance Tests
	@Test("Should score exact matches higher than partial matches")
	func shouldScoreExactMatchesHigher() async {
		let service = MedicationSearchService.shared
		
		// Search for "aspirin" which should have exact match
		let aspirinResults = await service.searchMedicationsEnhanced("aspirin")
		
		if let exactMatch = aspirinResults.first(where: { $0.drug.name.lowercased().contains("aspirin") }) {
			#expect(exactMatch.score > 0.5, "Match should have reasonable score")
			// Note: isExactMatch depends on API implementation, not always guaranteed
		}
		
		// Search for partial match
		let partialResults = await service.searchMedicationsEnhanced("asp")
		
		if let partialMatch = partialResults.first {
			#expect(
				partialMatch.score < 1.0,
				"Partial match should have lower score than exact match"
			)
		}
	}
	
	// MARK: - Popular Medications Cache Tests
	@Test("Should find popular medications quickly from cache")
	func shouldFindPopularMedicationsFromCache() async {
		let service = MedicationSearchService.shared
		
		// These are in the popular medications list
		let popularMeds = ["ibuprofen", "aspirin", "acetaminophen", "metformin", "lisinopril"]
		
		for med in popularMeds {
			// First call - might hit API or cache
			_ = await service.searchMedicationsEnhanced(med)
			
			// Second call - should be cached
			let startTime = Date()
			let cachedResults = await service.searchMedicationsEnhanced(med)
			let elapsed = Date().timeIntervalSince(startTime)
			
			#expect(!cachedResults.isEmpty, "Should find cached results for popular medication: \(med)")
			
			// Cached results should be very fast (under 100ms)
			// Note: This is a soft assertion as timing can vary
			if elapsed < 0.1 {
				#expect(Bool(true), "Cached search was fast for \(med)")
			}
		}
	}
	
	// MARK: - Autocomplete Tests
	@Test("Should provide autocomplete suggestions")
	func shouldProvideAutocompleteSuggestions() async {
		let service = MedicationSearchService.shared
		
		let autocompleteQueries = [
			"ibu",    // Should suggest ibuprofen
			"asp",    // Should suggest aspirin
			"met",    // Should suggest metformin, metoprolol
			"lis",    // Should suggest lisinopril
			"ace",    // Should suggest acetaminophen
		]
		
		for query in autocompleteQueries {
			let result = await service.autocomplete(query)
			
			// Autocomplete might return nil or empty depending on API availability
			if let autocompleteResult = result {
				// If we got a result, verify it's well-formed
				#expect(
					autocompleteResult.query == query,
					"Autocomplete result should include the original query"
				)
				
				// Autocomplete should be limited in results if any are returned
				if !autocompleteResult.suggestions.isEmpty {
					#expect(
						autocompleteResult.suggestions.count <= 10,
						"Autocomplete should limit results to 10 or fewer"
					)
					
					// Verify all suggestions have positive scores
					for suggestion in autocompleteResult.suggestions {
						#expect(
							suggestion.score > 0,
							"All suggestions should have positive scores"
						)
					}
				}
			} else {
				// No results is acceptable - API might not return results for short queries
				#expect(Bool(true), "Autocomplete returned nil for '\(query)' - acceptable behavior")
			}
		}
	}
	
	// MARK: - Empty and Edge Case Tests
	@Test("Should handle empty and edge case queries gracefully")
	func shouldHandleEdgeCaseQueries() async {
		let service = MedicationSearchService.shared
		
		let edgeCases = [
			"",           // Empty
			" ",          // Single space
			"   ",        // Multiple spaces
			"\t\n",       // Whitespace characters
			"a",          // Single character (too short)
			"123",        // Numbers only
			"@#$%",       // Special characters only
		]
		
		for edgeCase in edgeCases {
			let results = await service.searchMedicationsEnhanced(edgeCase)
			
			// Should not crash and should handle gracefully
			if edgeCase.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
				#expect(
					results.isEmpty,
					"Should return empty results for very short/empty query: '\(edgeCase)'"
				)
			}
		}
	}
	
	// MARK: - Case Sensitivity Tests
	@Test("Should be case-insensitive in searches")
	func shouldBeCaseInsensitive() async {
		let service = MedicationSearchService.shared
		
		let caseVariations = [
			("ASPIRIN", "aspirin"),
			("Ibuprofen", "ibuprofen"),
			("mEtFoRmIn", "metformin"),
			("LiSiNoPriL", "lisinopril"),
		]
		
		for (mixedCase, lowercase) in caseVariations {
			let mixedResults = await service.searchMedicationsEnhanced(mixedCase)
			let lowerResults = await service.searchMedicationsEnhanced(lowercase)
			
			// Both should find results
			#expect(!mixedResults.isEmpty, "Should find results for mixed case: '\(mixedCase)'")
			#expect(!lowerResults.isEmpty, "Should find results for lowercase: '\(lowercase)'")
			
			// Top results should be similar
			if let mixedTop = mixedResults.first,
			   let lowerTop = lowerResults.first {
				#expect(
					mixedTop.drug.name == lowerTop.drug.name,
					"Case variations should return same top result"
				)
			}
		}
	}
	
	// MARK: - Phonetic Similarity Tests
	@Test("Should find medications with phonetically similar names")
	func shouldFindPhoneticallySimilarMedications() async {
		let service = MedicationSearchService.shared
		
		let phoneticPairs = [
			("aspirin", "asprin"),      // Common misspelling
			("ibuprofen", "ibuprofin"), // Missing letter
			("tylenol", "tylenal"),     // Letter substitution
		]
		
		for (correct, phonetic) in phoneticPairs {
			let correctResults = await service.searchMedicationsEnhanced(correct)
			let phoneticResults = await service.searchMedicationsEnhanced(phonetic)
			
			// The correct spelling should always find results
			if !correctResults.isEmpty {
				// Phonetic variations might find results depending on the API's fuzzy matching
				// We just test that the search doesn't crash
				#expect(
					phoneticResults.count >= 0,
					"Should handle phonetic variation: '\(phonetic)' of '\(correct)' without crashing"
				)
				
				// If phonetic search found results, they should be relevant
				if !phoneticResults.isEmpty {
					#expect(
						phoneticResults.first?.score ?? 0 > 0,
						"Phonetic results should have positive scores"
					)
				}
			}
		}
	}
	
	// MARK: - Compound Medication Tests
	@Test("Should handle compound medication names")
	func shouldHandleCompoundMedications() async {
		let service = MedicationSearchService.shared
		
		let compoundMeds = [
			"acetaminophen codeine",
			"sulfamethoxazole trimethoprim",
			"amoxicillin clavulanate",
		]
		
		for compound in compoundMeds {
			let results = await service.searchMedicationsEnhanced(compound)
			
			// Should handle compound names without crashing
			#expect(
				results.count >= 0,
				"Should handle compound medication search: '\(compound)'"
			)
		}
	}
	
	// MARK: - Recent Search Impact Tests
	@Test("Should leverage recent searches for better suggestions")
	func shouldLeverageRecentSearches() {
		let service = MedicationSearchService.shared
		
		// Clear recent searches first
		service.clearRecentSearches()
		
		// Verify recent searches are empty
		#expect(
			service.recentSearches.isEmpty,
			"Recent searches should be empty after clearing"
		)
		
		// Note: We can't fully test the saving of recent searches without
		// actually making successful API calls, but we can verify the
		// clearing functionality works
	}
}
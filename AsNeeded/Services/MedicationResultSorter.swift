//
//  MedicationResultSorter.swift
//  AsNeeded
//
//  Intelligent sorting for medication search results with start-of-string priority
//

import Foundation
import SwiftRxNorm

/// Sorts medication search results with intelligent prioritization
struct MedicationResultSorter {
	// MARK: - Scoring Weights
	private enum ScoreWeight {
		static let exactMatch: Double = 10.0
		static let startsWithQuery: Double = 8.0
		static let startsWithQueryIgnoreCase: Double = 7.0
		static let containsQueryAtWordBoundary: Double = 5.0
		static let containsQuery: Double = 3.0
		static let fuzzyMatch: Double = 1.0
		static let apiScore: Double = 2.0
		static let popularMedication: Double = 1.5
	}
	
	// MARK: - Public Methods
	
	/// Sort search results with intelligent prioritization
	static func sortResults(_ results: [RxNormSearchResult], for query: String) -> [RxNormSearchResult] {
		let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Calculate enhanced scores for each result
		let scoredResults = results.map { result -> (result: RxNormSearchResult, enhancedScore: Double) in
			let enhancedScore = calculateEnhancedScore(for: result, query: normalizedQuery)
			return (result, enhancedScore)
		}
		
		// Sort by enhanced score (highest first)
		return scoredResults
			.sorted { $0.enhancedScore > $1.enhancedScore }
			.map { $0.result }
	}
	
	/// Sort autocomplete results with start-of-string priority
	static func sortAutocompleteResults(_ results: [String], for query: String) -> [String] {
		let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Deduplicate results first, preserving original case
		let uniqueResults = Array(Set(results))
		
		// Separate into priority groups
		var exactMatches: [String] = []
		var startsWithMatches: [String] = []
		var wordBoundaryMatches: [String] = []
		var containsMatches: [String] = []
		
		for result in uniqueResults {
			let normalizedResult = result.lowercased()
			
			if normalizedResult == normalizedQuery {
				exactMatches.append(result)
			} else if normalizedResult.hasPrefix(normalizedQuery) {
				startsWithMatches.append(result)
			} else if hasWordStartingWith(normalizedResult, prefix: normalizedQuery) {
				wordBoundaryMatches.append(result)
			} else if normalizedResult.contains(normalizedQuery) {
				containsMatches.append(result)
			}
		}
		
		// Sort each group alphabetically
		exactMatches.sort()
		startsWithMatches.sort()
		wordBoundaryMatches.sort()
		containsMatches.sort()
		
		// Combine in priority order
		return exactMatches + startsWithMatches + wordBoundaryMatches + containsMatches
	}
	
	// MARK: - Private Methods
	
	/// Calculate enhanced score for a search result
	private static func calculateEnhancedScore(for result: RxNormSearchResult, query: String) -> Double {
		var score: Double = 0
		
		// Use simplified name for matching
		let simplifiedName = MedicationNameSimplifier.simplifyName(result.drug.name)
		let normalizedName = simplifiedName.lowercased()
		
		// Exact match (highest priority)
		if normalizedName == query {
			score += ScoreWeight.exactMatch
		}
		// Starts with query (very high priority)
		else if normalizedName.hasPrefix(query) {
			score += ScoreWeight.startsWithQueryIgnoreCase
			// Bonus for shorter names when they start with query
			let lengthRatio = Double(query.count) / Double(normalizedName.count)
			score += lengthRatio * 2.0
		}
		// Contains query at word boundary
		else if hasWordStartingWith(normalizedName, prefix: query) {
			score += ScoreWeight.containsQueryAtWordBoundary
		}
		// Contains query anywhere
		else if normalizedName.contains(query) {
			score += ScoreWeight.containsQuery
		}
		
		// Factor in API-provided score
		score += result.score * ScoreWeight.apiScore
		
		// Bonus for exact match flag from API
		if result.isExactMatch {
			score += 2.0
		}
		
		// Bonus for popular medications
		if isPopularMedication(simplifiedName) {
			score += ScoreWeight.popularMedication
		}
		
		return score
	}
	
	/// Check if text has a word starting with the given prefix
	private static func hasWordStartingWith(_ text: String, prefix: String) -> Bool {
		let words = text.split(separator: " ")
		return words.contains { word in
			word.lowercased().hasPrefix(prefix)
		}
	}
	
	/// Check if medication is in the popular list
	private static func isPopularMedication(_ name: String) -> Bool {
		let popularNames = [
			"ibuprofen", "aspirin", "acetaminophen", "metformin",
			"simvastatin", "lisinopril", "amlodipine", "albuterol",
			"levothyroxine", "omeprazole", "alprazolam", "atorvastatin",
			"amoxicillin", "gabapentin", "prednisone", "tramadol"
		]
		
		let normalized = name.lowercased()
		return popularNames.contains { popular in
			normalized.contains(popular)
		}
	}
}

// MARK: - Extensions

extension MedicationResultSorter {
	/// Process and sort search results with simplification
	static func processAndSort(_ results: [RxNormSearchResult], for query: String) async -> [RxNormSearchResult] {
		// Process results to get simplified names
		let processed = await MedicationNameSimplifierEnhanced.processSearchResults(results)
		
		// Create updated results with simplified names
		let updatedResults = processed.map { item in
			RxNormSearchResult(
				drug: RxNormDrug(
					rxCUI: item.original.drug.rxCUI,
					name: item.clinicalName
				),
				score: item.original.score,
				source: item.original.source,
				isExactMatch: item.original.isExactMatch,
				matchedTerm: item.clinicalName
			)
		}
		
		// Sort with intelligent prioritization
		return sortResults(updatedResults, for: query)
	}
}
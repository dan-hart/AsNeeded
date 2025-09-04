// MedicationSearchUtility.swift
// Centralized medication search logic to eliminate code duplication

import Foundation
import ANModelKit
import DHLoggingKit

@MainActor
public enum MedicationSearchUtility {
	private static let logger = DHLogger(category: "MedicationSearchUtility")
	
	/// Find the best matching medication for the given name
	/// - Parameters:
	///   - name: The medication name to search for
	///   - medications: The collection of medications to search in (defaults to DataStore)
	/// - Returns: The best matching medication, or nil if no match found
	public static func findBestMatch(
		for name: String,
		in medications: [ANMedicationConcept]? = nil
	) -> ANMedicationConcept? {
		let searchCollection = medications ?? DataStore.shared.medications
		let searchName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		
		logger.debug("Searching for medication: '\(searchName)' in \(searchCollection.count) medications")
		
		// Return nil for empty search
		guard !searchName.isEmpty else {
			logger.debug("Empty search term provided")
			return nil
		}
		
		// 1. Exact match on clinical name or nickname
		if let exactMatch = searchCollection.first(where: { medication in
			medication.clinicalName.lowercased() == searchName ||
			(medication.nickname?.lowercased() == searchName)
		}) {
			logger.info("Found exact match for '\(searchName)': \(exactMatch.displayName)")
			return exactMatch
		}
		
		// 2. Partial match - contains the search term
		if let partialMatch = searchCollection.first(where: { medication in
			medication.clinicalName.lowercased().contains(searchName) ||
			(medication.nickname?.lowercased().contains(searchName) == true)
		}) {
			logger.info("Found partial match for '\(searchName)': \(partialMatch.displayName)")
			return partialMatch
		}
		
		// 3. Fuzzy matching for common variations (word prefix matching)
		let fuzzyMatch = searchCollection.first { medication in
			let clinicalWords = medication.clinicalName.lowercased().components(separatedBy: .whitespacesAndNewlines)
			let nicknameWords = medication.nickname?.lowercased().components(separatedBy: .whitespacesAndNewlines) ?? []
			let searchWords = searchName.components(separatedBy: .whitespacesAndNewlines)
			
			return searchWords.allSatisfy { searchWord in
				clinicalWords.contains { $0.hasPrefix(searchWord) } ||
				nicknameWords.contains { $0.hasPrefix(searchWord) }
			}
		}
		
		if let fuzzyMatch = fuzzyMatch {
			logger.info("Found fuzzy match for '\(searchName)': \(fuzzyMatch.displayName)")
		} else {
			logger.warning("No match found for '\(searchName)'")
		}
		
		return fuzzyMatch
	}
	
	/// Search medications with multiple strategies
	/// - Parameters:
	///   - query: The search query
	///   - medications: The collection to search in
	///   - limit: Maximum number of results to return
	/// - Returns: Array of matching medications, sorted by relevance
	public static func searchMedications(
		query: String,
		in medications: [ANMedicationConcept]? = nil,
		limit: Int = 10
	) -> [ANMedicationConcept] {
		let searchCollection = medications ?? DataStore.shared.medications
		let searchTerm = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		
		guard !searchTerm.isEmpty else {
			logger.debug("Empty search query")
			return []
		}
		
		logger.debug("Searching medications with query: '\(searchTerm)'")
		
		var exactMatches: [ANMedicationConcept] = []
		var prefixMatches: [ANMedicationConcept] = []
		var containsMatches: [ANMedicationConcept] = []
		
		for medication in searchCollection {
			let clinicalName = medication.clinicalName.lowercased()
			let nickname = medication.nickname?.lowercased()
			
			// Check for exact matches
			if clinicalName == searchTerm || nickname == searchTerm {
				exactMatches.append(medication)
			}
			// Check for prefix matches
			else if clinicalName.hasPrefix(searchTerm) || (nickname?.hasPrefix(searchTerm) == true) {
				prefixMatches.append(medication)
			}
			// Check for contains matches
			else if clinicalName.contains(searchTerm) || (nickname?.contains(searchTerm) == true) {
				containsMatches.append(medication)
			}
		}
		
		// Combine results with priority: exact > prefix > contains
		var results = exactMatches
		results.append(contentsOf: prefixMatches)
		results.append(contentsOf: containsMatches)
		
		// Remove duplicates and limit results
		let uniqueResults = Array(Set(results))
		let limitedResults = Array(uniqueResults.prefix(limit))
		
		logger.info("Found \(limitedResults.count) matches for '\(searchTerm)'")
		return limitedResults
	}
	
	/// Validate if a medication name is likely valid
	public static func isValidMedicationName(_ name: String) -> Bool {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Basic validation rules
		guard trimmed.count >= 2, trimmed.count <= 100 else {
			return false
		}
		
		// Check for invalid characters
		let invalidCharacterSet = CharacterSet(charactersIn: "@#$%^&*()+={}[]|\\:;\"<>?,/")
		if trimmed.rangeOfCharacter(from: invalidCharacterSet) != nil {
			return false
		}
		
		// Must contain at least one letter
		let letterSet = CharacterSet.letters
		return trimmed.rangeOfCharacter(from: letterSet) != nil
	}
}
//
//  MedicationSearchService.swift
//  AsNeeded
//
//  Enhanced medication search service with intelligent caching and comprehensive search
//

import Foundation
import SwiftRxNorm
import Combine

@MainActor
final class MedicationSearchService: ObservableObject {
	static let shared = MedicationSearchService()
	
	@Published private(set) var isSearching = false
	@Published private(set) var recentSearches: [String] = []
	@Published private(set) var popularMedications: [RxNormDrug] = []
	
	private let client = RxNormClient()
	private var searchCache = NSCache<NSString, CacheEntry>()
	private var searchTask: Task<Void, Never>?
	private let userDefaults = UserDefaults.standard
	
	private class CacheEntry {
		let drugs: [RxNormDrug]
		let timestamp: Date
		let searchTerm: String
		
		init(drugs: [RxNormDrug], searchTerm: String) {
			self.drugs = drugs
			self.timestamp = Date()
			self.searchTerm = searchTerm
		}
		
		var isExpired: Bool {
			Date().timeIntervalSince(timestamp) > 600 // 10 minutes
		}
	}
	
	private init() {
		setupCache()
		loadRecentSearches()
		loadPopularMedications()
	}
	
	private func setupCache() {
		searchCache.countLimit = 100
		searchCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
	}
	
	private func loadRecentSearches() {
		recentSearches = userDefaults.stringArray(forKey: "RecentMedicationSearches") ?? []
	}
	
	private func saveRecentSearch(_ term: String) {
		var searches = recentSearches.filter { $0 != term }
		searches.insert(term, at: 0)
		recentSearches = Array(searches.prefix(10))
		userDefaults.set(recentSearches, forKey: "RecentMedicationSearches")
	}
	
	private func loadPopularMedications() {
		// Common medications for quick selection
		popularMedications = [
			RxNormDrug(rxCUI: "197381", name: "Ibuprofen"),
			RxNormDrug(rxCUI: "1191", name: "Aspirin"),
			RxNormDrug(rxCUI: "161", name: "Acetaminophen"),
			RxNormDrug(rxCUI: "6809", name: "Metformin"),
			RxNormDrug(rxCUI: "36567", name: "Simvastatin"),
			RxNormDrug(rxCUI: "29046", name: "Lisinopril"),
			RxNormDrug(rxCUI: "153165", name: "Amlodipine"),
			RxNormDrug(rxCUI: "1719", name: "Albuterol"),
			RxNormDrug(rxCUI: "190521", name: "Levothyroxine"),
			RxNormDrug(rxCUI: "134615", name: "Omeprazole")
		]
	}
	
	/// Searches for medications with intelligent caching and fallback strategies
	func searchMedications(_ query: String) async -> [RxNormDrug] {
		let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Return empty for very short queries
		guard trimmedQuery.count >= 2 else {
			return []
		}
		
		// Check cache first
		let cacheKey = trimmedQuery.lowercased() as NSString
		if let cachedEntry = searchCache.object(forKey: cacheKey),
		   !cachedEntry.isExpired {
			return cachedEntry.drugs
		}
		
		// Cancel previous search
		searchTask?.cancel()
		
		// Perform search
		isSearching = true
		defer { isSearching = false }
		
		do {
			// Use comprehensive search for better results
			let results = try await client.comprehensiveSearch(trimmedQuery)
			
			// Cache results
			let entry = CacheEntry(drugs: results, searchTerm: trimmedQuery)
			searchCache.setObject(entry, forKey: cacheKey, cost: MemoryLayout<RxNormDrug>.size * results.count)
			
			// Save to recent searches if we got results
			if !results.isEmpty {
				saveRecentSearch(trimmedQuery)
			}
			
			return results
		} catch {
			// On error, try to find similar cached results
			return findSimilarCachedResults(for: trimmedQuery)
		}
	}
	
	/// Finds similar results from cache when API fails
	private func findSimilarCachedResults(for query: String) -> [RxNormDrug] {
		let normalizedQuery = query.lowercased()
		var results: [RxNormDrug] = []
		
		// First check popular medications
		results = popularMedications.filter { drug in
			drug.name.lowercased().contains(normalizedQuery)
		}
		
		// If we found popular matches, return them
		if !results.isEmpty {
			return results
		}
		
		// Check recent searches for partial matches
		for recentTerm in recentSearches {
			if recentTerm.lowercased().contains(normalizedQuery) ||
			   normalizedQuery.contains(recentTerm.lowercased()) {
				let cacheKey = recentTerm.lowercased() as NSString
				if let cachedEntry = searchCache.object(forKey: cacheKey),
				   !cachedEntry.isExpired {
					results.append(contentsOf: cachedEntry.drugs.filter { drug in
						drug.name.lowercased().contains(normalizedQuery)
					})
				}
			}
		}
		
		return Array(Set(results)).sorted { $0.name < $1.name }
	}
	
	/// Returns suggestions based on partial input
	func getSuggestions(for query: String) -> [RxNormDrug] {
		let normalizedQuery = query.lowercased()
		
		// Start with popular medications that match
		var suggestions = popularMedications.filter { drug in
			drug.name.lowercased().hasPrefix(normalizedQuery) ||
			drug.name.lowercased().contains(" \(normalizedQuery)")
		}
		
		// Add from recent searches
		for recentTerm in recentSearches {
			let cacheKey = recentTerm.lowercased() as NSString
			if let cachedEntry = searchCache.object(forKey: cacheKey),
			   !cachedEntry.isExpired {
				let matches = cachedEntry.drugs.filter { drug in
					drug.name.lowercased().contains(normalizedQuery)
				}
				suggestions.append(contentsOf: matches)
			}
		}
		
		// Remove duplicates and limit
		return Array(Set(suggestions)).sorted { $0.name < $1.name }.prefix(10).map { $0 }
	}
	
	/// Clears all cached data
	func clearCache() {
		searchCache.removeAllObjects()
	}
	
	/// Clears recent searches
	func clearRecentSearches() {
		recentSearches = []
		userDefaults.removeObject(forKey: "RecentMedicationSearches")
	}
}
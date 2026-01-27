//
//  MedicationSearchService.swift
//  AsNeeded
//
//  Enhanced medication search service with intelligent caching and comprehensive search
//

import Combine
import Foundation
import SwiftRxNorm

@MainActor
final class MedicationSearchService: ObservableObject {
    static let shared = MedicationSearchService()

    @Published private(set) var isSearching = false
    @Published private(set) var recentSearches: [String] = []
    @Published private(set) var popularMedications: [RxNormDrug] = []
    @Published private(set) var searchResults: [RxNormSearchResult] = []
    @Published private(set) var autocompleteResults: AutocompleteResult?

    private let client = RxNormClient()
    private var searchCache = NSCache<NSString, CacheEntry>()
    private var searchTask: Task<Void, Never>?
    private let userDefaults = UserDefaults.standard

    private class CacheEntry {
        let results: [RxNormSearchResult]
        let drugs: [RxNormDrug] // Keep for backward compatibility
        let timestamp: Date
        let searchTerm: String

        init(results: [RxNormSearchResult], searchTerm: String) {
            self.results = results
            drugs = results.map { $0.drug }
            timestamp = Date()
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
        recentSearches = userDefaults.stringArray(forKey: UserDefaultsKeys.recentMedicationSearches) ?? []
    }

    private func saveRecentSearch(_ term: String) {
        var searches = recentSearches.filter { $0 != term }
        searches.insert(term, at: 0)
        recentSearches = Array(searches.prefix(10))
        userDefaults.set(recentSearches, forKey: UserDefaultsKeys.recentMedicationSearches)
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
            RxNormDrug(rxCUI: "134615", name: "Omeprazole"),
        ]
    }

    /// Searches for medications with intelligent caching and fallback strategies
    func searchMedications(_ query: String) async -> [RxNormDrug] {
        let results = await searchMedicationsEnhanced(query)
        return results.map { $0.drug }
    }

    /// Enhanced search using new SwiftRxNorm APIs with fuzzy matching and scoring
    func searchMedicationsEnhanced(_ query: String) async -> [RxNormSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Return empty for very short queries
        guard trimmedQuery.count >= 2 else {
            return []
        }

        // Check cache first
        let cacheKey = trimmedQuery.lowercased() as NSString
        if let cachedEntry = searchCache.object(forKey: cacheKey),
           !cachedEntry.isExpired
        {
            searchResults = cachedEntry.results
            return cachedEntry.results
        }

        // Cancel previous search
        searchTask?.cancel()

        // Perform search
        isSearching = true
        defer { isSearching = false }

        do {
            // Use enhanced search with fuzzy matching for better results
            let rawResults = try await client.enhancedSearch(trimmedQuery, options: .comprehensive)

            // Process, simplify and sort results with intelligent prioritization
            let sortedResults = await MedicationResultSorter.processAndSort(rawResults, for: trimmedQuery)

            // Deduplicate while preserving sort order
            var seen = Set<String>()
            let results = sortedResults.filter { result in
                let key = result.drug.rxCUI
                if seen.contains(key) {
                    return false
                }
                seen.insert(key)
                return true
            }

            // Cache results
            let entry = CacheEntry(results: results, searchTerm: trimmedQuery)
            searchCache.setObject(entry, forKey: cacheKey, cost: MemoryLayout<RxNormSearchResult>.size * results.count)

            // Save to recent searches if we got results
            if !results.isEmpty {
                saveRecentSearch(trimmedQuery)
            }

            searchResults = results
            return results
        } catch {
            // On error, try to find similar cached results
            return findSimilarCachedResultsEnhanced(for: trimmedQuery)
        }
    }

    /// Optimized autocomplete using new SwiftRxNorm API
    func autocomplete(_ query: String) async -> AutocompleteResult? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Return empty for very short queries
        guard trimmedQuery.count >= 2 else {
            return nil
        }

        // Cancel previous search
        searchTask?.cancel()

        // Perform autocomplete
        isSearching = true
        defer { isSearching = false }

        do {
            // Use optimized autocomplete API
            let result = try await client.autocomplete(trimmedQuery, options: .autocomplete)

            // Extract drug names from suggestions for deduplication and sorting
            let drugNames = result.suggestions.map { $0.drug.name }

            // Deduplicate and sort suggestions with start-of-string priority
            let uniqueNames = Array(Set(drugNames))
            let sortedNames = MedicationResultSorter.sortAutocompleteResults(uniqueNames, for: trimmedQuery)

            // Convert back to RxNormSearchResult format, preserving original metadata
            let sortedSuggestions = sortedNames.compactMap { name in
                result.suggestions.first { $0.drug.name == name }
            }

            // Create new result with deduplicated and sorted suggestions
            let sortedResult = AutocompleteResult(
                suggestions: sortedSuggestions,
                hasMore: result.hasMore,
                query: result.query,
                searchTime: result.searchTime
            )

            autocompleteResults = sortedResult

            // Save to recent searches if we got results
            if !sortedResult.suggestions.isEmpty {
                saveRecentSearch(trimmedQuery)
            }

            return sortedResult
        } catch {
            // Return nil on error
            return nil
        }
    }

    /// Finds similar results from cache when API fails
    private func findSimilarCachedResults(for query: String) -> [RxNormDrug] {
        let results = findSimilarCachedResultsEnhanced(for: query)
        return results.map { $0.drug }
    }

    /// Enhanced version that returns RxNormSearchResult with scoring
    private func findSimilarCachedResultsEnhanced(for query: String) -> [RxNormSearchResult] {
        let normalizedQuery = query.lowercased()
        var results: [RxNormSearchResult] = []

        // First check popular medications
        let popularMatches = popularMedications.compactMap { drug -> RxNormSearchResult? in
            let nameLower = drug.name.lowercased()
            if nameLower.contains(normalizedQuery) {
                // Calculate a simple relevance score
                let score: Double
                if nameLower == normalizedQuery {
                    score = 1.0
                } else if nameLower.hasPrefix(normalizedQuery) {
                    score = 0.9
                } else {
                    score = 0.7
                }
                return RxNormSearchResult(
                    drug: drug,
                    score: score,
                    source: .direct,
                    isExactMatch: nameLower == normalizedQuery,
                    matchedTerm: drug.name
                )
            }
            return nil
        }

        results.append(contentsOf: popularMatches)

        // If we found popular matches, return them sorted by score
        if !results.isEmpty {
            return results.sorted { $0.score > $1.score }
        }

        // Check recent searches for partial matches
        for recentTerm in recentSearches {
            if recentTerm.lowercased().contains(normalizedQuery) ||
                normalizedQuery.contains(recentTerm.lowercased())
            {
                let cacheKey = recentTerm.lowercased() as NSString
                if let cachedEntry = searchCache.object(forKey: cacheKey),
                   !cachedEntry.isExpired
                {
                    let matches = cachedEntry.results.filter { result in
                        result.drug.name.lowercased().contains(normalizedQuery)
                    }
                    results.append(contentsOf: matches)
                }
            }
        }

        // Remove duplicates and sort by score
        let uniqueResults = Dictionary(grouping: results) { $0.drug.rxCUI }
            .compactMap { $0.value.max(by: { $0.score < $1.score }) }

        return uniqueResults.sorted { $0.score > $1.score }
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
               !cachedEntry.isExpired
            {
                let matches = cachedEntry.drugs.filter { drug in
                    drug.name.lowercased().contains(normalizedQuery)
                }
                suggestions.append(contentsOf: matches)
            }
        }

        // Convert to search results and process through name simplifier for proper deduplication
        let searchResults = suggestions.map { drug in
            RxNormSearchResult(
                drug: drug,
                score: 0.8,
                source: .direct,
                isExactMatch: false,
                matchedTerm: drug.name
            )
        }

        let processedResults = MedicationNameSimplifier.processSearchResults(searchResults)
        let deduplicatedResults = MedicationNameSimplifier.deduplicateResults(processedResults)

        // Convert back to RxNormDrug with simplified names and limit to 10
        return deduplicatedResults.prefix(10).map { result in
            RxNormDrug(rxCUI: result.original.drug.rxCUI, name: result.clinicalName)
        }
    }

    /// Clears all cached data
    func clearCache() {
        searchCache.removeAllObjects()
    }

    /// Clears recent searches
    func clearRecentSearches() {
        recentSearches = []
        userDefaults.removeObject(forKey: UserDefaultsKeys.recentMedicationSearches)
    }
}

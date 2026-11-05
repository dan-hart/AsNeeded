// MedicationSearchEnhancedTests.swift
// Service behavior at the RxNorm boundary, using deterministic responses.

@testable import AsNeeded
import Foundation
import SwiftRxNorm
import Testing

@MainActor
@Suite(.tags(.search, .medication, .unit))
struct MedicationSearchEnhancedTests {
	private let preferences: IsolatedTestPreferences
	private let requests = Requests()

	init() throws {
		preferences = try IsolatedTestPreferences()
	}

	private final class Requests {
		var searches: [String] = []
		var autocompletes: [String] = []
	}

	private enum FixtureError: Error { case unavailable }

	private func result(_ name: String, id: String, score: Double = 0.8) -> RxNormSearchResult {
		RxNormSearchResult(drug: RxNormDrug(rxCUI: id, name: name), score: score, source: .direct, isExactMatch: false, matchedTerm: name)
	}

	private func service(results: [RxNormSearchResult] = [], fails: Bool = false) -> MedicationSearchService {
		MedicationSearchService(
			defaults: preferences.defaults,
			enhancedSearch: { query in
				requests.searches.append(query)
				if fails { throw FixtureError.unavailable }
				return results
			},
			autocomplete: { query in
				requests.autocompletes.append(query)
				if fails { throw FixtureError.unavailable }
				return AutocompleteResult(suggestions: results, hasMore: true, query: query, searchTime: 0.01)
			}
                    )
                }

	@Test("Empty and short input never reaches RxNorm")
	func shortQueries() async {
		let service = service()
		for query in ["", " ", "\t\n", "a"] {
			let results = await service.searchMedicationsEnhanced(query)
			let autocomplete = await service.autocomplete(query)
			#expect(results.isEmpty)
			#expect(autocomplete == nil)
		}
		#expect(requests.searches.isEmpty)
		#expect(requests.autocompletes.isEmpty)
		#expect(!service.isSearching)
	}

	@Test("Search trims input, removes duplicate IDs, and publishes successful results")
	func processesSearchResponse() async throws {
		let service = service(results: [result("Aspirin", id: "1191"), result("Aspirin", id: "1191")])
		let results = await service.searchMedicationsEnhanced("  aspirin \n")
		let first = try #require(results.first)
		#expect(requests.searches == ["aspirin"])
		#expect(results.count == 1)
		#expect(first.drug.rxCUI == "1191")
		#expect(first.drug.name == "Aspirin")
		#expect(service.searchResults.map(\.drug.rxCUI) == ["1191"])
		#expect(service.recentSearches == ["aspirin"])
		#expect(!service.isSearching)
	}

	@Test("Case variants reuse cached results and clearing the cache fetches again")
	func cacheReuseAndInvalidation() async {
		let service = service(results: [result("Aspirin", id: "1191")])
		let first = await service.searchMedicationsEnhanced("aspirin")
		let cached = await service.searchMedicationsEnhanced("ASPIRIN")
		#expect(first.map(\.drug.rxCUI) == ["1191"])
		#expect(cached.map(\.drug.rxCUI) == first.map(\.drug.rxCUI))
		#expect(requests.searches == ["aspirin"])
		service.clearCache()
		let refreshed = await service.searchMedicationsEnhanced("aspirin")
		#expect(refreshed.map(\.drug.rxCUI) == ["1191"])
		#expect(requests.searches == ["aspirin", "aspirin"])
	}

	@Test("The legacy search returns the drugs from enhanced results")
	func legacySearch() async {
		let service = service(results: [result("Ibuprofen", id: "197381")])
		let drugs = await service.searchMedications("ibuprofen")
		#expect(drugs.map(\.rxCUI) == ["197381"])
		#expect(requests.searches == ["ibuprofen"])
	}

	@Test("Failed searches fall back to matching popular medications")
	func errorFallback() async {
		let service = service(fails: true)
		let results = await service.searchMedicationsEnhanced("aspirin")
		#expect(results.map(\.drug.name) == ["Aspirin"])
		#expect(requests.searches == ["aspirin"])
		#expect(service.recentSearches.isEmpty)
		#expect(!service.isSearching)
	}

	@Test("Successful empty results do not create a recent search")
	func emptyResponse() async {
		let service = service()
		let results = await service.searchMedicationsEnhanced("unknown")
		#expect(results.isEmpty)
		#expect(requests.searches == ["unknown"])
		#expect(service.recentSearches.isEmpty)
	}

	@Test("Autocomplete trims input, deduplicates names, and preserves response metadata")
	func autocompleteResponse() async throws {
		let service = service(results: [result("Aspirin", id: "1191"), result("Aspirin", id: "duplicate")])
		let response = try #require(await service.autocomplete("  asp  "))
		#expect(response.query == "asp")
		#expect(response.suggestions.map(\.drug.name) == ["Aspirin"])
		#expect(response.hasMore)
		#expect(response.searchTime == 0.01)
		#expect(service.autocompleteResults?.query == "asp")
		#expect(requests.autocompletes == ["asp"])
		#expect(service.recentSearches == ["asp"])
		#expect(!service.isSearching)
	}

	@Test("Failed autocomplete returns nil without recording a recent search")
	func autocompleteFailure() async {
		let service = service(fails: true)
		let response = await service.autocomplete("asp")
		#expect(response == nil)
		#expect(requests.autocompletes == ["asp"])
		#expect(service.recentSearches.isEmpty)
		#expect(!service.isSearching)
	}

	@Test("Recent searches persist in the injected domain and clear explicitly")
	func recentSearchPersistence() async {
		let service = service(results: [result("Aspirin", id: "1191")])
		_ = await service.searchMedicationsEnhanced("aspirin")
		#expect(preferences.defaults.stringArray(forKey: UserDefaultsKeys.recentMedicationSearches) == ["aspirin"])
		let reloaded = self.service()
		#expect(reloaded.recentSearches == ["aspirin"])
		reloaded.clearRecentSearches()
		#expect(reloaded.recentSearches.isEmpty)
		#expect(preferences.defaults.object(forKey: UserDefaultsKeys.recentMedicationSearches) == nil)
            }
        }

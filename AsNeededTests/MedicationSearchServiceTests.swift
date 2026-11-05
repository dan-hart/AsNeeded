//
//  MedicationSearchServiceTests.swift
//  AsNeededTests
//
//  Tests for the MedicationSearchService functionality
//

@testable import AsNeeded
import Foundation
import SwiftRxNorm
import Testing

@MainActor
@Suite(.tags(.search, .medication, .service, .unit))
struct MedicationSearchServiceTests {
	private let preferences: IsolatedTestPreferences
	private let service: MedicationSearchService

	init() throws {
		preferences = try IsolatedTestPreferences()
		service = MedicationSearchService(defaults: preferences.defaults)
	}

    // MARK: - Initialization Tests
    @Test("MedicationSearchService should initialize as singleton")
    func medicationSearchServiceInitializesAsSingleton() {
        let service1 = MedicationSearchService.shared
        let service2 = MedicationSearchService.shared

        #expect(service1 === service2, "Should return the same instance (singleton)")
    }

    // MARK: - Search Functionality Tests
    @Test("getSuggestions should return popular medications for empty search term")
    func getSuggestionsShouldReturnPopularMedicationsForEmptyTerm() {
		let service = self.service
        let suggestions = service.getSuggestions(for: "")

		#expect(Set(suggestions.map(\.name)) == Set(["Ibuprofen", "Aspirin", "Acetaminophen", "Metformin", "Simvastatin", "Lisinopril", "Amlodipine", "Albuterol", "Levothyroxine", "Omeprazole"]))
    }

    @Test("getSuggestions should return empty array for whitespace-only search term")
    func getSuggestionsShouldReturnEmptyForWhitespaceOnlyTerm() {
		let service = self.service
        let suggestions = service.getSuggestions(for: "   ")

        #expect(suggestions.isEmpty, "Should return empty array for whitespace-only search term")
    }

    // MARK: - Search Method Tests
    @Test("Search method should handle empty terms gracefully")
    func searchMethodShouldHandleEmptyTermsGracefully() async {
		let service = self.service

        // This should complete without throwing
        let results = await service.searchMedications("")

        #expect(results.isEmpty, "Search should return empty results for empty terms")
    }

    @Test("Search method should handle whitespace-only terms gracefully")
    func searchMethodShouldHandleWhitespaceOnlyTermsGracefully() async {
		let service = self.service

        // This should complete without throwing
        let results = await service.searchMedications("   ")

        #expect(results.isEmpty, "Search should return empty results for whitespace-only terms")
    }

    // MARK: - Deduplication Integration Tests
    @Test("getSuggestions should return simplified medication names")
	func getSuggestionsShouldReturnSimplifiedMedicationNames() throws {
		let service = self.service

        // Test that popular medications are simplified
        let suggestions = service.getSuggestions(for: "ibuprofen")

        // Should contain simplified "Ibuprofen" (not "Ibuprofen 200mg" or similar)
        let ibuprofenResults = suggestions.filter { $0.name.lowercased().contains("ibuprofen") }
		try #require(!ibuprofenResults.isEmpty)
        for result in ibuprofenResults {
            // Should not contain dosage information
            #expect(!result.name.contains("mg"))
            #expect(!result.name.contains("tablet"))
            #expect(!result.name.contains("capsule"))
        }
    }

    @Test("getSuggestions should not return duplicate simplified names")
	func getSuggestionsShouldNotReturnDuplicateSimplifiedNames() throws {
		let service = self.service

        // Get all suggestions for empty search (returns popular medications)
        let suggestions = service.getSuggestions(for: "")

		try #require(!suggestions.isEmpty)

        // Check that there are no duplicate medication names
        let medicationNames = suggestions.map { $0.name }
        let uniqueNames = Array(Set(medicationNames))

        #expect(uniqueNames.count == medicationNames.count, "Should not have duplicate medication names in suggestions")

        // Specifically check for common duplicates that might occur
        let nameCounts = medicationNames.reduce(into: [String: Int]()) { counts, name in
            counts[name, default: 0] += 1
        }

        for (name, count) in nameCounts {
            #expect(count == 1, "Medication '\(name)' appears \(count) times, should only appear once")
        }
    }

    @Test("getSuggestions should maintain consistent behavior across multiple calls")
    func getSuggestionsShouldMaintainConsistentBehaviorAcrossMultipleCalls() {
		let service = self.service

        // Make multiple calls to getSuggestions
        let firstCall = service.getSuggestions(for: "ibuprofen")
        let secondCall = service.getSuggestions(for: "ibuprofen")
        let thirdCall = service.getSuggestions(for: "ibuprofen")

        // Results should be consistent
		#expect(firstCall.map(\.name) == ["Ibuprofen"])
        #expect(firstCall.count == secondCall.count)
        #expect(secondCall.count == thirdCall.count)

        // Names should be identical across calls
        let firstNames = Set(firstCall.map { $0.name })
        let secondNames = Set(secondCall.map { $0.name })
        let thirdNames = Set(thirdCall.map { $0.name })

        #expect(firstNames == secondNames)
        #expect(secondNames == thirdNames)
    }
}

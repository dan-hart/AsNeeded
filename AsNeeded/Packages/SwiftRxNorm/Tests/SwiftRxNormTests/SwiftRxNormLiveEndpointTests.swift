import Foundation
import Testing
@testable import SwiftRxNorm
@Suite("RxNormClient Live Endpoint Tests")
struct RxNormLiveTests {
	// Set to 'true' to enable live endpoint tests
	static let enabled = false

	@Test("fetchDrugsByName hits real API (only runs if enabled)")
	func testFetchDrugsByNameLive() async throws {
		guard Self.enabled else { return /* Skipped: Live endpoint tests are disabled */ }
		let client = await RxNormClient()
		let drugs = try await client.fetchDrugsByName("aspirin")
		#expect(!drugs.isEmpty)
		#expect(drugs.contains(where: { $0.name.lowercased().contains("aspirin") }))
	}

	@Test("fetchRxcuiByName hits real API (only runs if enabled)")
	func testFetchRxcuiByNameLive() async throws {
		guard Self.enabled else { return /* Skipped: Live endpoint tests are disabled */ }
		let client = await RxNormClient()
		let rxcui = try await client.fetchRxcuiByName("aspirin")
		#expect(rxcui != nil)
	}

	@Test("fetchDrugSynonyms hits real API (only runs if enabled)")
	func testFetchDrugSynonymsLive() async throws {
		guard Self.enabled else { return /* Skipped: Live endpoint tests are disabled */ }
		let client = await RxNormClient()
		let rxcui = try await client.fetchRxcuiByName("aspirin")
		guard let rxcui = rxcui else {
			#expect(false, "RxCUI not found for aspirin")
			return
		}
		let synonyms = try await client.fetchDrugSynonyms(for: rxcui)
		#expect(!synonyms.isEmpty)
	}

	@Test("fetchInteractionsForRxcui hits real API (only runs if enabled)")
	func testFetchInteractionsForRxcuiLive() async throws {
		guard Self.enabled else { return /* Skipped: Live endpoint tests are disabled */ }
		let client = await RxNormClient()
		let rxcui = try await client.fetchRxcuiByName("warfarin")
		guard let rxcui = rxcui else {
			#expect(false, "RxCUI not found for warfarin")
			return
		}
		let interactions = try await client.fetchInteractionsForRxcui(rxcui)
		#expect(!interactions.isEmpty)
	}

	@Test("fetchPropertiesForRxcui hits real API (only runs if enabled)")
	func testFetchPropertiesForRxcuiLive() async throws {
		guard Self.enabled else { return /* Skipped: Live endpoint tests are disabled */ }
		let client = await RxNormClient()
		let rxcui = try await client.fetchRxcuiByName("ibuprofen")
		guard let rxcui = rxcui else {
			#expect(false, "RxCUI not found for ibuprofen")
			return
		}
		let props = try await client.fetchPropertiesForRxcui(rxcui)
		#expect(props["Name"]?.lowercased().contains("ibuprofen") == true)
	}
}

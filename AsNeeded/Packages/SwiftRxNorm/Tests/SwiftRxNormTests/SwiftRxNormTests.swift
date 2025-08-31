import Foundation
import Testing
@testable import SwiftRxNorm

@Suite("RxNormClient Endpoint Tests")
struct RxNormTests {
	struct MockNetwork: RxNormNetworking {
		let responseData: Data
		func data(for request: URLRequest) async throws -> (Data, URLResponse) {
			let url = request.url ?? URL(string: "https://mock")!
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (responseData, response)
		}
	}

	@Test("fetchDrugsByName returns array of drugs for valid response")
	func testFetchDrugsByName() async throws {
		let mockJSON = """
		{
		  "drugGroup": {
			"conceptGroup": [
			  {
				"conceptProperties": [
				  {"rxcui": "1234", "name": "Aspirin"},
				  {"rxcui": "5678", "name": "Ibuprofen"}
				]
			  }
			]
		  }
		}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		let results = try await client.fetchDrugsByName("aspirin")
		#expect(results.count == 2)
		#expect(results[0].name == "Aspirin")
		#expect(results[1].rxCUI == "5678")
	}

	@Test("fetchDrugsByName throws decodingFailed for invalid JSON")
	func testFetchDrugsByNameInvalidJSON() async throws {
		let invalidJSON = Data("{".utf8)
		let client = await RxNormClient(network: MockNetwork(responseData: invalidJSON))
		do {
			_ = try await client.fetchDrugsByName("invalid")
			#expect(false, "Should have thrown")
		} catch {
			#expect(error is DecodingError || error is RxNormError)
		}
	}

	@Test("fetchRxcuiByName returns RxCUI for valid response")
	func testFetchRxcuiByName() async throws {
		let mockJSON = """
		{"idGroup":{"rxnormId":["1234"]}}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		let rxcui = try await client.fetchRxcuiByName("aspirin")
		#expect(rxcui == "1234")
	}

	@Test("fetchRxcuiByName throws decodingFailed for invalid JSON")
	func testFetchRxcuiByNameInvalidJSON() async throws {
		let invalidJSON = Data("{".utf8)
		let client = await RxNormClient(network: MockNetwork(responseData: invalidJSON))
		do {
			_ = try await client.fetchRxcuiByName("invalid")
			#expect(false, "Should have thrown")
		} catch {
			#expect(error is DecodingError || error is RxNormError)
		}
	}

	@Test("fetchDrugSynonyms returns synonyms for valid response")
	func testFetchDrugSynonyms() async throws {
		let mockJSON = """
		{"propConceptGroup":{"propConcept":[{"propValue":"Aspirin"},{"propValue":"Acetylsalicylic Acid"}]}}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		let synonyms = try await client.fetchDrugSynonyms(for: "1234")
		#expect(synonyms == ["Aspirin","Acetylsalicylic Acid"])
	}

	@Test("fetchDrugSynonyms throws decodingFailed for invalid JSON")
	func testFetchDrugSynonymsInvalidJSON() async throws {
		let invalidJSON = Data("{".utf8)
		let client = await RxNormClient(network: MockNetwork(responseData: invalidJSON))
		do {
			_ = try await client.fetchDrugSynonyms(for: "1234")
			#expect(false)
		} catch {
			#expect(error is DecodingError || error is RxNormError)
		}
	}

	@Test("fetchInteractionsForRxcui returns interactions for valid response")
	func testFetchInteractionsForRxcui() async throws {
		let mockJSON = """
		{"interactionTypeGroup":[{"interactionType":[{"interactionPair":[{"description":"Major interaction.","interactionConcept":[{"minConceptItem":{"name":"Aspirin","rxcui":"1234"}},{"minConceptItem":{"name":"Warfarin","rxcui":"5678"}}]}]}]}]}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		let interactions = try await client.fetchInteractionsForRxcui("1234")
		#expect(interactions.count == 1)
		#expect(interactions[0].description == "Major interaction.")
		#expect(interactions[0].drugs.map(\.name) == ["Aspirin","Warfarin"])
	}

	@Test("fetchInteractionsForRxcui throws decodingFailed for invalid JSON")
	func testFetchInteractionsForRxcuiInvalidJSON() async throws {
		let invalidJSON = Data("{".utf8)
		let client = await RxNormClient(network: MockNetwork(responseData: invalidJSON))
		do {
			_ = try await client.fetchInteractionsForRxcui("1234")
			#expect(false)
		} catch {
			#expect(error is DecodingError || error is RxNormError)
		}
	}

	@Test("fetchPropertiesForRxcui returns properties for valid response")
	func testFetchPropertiesForRxcui() async throws {
		let mockJSON = """
		{"properties":{"RxCUI":"1234","Name":"Aspirin","Synonym":"Acetylsalicylic Acid"}}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		let props = try await client.fetchPropertiesForRxcui("1234")
		#expect(props["RxCUI"] == "1234")
		#expect(props["Name"] == "Aspirin")
		#expect(props["Synonym"] == "Acetylsalicylic Acid")
	}

	@Test("fetchPropertiesForRxcui throws decodingFailed for invalid JSON")
	func testFetchPropertiesForRxcuiInvalidJSON() async throws {
		let invalidJSON = Data("{".utf8)
		let client = await RxNormClient(network: MockNetwork(responseData: invalidJSON))
		do {
			_ = try await client.fetchPropertiesForRxcui("1234")
			#expect(false)
		} catch {
			#expect(error is DecodingError || error is RxNormError)
		}
	}

	@Test("getSpellingSuggestions returns suggestions for valid response")
	func testGetSpellingSuggestions() async throws {
		let mockJSON = """
		{
		  "suggestionGroup": {
		    "suggestionList": {
		      "suggestion": ["Aspirin", "Acetaminophen", "Ibuprofen"]
		    }
		  }
		}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		let suggestions = try await client.getSpellingSuggestions("asirin")
		#expect(suggestions == ["Aspirin", "Acetaminophen", "Ibuprofen"])
	}

	@Test("getSpellingSuggestions returns empty array for no suggestions")
	func testGetSpellingSuggestionsEmpty() async throws {
		let mockJSON = """
		{"suggestionGroup":null}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		let suggestions = try await client.getSpellingSuggestions("invalidterm")
		#expect(suggestions.isEmpty)
	}

	@Test("getSpellingSuggestions throws decodingFailed for invalid JSON")
	func testGetSpellingSuggestionsInvalidJSON() async throws {
		let invalidJSON = Data("{".utf8)
		let client = await RxNormClient(network: MockNetwork(responseData: invalidJSON))
		do {
			_ = try await client.getSpellingSuggestions("test")
			#expect(false, "Should have thrown")
		} catch {
			#expect(error is DecodingError || error is RxNormError)
		}
	}

	@Test("suggestDrugs returns limited results")
	func testSuggestDrugsLimit() async throws {
		let mockJSON = """
		{
		  "approximateGroup": {
		    "candidate": [
		      {"rxcui": "1", "name": "Drug1", "score": "100"},
		      {"rxcui": "2", "name": "Drug2", "score": "90"},
		      {"rxcui": "3", "name": "Drug3", "score": "80"}
		    ]
		  }
		}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		let results = try await client.suggestDrugs("drug", max: 2)
		#expect(results.count == 2)
		#expect(results[0].name == "Drug1")
		#expect(results[1].name == "Drug2")
	}

	@Test("comprehensiveSearch combines multiple strategies")
	func testComprehensiveSearch() async throws {
		// This test uses a mock that will succeed for all three requests
		let mockJSON = """
		{
		  "approximateGroup": {
		    "candidate": [{"rxcui": "1", "name": "Aspirin", "score": "100"}]
		  }
		}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		let results = try await client.comprehensiveSearch("aspirin")
		#expect(!results.isEmpty)
		#expect(results[0].name == "Aspirin")
	}

	@Test("RxNormDrug equality and hashing")
	func testRxNormDrugEquality() throws {
		let drug1 = RxNormDrug(rxCUI: "1234", name: "Aspirin")
		let drug2 = RxNormDrug(rxCUI: "1234", name: "Aspirin")
		let drug3 = RxNormDrug(rxCUI: "5678", name: "Ibuprofen")
		
		#expect(drug1 == drug2)
		#expect(drug1 != drug3)
		#expect(drug1.hashValue == drug2.hashValue)
	}

	@Test("RxNormError descriptions")
	func testRxNormErrorDescriptions() throws {
		#expect(RxNormError.invalidRequest.errorDescription == "Invalid RxNorm API request.")
		#expect(RxNormError.invalidResponse.errorDescription == "Unexpected response from RxNorm API.")
		#expect(RxNormError.decodingFailed.errorDescription == "Failed to decode RxNorm API response.")
	}

	@Test("RxNormInteraction model")
	func testRxNormInteractionModel() throws {
		let drugs = [
			RxNormDrug(rxCUI: "1", name: "Drug A"),
			RxNormDrug(rxCUI: "2", name: "Drug B")
		]
		let interaction = RxNormInteraction(description: "Test interaction", drugs: drugs)
		
		#expect(interaction.description == "Test interaction")
		#expect(interaction.drugs.count == 2)
		#expect(interaction.drugs[0].name == "Drug A")
		#expect(interaction.drugs[1].name == "Drug B")
	}

	@Test("Empty response handling")
	func testEmptyResponseHandling() async throws {
		let emptyJSON = """
		{"drugGroup":{"conceptGroup":null}}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: emptyJSON))
		let results = try await client.fetchDrugsByName("nonexistent")
		#expect(results.isEmpty)
	}

	@Test("Network error handling")
	func testNetworkErrorHandling() async throws {
		struct ErrorNetwork: RxNormNetworking {
			func data(for request: URLRequest) async throws -> (Data, URLResponse) {
				throw URLError(.networkConnectionLost)
			}
		}
		
		let client = await RxNormClient(network: ErrorNetwork())
		do {
			_ = try await client.fetchDrugsByName("aspirin")
			#expect(false, "Should have thrown")
		} catch {
			#expect(error is URLError)
		}
	}

	@Test("HTTP error status handling")
	func testHTTPErrorStatusHandling() async throws {
		struct NotFoundNetwork: RxNormNetworking {
			func data(for request: URLRequest) async throws -> (Data, URLResponse) {
				let url = request.url ?? URL(string: "https://mock")!
				let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
				return (Data(), response)
			}
		}
		
		let client = await RxNormClient(network: NotFoundNetwork())
		do {
			_ = try await client.fetchDrugsByName("aspirin")
			#expect(false, "Should have thrown")
		} catch {
			#expect(error is RxNormError)
			#expect(error as? RxNormError == .invalidResponse)
		}
	}

	@Test("URL encoding edge cases")
	func testURLEncodingEdgeCases() async throws {
		let mockJSON = """
		{"drugGroup":{"conceptGroup":null}}
		""".data(using: .utf8)!
		let client = await RxNormClient(network: MockNetwork(responseData: mockJSON))
		
		// Test special characters in drug names
		let results = try await client.fetchDrugsByName("Drug with spaces & symbols!")
		#expect(results.isEmpty) // Empty response is fine, we're testing URL encoding doesn't crash
	}
}


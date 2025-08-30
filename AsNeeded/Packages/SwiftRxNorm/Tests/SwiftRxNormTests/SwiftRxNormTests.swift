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
}


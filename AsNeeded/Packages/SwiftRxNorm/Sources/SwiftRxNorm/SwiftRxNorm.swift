//
//  SwiftRxNorm.swift
//  
//  A Swift client for the RxNorm API
//
//  RxNorm provides normalized names for clinical drugs and links them to many of the drug vocabularies commonly used in pharmacy management and drug interaction software. The RxNorm API allows developers to access this rich drug information in a standardized format.
//
//  This package provides a simple, Swift-native interface to interact with the RxNorm API using modern Swift concurrency (async/await).
//
//  Usage:
//  ```swift
//  let client = RxNormClient()
//  let drugs = try await client.fetchDrugsByName("Aspirin")
//  print(drugs)
//  ```
//
//  This is a starting template designed for extensibility and easy integration into Swift projects.
//

import Foundation

/// An API client for the NIH RxNorm REST API.
///
/// This client provides strongly typed, documented, and testable access to all endpoints defined by the RxNorm API.
/// Each endpoint is exposed as an async method. All networking is dependency-injected for testability.
public struct RxNormClient {
    /// Base URL for all RxNorm REST API endpoints to simplify URL construction and maintenance.
    private static let baseURL = "https://rxnav.nlm.nih.gov/REST/"
    
    public let network: RxNormNetworking
    
    /// Creates a new instance of `RxNormClient` with the given networking implementation.
    /// - Parameter network: The networking layer to use. Defaults to `URLSession.shared`.
    public init(network: RxNormNetworking = URLSession.shared) {
        self.network = network
    }
    
    /// Fetches drugs matching the provided name from the RxNorm API.
    /// - Parameter name: The (partial or full) name of the drug to search for.
    /// - Returns: An array of `RxNormDrug` results.
    /// - Throws: `RxNormError` if the network request or parsing fails.
    public func fetchDrugsByName(_ name: String) async throws -> [RxNormDrug] {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(Self.baseURL)drugs.json?name=\(encoded)") else {
            throw RxNormError.invalidRequest
        }
        let request = URLRequest(url: url)
        let (data, response) = try await network.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RxNormError.invalidResponse
        }
        return try decodeDrugs(from: data)
    }
    
    /// Fetches the RxCUI (RxNorm Concept Unique Identifier) for a given drug name.
    public func fetchRxcuiByName(_ name: String) async throws -> String? {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(Self.baseURL)rxcui.json?name=\(encoded)") else {
            throw RxNormError.invalidRequest
        }
        let request = URLRequest(url: url)
        let (data, response) = try await network.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RxNormError.invalidResponse
        }
        return try decodeRxCui(from: data)
    }
    
    /// Fetches synonyms for a given RxCUI.
    public func fetchDrugSynonyms(for rxCui: String) async throws -> [String] {
        guard let url = URL(string: "\(Self.baseURL)rxcui/\(rxCui)/allProperties.json?prop=names") else {
            throw RxNormError.invalidRequest
        }
        let request = URLRequest(url: url)
        let (data, response) = try await network.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RxNormError.invalidResponse
        }
        return try decodeSynonyms(from: data)
    }
    
    /// Fetches all interactions for a given RxCUI.
    public func fetchInteractionsForRxcui(_ rxCui: String) async throws -> [RxNormInteraction] {
        guard let url = URL(string: "\(Self.baseURL)interaction/interaction.json?rxcui=\(rxCui)") else {
            throw RxNormError.invalidRequest
        }
        let request = URLRequest(url: url)
        let (data, response) = try await network.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RxNormError.invalidResponse
        }
        return try decodeInteractions(from: data)
    }
    
    /// Fetches properties/details for a given RxCUI.
    public func fetchPropertiesForRxcui(_ rxCui: String) async throws -> [String: String] {
        guard let url = URL(string: "\(Self.baseURL)rxcui/\(rxCui)/properties.json") else {
            throw RxNormError.invalidRequest
        }
        let request = URLRequest(url: url)
        let (data, response) = try await network.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RxNormError.invalidResponse
        }
        return try decodeProperties(from: data)
    }
    
    /// Decodes the response for the drug search endpoint.
    private func decodeDrugs(from data: Data) throws -> [RxNormDrug] {
        do {
            let decoded = try JSONDecoder().decode(DrugsResponse.self, from: data)
            return decoded.drugGroup.conceptGroup?.flatMap { $0.conceptProperties ?? [] }.map {
                RxNormDrug(rxCUI: $0.rxcui, name: $0.name)
            } ?? []
        } catch {
            throw RxNormError.decodingFailed
        }
    }
    
    private func decodeRxCui(from data: Data) throws -> String? {
        struct RxcuiResponse: Decodable { let idGroup: IdGroup; struct IdGroup: Decodable { let rxnormId: [String]? } }
        do {
            let decoded = try JSONDecoder().decode(RxcuiResponse.self, from: data)
            return decoded.idGroup.rxnormId?.first
        } catch { throw RxNormError.decodingFailed }
    }
    
    private func decodeSynonyms(from data: Data) throws -> [String] {
        struct SynonymsResponse: Decodable { let propConceptGroup: PropConceptGroup?; struct PropConceptGroup: Decodable { let propConcept: [PropConcept]?; struct PropConcept: Decodable { let propValue: String } } }
        do {
            let decoded = try JSONDecoder().decode(SynonymsResponse.self, from: data)
            return decoded.propConceptGroup?.propConcept?.map { $0.propValue } ?? []
        } catch { throw RxNormError.decodingFailed }
    }

    private func decodeProperties(from data: Data) throws -> [String: String] {
        struct PropertiesResponse: Decodable { let properties: [String: String]? }
        do {
            let decoded = try JSONDecoder().decode(PropertiesResponse.self, from: data)
            return decoded.properties ?? [:]
        } catch { throw RxNormError.decodingFailed }
    }
    
    private func decodeInteractions(from data: Data) throws -> [RxNormInteraction] {
        struct InteractionResponse: Decodable {
            let interactionTypeGroup: [TypeGroup]?
            struct TypeGroup: Decodable {
                let interactionType: [InteractionType]?
                struct InteractionType: Decodable {
                    let interactionPair: [InteractionPair]?
                    struct InteractionPair: Decodable {
                        let description: String
                        let interactionConcept: [InteractionConcept]
                        struct InteractionConcept: Decodable {
                            let minConceptItem: ConceptItem
                            struct ConceptItem: Decodable {
                                let name: String
                                let rxcui: String
                            }
                        }
                    }
                }
            }
        }
        do {
            let interactionResponse = try JSONDecoder().decode(InteractionResponse.self, from: data)
            let pairs = interactionResponse.interactionTypeGroup?.flatMap { $0.interactionType ?? [] }.flatMap { $0.interactionPair ?? [] } ?? []
            return pairs.map { pair in
                RxNormInteraction(
                    description: pair.description,
                    drugs: pair.interactionConcept.map { c in RxNormDrug(rxCUI: c.minConceptItem.rxcui, name: c.minConceptItem.name) }
                )
            }
        } catch { throw RxNormError.decodingFailed }
    }
}


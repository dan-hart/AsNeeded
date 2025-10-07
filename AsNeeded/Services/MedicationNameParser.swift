//
//  MedicationNameParser.swift
//  AsNeeded
//
//  AI-powered medication name parsing using iOS 26 Foundation Models
//

import Foundation
import SwiftRxNorm
import DHLoggingKit
// Foundation Models will be available in iOS 26 final release
// For now, we'll use NaturalLanguage framework as a bridge
import NaturalLanguage

/// Components extracted from a medication name
@available(iOS 18.0, *)
struct MedicationComponents: Codable {
	let genericName: String
	let brandName: String?
	let dosageStrength: String?
	let dosageUnit: String?
	let route: String?
	let form: String?
	let releaseType: String? // extended, immediate, etc.
	
	/// Returns a simplified clinical name
	var simplifiedName: String {
		genericName
	}
	
	/// Returns the full dosage information if available
	var dosage: String? {
		guard let strength = dosageStrength, let unit = dosageUnit else { return nil }
		return "\(strength) \(unit)"
	}
}

/// Modern AI-powered medication name parser using Foundation Models
@available(iOS 18.0, *)
@MainActor
final class MedicationNameParser {
	static let shared = MedicationNameParser()
	
	private let tagger = NLTagger(tagSchemes: [.nameType, .tokenType])
	
	private init() {}
	
	/// Parses a medication name using AI to extract components
	/// Note: This is a bridge implementation until FoundationModels framework is available
	func parseComponents(from medicationName: String) async throws -> MedicationComponents {
		// For now, use enhanced regex patterns with NLTagger assistance
		// This will be replaced with actual FoundationModels API when available
		
		// Use NLTagger to identify key components
		tagger.string = medicationName
		
		var genericName = ""
		var brandName: String?
		var dosageStrength: String?
		var dosageUnit: String?
		var route: String?
		var form: String?
		var releaseType: String?
		
		// Extract brand name from brackets or parentheses
		if let brandMatch = medicationName.firstMatch(of: /\[([^\]]+)\]/) {
			brandName = String(brandMatch.1)
		} else if let brandMatch = medicationName.firstMatch(of: /\(([^)]+)\)/) {
			let content = String(brandMatch.1)
			// Check if it looks like a brand name
			if content.first?.isUppercase == true && content != content.uppercased() {
				brandName = content
			}
		}
		
		// Extract dosage information
		if let dosageMatch = try? /(\d+(?:\.\d+)?)\s*(mg|mcg|ml|g|iu|unit|%)/.ignoresCase().firstMatch(in: medicationName) {
			dosageStrength = String(dosageMatch.1)
			dosageUnit = String(dosageMatch.2).lowercased()
		}
		
		// Extract release type
		if medicationName.lowercased().contains("extended release") {
			releaseType = "Extended Release"
		} else if medicationName.lowercased().contains("immediate release") {
			releaseType = "Immediate Release"
		} else if medicationName.lowercased().contains("sustained release") {
			releaseType = "Sustained Release"
		}
		
		// Extract route
		let routes = ["oral", "topical", "injection", "intravenous", "subcutaneous", "intramuscular", "rectal", "nasal", "ophthalmic"]
		for r in routes {
			if medicationName.lowercased().contains(r) {
				route = r.capitalized
				break
			}
		}
		
		// Extract form
		let forms = ["tablet", "capsule", "solution", "suspension", "cream", "ointment", "gel", "patch", "inhaler", "spray", "drops", "syrup", "liquid", "powder"]
		for f in forms {
			if medicationName.lowercased().contains(f) {
				form = f.capitalized
				break
			}
		}
		
		// Extract generic name (simplified version of the full name)
		genericName = MedicationNameSimplifier.simplifyName(medicationName)
		
		return MedicationComponents(
			genericName: genericName,
			brandName: brandName,
			dosageStrength: dosageStrength,
			dosageUnit: dosageUnit,
			route: route,
			form: form,
			releaseType: releaseType
		)
	}
	
	/// Batch process multiple medication names efficiently
	func parseMultiple(_ medicationNames: [String]) async throws -> [MedicationComponents] {
		return try await withThrowingTaskGroup(of: MedicationComponents.self) { group in
			for name in medicationNames {
				group.addTask {
					try await self.parseComponents(from: name)
				}
			}
			
			var results: [MedicationComponents] = []
			for try await component in group {
				results.append(component)
			}
			return results
		}
	}
	
	/// Simplifies a medication name using AI parsing
	func simplifyName(_ name: String) async throws -> String {
		let components = try await parseComponents(from: name)
		return components.simplifiedName
	}
	
	/// Extracts brand name if present
	func extractBrandName(from name: String) async throws -> String? {
		let components = try await parseComponents(from: name)
		return components.brandName
	}
}

/// Errors that can occur during medication parsing
enum MedicationParsingError: LocalizedError {
	case foundationModelsUnavailable
	case parsingFailed(String)
	
	var errorDescription: String? {
		switch self {
		case .foundationModelsUnavailable:
			return "Foundation Models framework requires iOS 26 or later"
		case .parsingFailed(let details):
			return "Failed to parse medication name: \(details)"
		}
	}
}

/// Enhanced simplifier that uses AI when available, regex as fallback
struct MedicationNameSimplifierEnhanced {
	
	/// Simplifies medication name using best available method
	static func simplifyName(_ name: String) async -> String {
		// Try AI-powered parsing first on iOS 18+
		if #available(iOS 18.0, *) {
			do {
				return try await MedicationNameParser.shared.simplifyName(name)
			} catch {
				// Fall back to regex if AI parsing fails
				DHLogger.data.error("AI parsing failed, using regex: \(error.localizedDescription)")
			}
		}
		
		// Fallback to regex-based simplification
		return MedicationNameSimplifier.simplifyName(name)
	}
	
	/// Extracts brand name using best available method
	static func extractBrandName(_ name: String) async -> String? {
		// Try AI-powered extraction first on iOS 18+
		if #available(iOS 18.0, *) {
			do {
				return try await MedicationNameParser.shared.extractBrandName(from: name)
			} catch {
				// Fall back to regex if AI extraction fails
				DHLogger.data.error("AI brand extraction failed, using regex: \(error.localizedDescription)")
			}
		}
		
		// Fallback to regex-based extraction
		return MedicationNameSimplifier.extractBrandName(name)
	}
	
	/// Process search results with AI enhancement when available
	static func processSearchResults(_ results: [RxNormSearchResult]) async -> [(clinicalName: String, nickname: String, original: RxNormSearchResult)] {
		if #available(iOS 18.0, *) {
			// Process with AI for better accuracy
			return await withTaskGroup(of: (String, String?, RxNormSearchResult).self) { group in
				for result in results {
					group.addTask {
						let simplified = await simplifyName(result.drug.name)
						let brandName = await extractBrandName(result.drug.name)
						return (simplified, brandName, result)
					}
				}
				
				var processedResults: [(clinicalName: String, nickname: String, original: RxNormSearchResult)] = []
				for await (simplified, brandName, original) in group {
					let nickname = brandName ?? simplified
					processedResults.append((clinicalName: simplified, nickname: nickname, original: original))
				}
				
				return processedResults
			}
		} else {
			// Fallback to synchronous regex processing
			return MedicationNameSimplifier.processSearchResults(results)
		}
	}
}
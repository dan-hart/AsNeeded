//
//  MedicationNameSimplifier.swift
//  AsNeeded
//
//  Logic layer to simplify complex medication names from RxNorm
//

import Foundation
import SwiftRxNorm

/// Simplifies complex medication names to user-friendly formats
enum MedicationNameSimplifier {
    // MARK: - Properties

    private nonisolated(unsafe) static let dosagePattern = /\s*\d+(?:\.\d+)?\s*(?:mg|mcg|ml|g|iu|unit|%)/
    private nonisolated(unsafe) static let routePattern = /\s+(?:oral|tablet|capsule|injection|topical|solution|suspension|cream|ointment|gel|patch|inhaler|spray|drops|syrup|liquid|powder|lozenge|suppository|implant|film)\b/
    private nonisolated(unsafe) static let formPattern = /\s+(?:extended|delayed|sustained|modified|immediate)[\s-]*(?:release|acting)\b/
    private nonisolated(unsafe) static let brandPattern = /\s*\[.*?\]\s*/
    private nonisolated(unsafe) static let parenPattern = /\s*\(.*?\)\s*/
    private nonisolated(unsafe) static let slashDosagePattern = /\s*\/\s*\d+(?:\.\d+)?\s*(?:mg|mcg|ml|g|iu|unit|%)/

    // MARK: - Public Methods

    /// Simplifies a medication name by removing dosage, route, and form information
    static func simplifyName(_ name: String) -> String {
        var simplified = name

        // Remove bracketed brand names first
        simplified = simplified.replacing(brandPattern, with: "")

        // Remove parenthetical information
        simplified = simplified.replacing(parenPattern, with: "")

        // Remove dosage information (e.g., "325 mg", "5 mcg") - case insensitive
        simplified = simplified.replacing(dosagePattern.ignoresCase(), with: "")

        // Remove slash dosage patterns (e.g., "/ 160 mg" in combination drugs)
        simplified = simplified.replacing(slashDosagePattern.ignoresCase(), with: "")

        // Remove extended/delayed release descriptors - case insensitive
        simplified = simplified.replacing(formPattern.ignoresCase(), with: "")

        // Remove route/form descriptors - case insensitive
        simplified = simplified.replacing(routePattern.ignoresCase(), with: "")

        // Clean up multiple spaces, trailing slashes and trim
        simplified = simplified
            .replacingOccurrences(of: "\\s*/$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize properly (title case)
        simplified = simplified
            .lowercased()
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")

        return simplified.isEmpty ? name : simplified
    }

    /// Extracts brand name from a medication name if present
    static func extractBrandName(_ name: String) -> String? {
        // Look for bracketed brand names
        if let match = name.firstMatch(of: #/\[([^\]]+)\]/#) {
            return String(match.1)
        }

        // Look for common brand name patterns in parentheses
        if let match = name.firstMatch(of: #/\(([^\)]+)\)/#) {
            let content = String(match.1)
            // Check if it looks like a brand name (starts with capital letter, not all caps)
            if content.first?.isUppercase == true, content != content.uppercased() {
                return content
            }
        }

        return nil
    }

    /// Processes search results to provide simplified names with brand names as nicknames
    static func processSearchResults(_ results: [RxNormSearchResult]) -> [(clinicalName: String, nickname: String, original: RxNormSearchResult)] {
        return results.map { result in
            let simplified = simplifyName(result.drug.name)
            let brandName = extractBrandName(result.drug.name)

            // Use brand name as nickname if available, otherwise use simplified name
            let nickname = brandName ?? simplified

            return (clinicalName: simplified, nickname: nickname, original: result)
        }
    }

    /// Gets common brand names for generic medications
    static func getCommonBrandName(for genericName: String) -> String? {
        let commonBrands: [String: String] = [
            "acetaminophen": "Tylenol",
            "ibuprofen": "Advil",
            "aspirin": "Bayer",
            "loratadine": "Claritin",
            "cetirizine": "Zyrtec",
            "diphenhydramine": "Benadryl",
            "pseudoephedrine": "Sudafed",
            "omeprazole": "Prilosec",
            "esomeprazole": "Nexium",
            "atorvastatin": "Lipitor",
            "simvastatin": "Zocor",
            "metformin": "Glucophage",
            "lisinopril": "Prinivil",
            "amlodipine": "Norvasc",
            "metoprolol": "Lopressor",
            "levothyroxine": "Synthroid",
            "albuterol": "ProAir",
            "fluticasone": "Flonase",
            "montelukast": "Singulair",
            "sertraline": "Zoloft",
            "escitalopram": "Lexapro",
            "fluoxetine": "Prozac",
            "gabapentin": "Neurontin",
            "tramadol": "Ultram",
            "prednisone": "Deltasone",
            "amoxicillin": "Amoxil",
            "azithromycin": "Zithromax",
            "ciprofloxacin": "Cipro",
            "doxycycline": "Vibramycin",
            "cephalexin": "Keflex",
        ]

        let normalized = genericName.lowercased()
        return commonBrands[normalized]
    }
}

// MARK: - Extensions

extension MedicationNameSimplifier {
    /// Simplifies a list of RxNormDrug objects
    static func simplifyDrugs(_ drugs: [RxNormDrug]) -> [(name: String, original: RxNormDrug)] {
        return drugs.map { drug in
            let simplified = simplifyName(drug.name)
            return (name: simplified, original: drug)
        }
    }

    /// Removes duplicate simplified names, keeping the highest scored result
    static func deduplicateResults(_ results: [(clinicalName: String, nickname: String, original: RxNormSearchResult)]) -> [(clinicalName: String, nickname: String, original: RxNormSearchResult)] {
        var uniqueResults: [String: (clinicalName: String, nickname: String, original: RxNormSearchResult)] = [:]

        for result in results {
            let key = result.clinicalName.lowercased()

            if let existing = uniqueResults[key] {
                // Keep the one with higher score
                if result.original.score > existing.original.score {
                    uniqueResults[key] = result
                }
            } else {
                uniqueResults[key] = result
            }
        }

        return Array(uniqueResults.values)
            .sorted { $0.original.score > $1.original.score }
    }
}

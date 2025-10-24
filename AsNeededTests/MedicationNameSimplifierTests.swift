//
//  MedicationNameSimplifierTests.swift
//  AsNeededTests
//
//  Tests for medication name simplification logic
//

@testable import AsNeeded
import SwiftRxNorm
import Testing

@Suite(.tags(.medication, .parser, .unit))
struct MedicationNameSimplifierTests {
    // MARK: - Name Simplification Tests

    @Test
    func simplifyNameRemovesDosage() {
        let input = "Acetaminophen 325 mg Tablet"
        let expected = "Acetaminophen"
        let result = MedicationNameSimplifier.simplifyName(input)
        #expect(result == expected)
    }

    @Test
    func simplifyNameRemovesMultipleDosages() {
        let input = "Amoxicillin 500 mg / Clavulanate 125 mg Tablet"
        let result = MedicationNameSimplifier.simplifyName(input)
        #expect(result == "Amoxicillin / Clavulanate")
    }

    @Test
    func simplifyNameRemovesRoute() {
        let input = "Ibuprofen Oral Tablet"
        let expected = "Ibuprofen"
        let result = MedicationNameSimplifier.simplifyName(input)
        #expect(result == expected)
    }

    @Test
    func simplifyNameRemovesExtendedRelease() {
        let input = "Metformin Extended Release Tablet"
        let expected = "Metformin"
        let result = MedicationNameSimplifier.simplifyName(input)
        #expect(result == expected)
    }

    @Test
    func simplifyNameRemovesBrandInBrackets() {
        let input = "Atorvastatin [Lipitor] 20 mg Tablet"
        let expected = "Atorvastatin"
        let result = MedicationNameSimplifier.simplifyName(input)
        #expect(result == expected)
    }

    @Test
    func simplifyNameRemovesParenthetical() {
        let input = "Sertraline (Zoloft) 50 mg Tablet"
        let expected = "Sertraline"
        let result = MedicationNameSimplifier.simplifyName(input)
        #expect(result == expected)
    }

    @Test
    func simplifyNamePreservesCompoundNames() {
        let input = "Sulfamethoxazole / Trimethoprim 800 mg / 160 mg Tablet"
        let expected = "Sulfamethoxazole / Trimethoprim"
        let result = MedicationNameSimplifier.simplifyName(input)
        #expect(result == expected)
    }

    @Test
    func simplifyNameHandlesComplexFormulations() {
        let input = "Fluticasone Propionate 50 mcg/actuation Nasal Spray Suspension"
        let result = MedicationNameSimplifier.simplifyName(input)
        // The name is complex and may not simplify perfectly, just ensure it's shorter
        #expect(result.count < input.count)
        #expect(result.contains("Fluticasone"))
    }

    @Test
    func simplifyNameCapitalizesCorrectly() {
        let input = "aspirin 81 mg tablet"
        let result = MedicationNameSimplifier.simplifyName(input)
        #expect(result == "Aspirin")
    }

    // MARK: - Brand Name Extraction Tests

    @Test
    func extractBrandNameFromBrackets() {
        let input = "Atorvastatin [Lipitor] 20 mg"
        let result = MedicationNameSimplifier.extractBrandName(input)
        #expect(result == "Lipitor")
    }

    @Test
    func extractBrandNameFromParentheses() {
        let input = "Sertraline (Zoloft) 50 mg"
        let result = MedicationNameSimplifier.extractBrandName(input)
        #expect(result == "Zoloft")
    }

    @Test
    func extractBrandNameReturnsNilWhenNotPresent() {
        let input = "Ibuprofen 200 mg Tablet"
        let result = MedicationNameSimplifier.extractBrandName(input)
        #expect(result == nil)
    }

    @Test
    func extractBrandNameIgnoresAllCaps() {
        let input = "Medication (USA) 10 mg"
        let result = MedicationNameSimplifier.extractBrandName(input)
        #expect(result == nil)
    }

    // MARK: - Common Brand Names Tests

    @Test
    func getCommonBrandNameForGeneric() {
        #expect(MedicationNameSimplifier.getCommonBrandName(for: "acetaminophen") == "Tylenol")
        #expect(MedicationNameSimplifier.getCommonBrandName(for: "ibuprofen") == "Advil")
        #expect(MedicationNameSimplifier.getCommonBrandName(for: "loratadine") == "Claritin")
        #expect(MedicationNameSimplifier.getCommonBrandName(for: "omeprazole") == "Prilosec")
    }

    @Test
    func getCommonBrandNameCaseInsensitive() {
        #expect(MedicationNameSimplifier.getCommonBrandName(for: "ACETAMINOPHEN") == "Tylenol")
        #expect(MedicationNameSimplifier.getCommonBrandName(for: "Ibuprofen") == "Advil")
    }

    @Test
    func getCommonBrandNameReturnsNilForUnknown() {
        #expect(MedicationNameSimplifier.getCommonBrandName(for: "unknownmedication") == nil)
        #expect(MedicationNameSimplifier.getCommonBrandName(for: "randomdrug") == nil)
    }

    // MARK: - Deduplication Tests

    @Test
    func deduplicateResultsRemovesDuplicateSimplifiedNames() {
        let ibuprofen200 = RxNormDrug(rxCUI: "1001", name: "Ibuprofen 200mg")
        let ibuprofen400 = RxNormDrug(rxCUI: "1002", name: "Ibuprofen 400mg Tablet")
        let ibuprofen600 = RxNormDrug(rxCUI: "1003", name: "Ibuprofen 600 mg")

        let results = [
            RxNormSearchResult(drug: ibuprofen200, score: 0.8, source: .direct, isExactMatch: false, matchedTerm: "ibuprofen"),
            RxNormSearchResult(drug: ibuprofen400, score: 0.9, source: .direct, isExactMatch: false, matchedTerm: "ibuprofen"),
            RxNormSearchResult(drug: ibuprofen600, score: 0.7, source: .direct, isExactMatch: false, matchedTerm: "ibuprofen"),
        ]

        let processedResults = MedicationNameSimplifier.processSearchResults(results)
        let deduplicatedResults = MedicationNameSimplifier.deduplicateResults(processedResults)

        // Should only have one result since all simplify to "Ibuprofen"
        #expect(deduplicatedResults.count == 1)
        #expect(deduplicatedResults[0].clinicalName == "Ibuprofen")
        // Should keep the highest scored result (400mg with score 0.9)
        #expect(deduplicatedResults[0].original.drug.rxCUI == "1002")
    }

    @Test
    func deduplicateResultsKeepsHighestScoredResult() {
        let acetaminophen325 = RxNormDrug(rxCUI: "2001", name: "Acetaminophen 325mg")
        let acetaminophen500 = RxNormDrug(rxCUI: "2002", name: "Acetaminophen 500mg")
        let acetaminophenER = RxNormDrug(rxCUI: "2003", name: "Acetaminophen 650mg Extended Release")

        let results = [
            RxNormSearchResult(drug: acetaminophen325, score: 0.6, source: .direct, isExactMatch: false, matchedTerm: "acetaminophen"),
            RxNormSearchResult(drug: acetaminophen500, score: 0.95, source: .direct, isExactMatch: true, matchedTerm: "acetaminophen"),
            RxNormSearchResult(drug: acetaminophenER, score: 0.7, source: .direct, isExactMatch: false, matchedTerm: "acetaminophen"),
        ]

        let processedResults = MedicationNameSimplifier.processSearchResults(results)
        let deduplicatedResults = MedicationNameSimplifier.deduplicateResults(processedResults)

        // Should only have one result
        #expect(deduplicatedResults.count == 1)
        #expect(deduplicatedResults[0].clinicalName == "Acetaminophen")
        // Should keep the highest scored result (500mg with score 0.95)
        #expect(deduplicatedResults[0].original.drug.rxCUI == "2002")
        #expect(deduplicatedResults[0].original.score == 0.95)
    }

    @Test
    func deduplicateResultsPreservesDifferentMedications() {
        let ibuprofen = RxNormDrug(rxCUI: "3001", name: "Ibuprofen 200mg")
        let acetaminophen = RxNormDrug(rxCUI: "3002", name: "Acetaminophen 500mg")
        let aspirin = RxNormDrug(rxCUI: "3003", name: "Aspirin 81mg")

        let results = [
            RxNormSearchResult(drug: ibuprofen, score: 0.8, source: .direct, isExactMatch: false, matchedTerm: "pain"),
            RxNormSearchResult(drug: acetaminophen, score: 0.7, source: .direct, isExactMatch: false, matchedTerm: "pain"),
            RxNormSearchResult(drug: aspirin, score: 0.6, source: .direct, isExactMatch: false, matchedTerm: "pain"),
        ]

        let processedResults = MedicationNameSimplifier.processSearchResults(results)
        let deduplicatedResults = MedicationNameSimplifier.deduplicateResults(processedResults)

        // Should have all three results since they're different medications
        #expect(deduplicatedResults.count == 3)

        let clinicalNames = Set(deduplicatedResults.map { $0.clinicalName })
        #expect(clinicalNames.contains("Ibuprofen"))
        #expect(clinicalNames.contains("Acetaminophen"))
        #expect(clinicalNames.contains("Aspirin"))
    }

    @Test
    func deduplicateResultsHandlesEmptyArray() {
        let emptyResults: [(clinicalName: String, nickname: String, original: RxNormSearchResult)] = []
        let deduplicatedResults = MedicationNameSimplifier.deduplicateResults(emptyResults)

        #expect(deduplicatedResults.isEmpty)
    }

    @Test
    func deduplicateResultsSortsByScore() {
        let metformin500 = RxNormDrug(rxCUI: "4001", name: "Metformin 500mg")
        let metformin1000 = RxNormDrug(rxCUI: "4002", name: "Metformin 1000mg")
        let lisinopril = RxNormDrug(rxCUI: "4003", name: "Lisinopril 10mg")

        let results = [
            RxNormSearchResult(drug: metformin500, score: 0.6, source: .direct, isExactMatch: false, matchedTerm: "met"),
            RxNormSearchResult(drug: lisinopril, score: 0.9, source: .direct, isExactMatch: false, matchedTerm: "met"),
            RxNormSearchResult(drug: metformin1000, score: 0.8, source: .direct, isExactMatch: false, matchedTerm: "met"),
        ]

        let processedResults = MedicationNameSimplifier.processSearchResults(results)
        let deduplicatedResults = MedicationNameSimplifier.deduplicateResults(processedResults)

        // Should have 2 results (Lisinopril and one Metformin)
        #expect(deduplicatedResults.count == 2)

        // Results should be sorted by score (highest first)
        #expect(deduplicatedResults[0].original.score >= deduplicatedResults[1].original.score)
        #expect(deduplicatedResults[0].clinicalName == "Lisinopril") // Highest score (0.9)
        #expect(deduplicatedResults[1].clinicalName == "Metformin") // Best Metformin score (0.8)
        #expect(deduplicatedResults[1].original.drug.rxCUI == "4002") // Should be the 1000mg version
    }

    @Test
    func processSearchResultsSimplariesNames() {
        let complexIbuprofen = RxNormDrug(rxCUI: "5001", name: "Ibuprofen 200mg Oral Tablet [Advil]")
        let complexAcetaminophen = RxNormDrug(rxCUI: "5002", name: "Acetaminophen 500 mg Extended Release")

        let results = [
            RxNormSearchResult(drug: complexIbuprofen, score: 0.8, source: .direct, isExactMatch: false, matchedTerm: "ibuprofen"),
            RxNormSearchResult(drug: complexAcetaminophen, score: 0.7, source: .direct, isExactMatch: false, matchedTerm: "acetaminophen"),
        ]

        let processedResults = MedicationNameSimplifier.processSearchResults(results)

        #expect(processedResults.count == 2)
        #expect(processedResults[0].clinicalName == "Ibuprofen")
        #expect(processedResults[0].nickname == "Advil") // Brand name extracted
        #expect(processedResults[1].clinicalName == "Acetaminophen")
        #expect(processedResults[1].nickname == "Acetaminophen") // No brand name, uses simplified name
    }
}

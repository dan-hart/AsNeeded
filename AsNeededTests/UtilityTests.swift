// UtilityTests.swift
// Tests for utility classes

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("Utility Tests", .tags(.utility, .unit))
@MainActor
struct UtilityTests {
    // MARK: - MedicationSearchUtility Tests

    @Test("Find best match with exact name")
    func findBestMatchExact() {
        // Given
        let medications = [
            createMedication(name: "Aspirin"),
            createMedication(name: "Ibuprofen"),
            createMedication(name: "Tylenol", nickname: "Acetaminophen"),
        ]

        // When
        let result = MedicationSearchUtility.findBestMatch(for: "Aspirin", in: medications)

        // Then
        #expect(result != nil)
        #expect(result?.clinicalName == "Aspirin")
    }

    @Test("Find best match by nickname")
    func findBestMatchByNickname() {
        // Given
        let medications = [
            createMedication(name: "Acetaminophen", nickname: "Tylenol"),
        ]

        // When
        let result = MedicationSearchUtility.findBestMatch(for: "tylenol", in: medications)

        // Then
        #expect(result != nil)
        #expect(result?.clinicalName == "Acetaminophen")
    }

    @Test("Find best match with partial name")
    func findBestMatchPartial() {
        // Given
        let medications = [
            createMedication(name: "Ibuprofen 200mg"),
            createMedication(name: "Aspirin"),
        ]

        // When
        let result = MedicationSearchUtility.findBestMatch(for: "ibuprofen", in: medications)

        // Then
        #expect(result != nil)
        #expect(result?.clinicalName == "Ibuprofen 200mg")
    }

    @Test("Find best match with fuzzy search")
    func findBestMatchFuzzy() {
        // Given
        let medications = [
            createMedication(name: "Metformin Hydrochloride"),
        ]

        // When
        let result = MedicationSearchUtility.findBestMatch(for: "metf hydro", in: medications)

        // Then
        #expect(result != nil)
        #expect(result?.clinicalName == "Metformin Hydrochloride")
    }

    @Test("Validate medication name")
    func isValidMedicationName() {
        // Valid names
        #expect(MedicationSearchUtility.isValidMedicationName("Aspirin") == true)
        #expect(MedicationSearchUtility.isValidMedicationName("Ibuprofen 200mg") == true)
        #expect(MedicationSearchUtility.isValidMedicationName("Vitamin-D3") == true)

        // Invalid names
        #expect(MedicationSearchUtility.isValidMedicationName("") == false)
        #expect(MedicationSearchUtility.isValidMedicationName("A") == false) // Too short
        #expect(MedicationSearchUtility.isValidMedicationName("Med@123") == false) // Invalid character
        #expect(MedicationSearchUtility.isValidMedicationName("12345") == false) // No letters
    }

    // MARK: - DateUtility Tests

    @Test("Get day range for date")
    func dayRange() {
        // Given
        let testDate = Date()

        // When
        let (start, end) = DateUtility.dayRange(for: testDate)

        // Then
        #expect(start <= testDate)
        #expect(testDate < end)
        #expect(Calendar.current.dateComponents([.day], from: start, to: end).day == 1)
    }

    @Test("Filter events for today")
    func filterEventsForToday() {
        // Given
        let todayEvent = ANEventConcept(eventType: .doseTaken, medication: nil, dose: nil, date: Date())
        let yesterdayEvent = ANEventConcept(eventType: .doseTaken, medication: nil, dose: nil, date: Date().addingTimeInterval(-86400))
        let events = [todayEvent, yesterdayEvent]

        // When
        let filtered = DateUtility.filterEventsForToday(events)

        // Then
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == todayEvent.id)
    }

    @Test("Validate medication date")
    func isValidMedicationDate() {
        // Valid dates
        #expect(DateUtility.isValidMedicationDate(Date()) == true)
        #expect(DateUtility.isValidMedicationDate(Date().addingTimeInterval(-86400 * 30)) == true) // 30 days ago

        // Invalid dates
        #expect(DateUtility.isValidMedicationDate(Date().addingTimeInterval(-86400 * 400)) == false) // Over a year ago
        #expect(DateUtility.isValidMedicationDate(Date().addingTimeInterval(86400 * 30)) == false) // Far future
    }

    // MARK: - ValidationUtility Tests

    @Test("Validate medication success")
    func validateMedicationSuccess() {
        // Given
        let medication = createMedication(name: "Valid Medication", nickname: "Valid")

        // When
        let result = ValidationUtility.validateMedication(medication)

        // Then
        #expect(result.isValid == true)
        #expect(result.errors.isEmpty == true)
    }

    @Test("Validate medication with empty name")
    func validateMedicationEmptyName() {
        // Given
        let medication = createMedication(name: "", nickname: nil)

        // When
        let result = ValidationUtility.validateMedication(medication)

        // Then
        #expect(result.isValid == false)
        #expect(result.errors.contains { error in
            if case .emptyField = error { return true }
            return false
        } == true)
    }

    @Test("Validate medication with invalid dose")
    func validateMedicationInvalidDose() {
        // Given
        var medication = createMedication(name: "Test")
        medication.prescribedDoseAmount = -5.0

        // When
        let result = ValidationUtility.validateMedication(medication)

        // Then
        #expect(result.isValid == false)
        #expect(result.errors.contains { error in
            if case .invalidValue = error { return true }
            return false
        } == true)
    }

    @Test("Validate event success")
    func validateEventSuccess() {
        // Given
        let medication = createMedication(name: "Test Med")
        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: ANDoseConcept(amount: 10.0, unit: .milligram),
            date: Date()
        )

        // When
        let result = ValidationUtility.validateEvent(event)

        // Then
        #expect(result.isValid == true)
    }

    @Test("Validate event missing medication")
    func validateEventMissingMedication() {
        // Given
        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: nil,
            dose: ANDoseConcept(amount: 10.0, unit: .milligram),
            date: Date()
        )

        // When
        let result = ValidationUtility.validateEvent(event)

        // Then
        #expect(result.isValid == false)
        #expect(result.errors.contains { error in
            if case .missingRequiredField = error { return true }
            return false
        } == true)
    }

    @Test("Find duplicate medications")
    func findDuplicateMedications() {
        // Given
        let med1 = createMedication(name: "Aspirin", nickname: nil)
        let med2 = createMedication(name: "aspirin", nickname: nil) // Same name, different case
        let med3 = createMedication(name: "Ibuprofen", nickname: nil)
        let medications = [med1, med2, med3]

        // When
        let duplicates = ValidationUtility.findDuplicateMedications(in: medications)

        // Then
        #expect(duplicates.count == 1)
        #expect(duplicates.first?.count == 2)
    }

    // MARK: - Helper Methods

    private func createMedication(name: String, nickname: String? = nil) -> ANMedicationConcept {
        return ANMedicationConcept(
            clinicalName: name,
            nickname: nickname,
            prescribedUnit: .milligram,
            prescribedDoseAmount: 10.0
        )
    }
}

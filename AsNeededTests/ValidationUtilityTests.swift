// ValidationUtilityTests.swift
// Comprehensive unit tests for ValidationUtility

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("ValidationUtility Tests", .tags(.validation, .utility, .unit))
struct ValidationUtilityTests {
    // MARK: - Name Validation Tests

    @Test("Valid medication names should pass validation")
    func validMedicationNames() {
        let validNames = [
            "Aspirin",
            "Ibuprofen 200mg",
            "Tylenol Extra Strength",
            "Vitamin D3",
            "Multi-vitamin complex",
            "AB", // Minimum length
            String(repeating: "A", count: 200), // Maximum length
        ]

        for name in validNames {
            #expect(ValidationUtility.isValidMedicationName(name) == true)
        }
    }

    @Test("Invalid medication names should fail validation")
    func invalidMedicationNames() {
        let invalidNames = [
            "", // Empty
            " ", // Only whitespace
            "A", // Too short
            String(repeating: "A", count: 201), // Too long
            "Med@123", // Invalid character @
            "Drug#1", // Invalid character #
            "Test$Med", // Invalid character $
            "123456", // No letters
            "!!!", // Only special characters
        ]

        for name in invalidNames {
            #expect(ValidationUtility.isValidMedicationName(name) == false)
        }
    }

    @Test("Medication names with whitespace should be trimmed")
    func medicationNameTrimming() {
        #expect(ValidationUtility.isValidMedicationName("  Aspirin  ") == true)
        #expect(ValidationUtility.isValidMedicationName("\nIbuprofen\t") == true)
        #expect(ValidationUtility.isValidMedicationName("  A  ") == false) // Too short after trimming
    }

    // MARK: - Medication Validation Tests

    @Test("Valid medication should pass validation")
    func validMedication() {
        let medication = ANMedicationConcept(
            clinicalName: "Ibuprofen",
            nickname: "Pain Relief",
            prescribedUnit: .milligram,
            prescribedDoseAmount: 200
        )

        let result = ValidationUtility.validateMedication(medication)
        #expect(result.isValid == true)
        #expect(result.errors.isEmpty == true)
    }

    @Test("Medication with empty clinical name should fail")
    func medicationEmptyClinicalName() {
        let medication = ANMedicationConcept(
            clinicalName: "",
            prescribedDoseAmount: 100
        )

        let result = ValidationUtility.validateMedication(medication)
        #expect(result.isValid == false)
        #expect(result.errors.count > 0)
    }

    @Test("Medication with invalid dose should fail")
    func medicationInvalidDose() {
        let medicationNegative = ANMedicationConcept(
            clinicalName: "Test Med",
            prescribedDoseAmount: -10
        )

        let resultNegative = ValidationUtility.validateMedication(medicationNegative)
        #expect(resultNegative.isValid == false)

        let medicationZero = ANMedicationConcept(
            clinicalName: "Test Med",
            prescribedDoseAmount: 0
        )

        let resultZero = ValidationUtility.validateMedication(medicationZero)
        #expect(resultZero.isValid == false)

        let medicationExcessive = ANMedicationConcept(
            clinicalName: "Test Med",
            prescribedDoseAmount: 10001
        )

        let resultExcessive = ValidationUtility.validateMedication(medicationExcessive)
        #expect(resultExcessive.isValid == false)
    }

    @Test("Medication with long nickname should fail")
    func medicationLongNickname() {
        let medication = ANMedicationConcept(
            clinicalName: "Valid Name",
            nickname: String(repeating: "A", count: 101)
        )

        let result = ValidationUtility.validateMedication(medication)
        #expect(result.isValid == false)
    }

    // MARK: - Event Validation Tests

    @Test("Valid event should pass validation")
    func validEvent() {
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        let dose = ANDoseConcept(amount: 10, unit: .milligram)
        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: Date()
        )

        let result = ValidationUtility.validateEvent(event)
        #expect(result.isValid == true)
    }

    @Test("Event with invalid dose should fail")
    func eventInvalidDose() {
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        let doseNegative = ANDoseConcept(amount: -5, unit: .milligram)
        let eventNegative = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: doseNegative,
            date: Date()
        )

        let resultNegative = ValidationUtility.validateEvent(eventNegative)
        #expect(resultNegative.isValid == false)

        let doseExcessive = ANDoseConcept(amount: 1001, unit: .milligram)
        let eventExcessive = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: doseExcessive,
            date: Date()
        )

        let resultExcessive = ValidationUtility.validateEvent(eventExcessive)
        #expect(resultExcessive.isValid == false)
    }

    @Test("Dose taken event without medication should fail")
    func eventMissingMedication() {
        let dose = ANDoseConcept(amount: 10, unit: .milligram)
        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: nil,
            dose: dose,
            date: Date()
        )

        let result = ValidationUtility.validateEvent(event)
        #expect(result.isValid == false)
    }

    @Test("Dose taken event without dose should fail")
    func eventMissingDose() {
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: nil,
            date: Date()
        )

        let result = ValidationUtility.validateEvent(event)
        #expect(result.isValid == false)
    }

    // MARK: - Bulk Validation Tests

    @Test("Bulk medication validation should categorize correctly")
    func bulkMedicationValidation() {
        let validMed1 = ANMedicationConcept(clinicalName: "Valid Med 1")
        let validMed2 = ANMedicationConcept(clinicalName: "Valid Med 2")
        let invalidMed1 = ANMedicationConcept(clinicalName: "")
        let invalidMed2 = ANMedicationConcept(clinicalName: "Test", prescribedDoseAmount: -10)

        let medications = [validMed1, validMed2, invalidMed1, invalidMed2]
        let result = ValidationUtility.validateMedications(medications)

        #expect(result.validCount == 2)
        #expect(result.invalidCount == 2)
        #expect(result.isAllValid == false)
        #expect(result.successRate == 0.5)
    }

    @Test("Bulk event validation should categorize correctly")
    func bulkEventValidation() {
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        let validDose = ANDoseConcept(amount: 10, unit: .milligram)
        let invalidDose = ANDoseConcept(amount: -5, unit: .milligram)

        let validEvent1 = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: validDose,
            date: Date()
        )
        let validEvent2 = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: validDose,
            date: Date().addingTimeInterval(-3600)
        )
        let invalidEvent = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: invalidDose,
            date: Date()
        )

        let events = [validEvent1, validEvent2, invalidEvent]
        let result = ValidationUtility.validateEvents(events)

        #expect(result.validCount == 2)
        #expect(result.invalidCount == 1)
        #expect(result.successRate > 0.66 && result.successRate < 0.67)
    }

    // MARK: - Data Integrity Tests

    @Test("Should find duplicate medications by name")
    func testFindDuplicateMedications() {
        let med1 = ANMedicationConcept(clinicalName: "Aspirin")
        let med2 = ANMedicationConcept(clinicalName: "aspirin") // Different case
        let med3 = ANMedicationConcept(clinicalName: "Ibuprofen")
        let med4 = ANMedicationConcept(clinicalName: "ASPIRIN") // Another duplicate

        let medications = [med1, med2, med3, med4]
        let duplicates = ValidationUtility.findDuplicateMedications(in: medications)

        #expect(duplicates.count == 1) // One group of duplicates
        #expect(duplicates[0].count == 3) // Three aspirins
    }

    @Test("Should find duplicate medications by nickname")
    func findDuplicateMedicationsByNickname() {
        let med1 = ANMedicationConcept(clinicalName: "Med1", nickname: "Pain")
        let med2 = ANMedicationConcept(clinicalName: "Med2", nickname: "Pain")
        let med3 = ANMedicationConcept(clinicalName: "Med3", nickname: "Sleep")

        let medications = [med1, med2, med3]
        let duplicates = ValidationUtility.findDuplicateMedications(in: medications)

        #expect(duplicates.count == 1)
        #expect(duplicates[0].count == 2)
    }

    @Test("Should validate data consistency")
    func dataConsistency() {
        let med1 = ANMedicationConcept(clinicalName: "Used Med")
        let med2 = ANMedicationConcept(clinicalName: "Unused Med")
        let orphanMed = ANMedicationConcept(clinicalName: "Orphan Med")

        let dose = ANDoseConcept(amount: 10, unit: .milligram)
        let event1 = ANEventConcept(
            eventType: .doseTaken,
            medication: med1,
            dose: dose,
            date: Date()
        )
        let orphanEvent = ANEventConcept(
            eventType: .doseTaken,
            medication: orphanMed,
            dose: dose,
            date: Date()
        )

        let medications = [med1, med2]
        let events = [event1, orphanEvent]

        let result = ValidationUtility.validateDataConsistency(
            medications: medications,
            events: events
        )

        #expect(result.isConsistent == false)
        #expect(result.orphanedEvents.count == 1)
        #expect(result.unusedMedications.count == 1)
        #expect(result.unusedMedications[0].id == med2.id)
    }

    // MARK: - ValidationError Tests

    @Test("ValidationError should provide correct descriptions")
    func validationErrorDescriptions() {
        let emptyError = ValidationError.emptyField(field: "Name")
        #expect(emptyError.errorDescription == "Name cannot be empty")

        let tooLongError = ValidationError.fieldTooLong(field: "Description", maxLength: 100)
        #expect(tooLongError.errorDescription == "Description exceeds maximum length of 100 characters")

        let invalidFormatError = ValidationError.invalidFormat(field: "Email", reason: "Invalid format")
        #expect(invalidFormatError.errorDescription == "Email has invalid format: Invalid format")

        let invalidValueError = ValidationError.invalidValue(field: "Age", reason: "Must be positive")
        #expect(invalidValueError.errorDescription == "Age has invalid value: Must be positive")

        let missingError = ValidationError.missingRequiredField(field: "Password")
        #expect(missingError.errorDescription == "Password is required")

        let duplicateError = ValidationError.duplicateValue(field: "Username")
        #expect(duplicateError.errorDescription == "Username already exists")
    }

    // MARK: - Performance Tests

    @Test("Bulk validation should be performant")
    func bulkValidationPerformance() {
        // Create 1000 medications for performance testing
        var medications: [ANMedicationConcept] = []
        for i in 0 ..< 1000 {
            medications.append(ANMedicationConcept(
                clinicalName: "Medication \(i)",
                prescribedDoseAmount: Double(i % 100 + 1)
            ))
        }

        let startTime = Date()
        let result = ValidationUtility.validateMedications(medications)
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(result.validCount == 1000)
        #expect(elapsed < 1.0) // Should complete in less than 1 second
    }
}

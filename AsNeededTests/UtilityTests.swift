// UtilityTests.swift
// Tests for utility classes

import XCTest
import ANModelKit
@testable import AsNeeded

@MainActor
final class UtilityTests: XCTestCase {
	
	// MARK: - MedicationSearchUtility Tests
	
	func testFindBestMatchExact() {
		// Given
		let medications = [
			createMedication(name: "Aspirin"),
			createMedication(name: "Ibuprofen"),
			createMedication(name: "Tylenol", nickname: "Acetaminophen")
		]
		
		// When
		let result = MedicationSearchUtility.findBestMatch(for: "Aspirin", in: medications)
		
		// Then
		XCTAssertNotNil(result)
		XCTAssertEqual(result?.clinicalName, "Aspirin")
	}
	
	func testFindBestMatchByNickname() {
		// Given
		let medications = [
			createMedication(name: "Acetaminophen", nickname: "Tylenol")
		]
		
		// When
		let result = MedicationSearchUtility.findBestMatch(for: "tylenol", in: medications)
		
		// Then
		XCTAssertNotNil(result)
		XCTAssertEqual(result?.clinicalName, "Acetaminophen")
	}
	
	func testFindBestMatchPartial() {
		// Given
		let medications = [
			createMedication(name: "Ibuprofen 200mg"),
			createMedication(name: "Aspirin")
		]
		
		// When
		let result = MedicationSearchUtility.findBestMatch(for: "ibuprofen", in: medications)
		
		// Then
		XCTAssertNotNil(result)
		XCTAssertEqual(result?.clinicalName, "Ibuprofen 200mg")
	}
	
	func testFindBestMatchFuzzy() {
		// Given
		let medications = [
			createMedication(name: "Metformin Hydrochloride")
		]
		
		// When
		let result = MedicationSearchUtility.findBestMatch(for: "metf hydro", in: medications)
		
		// Then
		XCTAssertNotNil(result)
		XCTAssertEqual(result?.clinicalName, "Metformin Hydrochloride")
	}
	
	func testIsValidMedicationName() {
		// Valid names
		XCTAssertTrue(MedicationSearchUtility.isValidMedicationName("Aspirin"))
		XCTAssertTrue(MedicationSearchUtility.isValidMedicationName("Ibuprofen 200mg"))
		XCTAssertTrue(MedicationSearchUtility.isValidMedicationName("Vitamin-D3"))
		
		// Invalid names
		XCTAssertFalse(MedicationSearchUtility.isValidMedicationName(""))
		XCTAssertFalse(MedicationSearchUtility.isValidMedicationName("A")) // Too short
		XCTAssertFalse(MedicationSearchUtility.isValidMedicationName("Med@123")) // Invalid character
		XCTAssertFalse(MedicationSearchUtility.isValidMedicationName("12345")) // No letters
	}
	
	// MARK: - DateUtility Tests
	
	func testDayRange() {
		// Given
		let testDate = Date()
		
		// When
		let (start, end) = DateUtility.dayRange(for: testDate)
		
		// Then
		XCTAssertTrue(start <= testDate)
		XCTAssertTrue(testDate < end)
		XCTAssertEqual(Calendar.current.dateComponents([.day], from: start, to: end).day, 1)
	}
	
	func testFilterEventsForToday() {
		// Given
		let todayEvent = ANEventConcept(eventType: .doseTaken, medication: nil, dose: nil, date: Date())
		let yesterdayEvent = ANEventConcept(eventType: .doseTaken, medication: nil, dose: nil, date: Date().addingTimeInterval(-86400))
		let events = [todayEvent, yesterdayEvent]
		
		// When
		let filtered = DateUtility.filterEventsForToday(events)
		
		// Then
		XCTAssertEqual(filtered.count, 1)
		XCTAssertEqual(filtered.first?.id, todayEvent.id)
	}
	
	func testIsValidMedicationDate() {
		// Valid dates
		XCTAssertTrue(DateUtility.isValidMedicationDate(Date()))
		XCTAssertTrue(DateUtility.isValidMedicationDate(Date().addingTimeInterval(-86400 * 30))) // 30 days ago
		
		// Invalid dates
		XCTAssertFalse(DateUtility.isValidMedicationDate(Date().addingTimeInterval(-86400 * 400))) // Over a year ago
		XCTAssertFalse(DateUtility.isValidMedicationDate(Date().addingTimeInterval(86400 * 30))) // Far future
	}
	
	// MARK: - ValidationUtility Tests
	
	func testValidateMedicationSuccess() {
		// Given
		let medication = createMedication(name: "Valid Medication", nickname: "Valid")
		
		// When
		let result = ValidationUtility.validateMedication(medication)
		
		// Then
		XCTAssertTrue(result.isValid)
		XCTAssertTrue(result.errors.isEmpty)
	}
	
	func testValidateMedicationEmptyName() {
		// Given
		let medication = createMedication(name: "", nickname: nil)
		
		// When
		let result = ValidationUtility.validateMedication(medication)
		
		// Then
		XCTAssertFalse(result.isValid)
		XCTAssertTrue(result.errors.contains { error in
			if case .emptyField = error { return true }
			return false
		})
	}
	
	func testValidateMedicationInvalidDose() {
		// Given
		var medication = createMedication(name: "Test")
		medication.prescribedDoseAmount = -5.0
		
		// When
		let result = ValidationUtility.validateMedication(medication)
		
		// Then
		XCTAssertFalse(result.isValid)
		XCTAssertTrue(result.errors.contains { error in
			if case .invalidValue = error { return true }
			return false
		})
	}
	
	func testValidateEventSuccess() {
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
		XCTAssertTrue(result.isValid)
	}
	
	func testValidateEventMissingMedication() {
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
		XCTAssertFalse(result.isValid)
		XCTAssertTrue(result.errors.contains { error in
			if case .missingRequiredField = error { return true }
			return false
		})
	}
	
	func testFindDuplicateMedications() {
		// Given
		let med1 = createMedication(name: "Aspirin", nickname: nil)
		let med2 = createMedication(name: "aspirin", nickname: nil) // Same name, different case
		let med3 = createMedication(name: "Ibuprofen", nickname: nil)
		let medications = [med1, med2, med3]
		
		// When
		let duplicates = ValidationUtility.findDuplicateMedications(in: medications)
		
		// Then
		XCTAssertEqual(duplicates.count, 1)
		XCTAssertEqual(duplicates.first?.count, 2)
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
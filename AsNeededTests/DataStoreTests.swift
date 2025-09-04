// DataStoreTests.swift
// Comprehensive tests for DataStore operations

import XCTest
import ANModelKit
@testable import AsNeeded

@MainActor
final class DataStoreTests: XCTestCase {
	private var dataStore: DataStore!
	
	override func setUp() async throws {
		try await super.setUp()
		// Create test instance with isolated storage
		dataStore = DataStore(testIdentifier: "DataStoreTests")
		// Clear any existing test data
		try await dataStore.clearAllData()
	}
	
	override func tearDown() async throws {
		// Clean up test data
		try await dataStore.clearAllData()
		dataStore = nil
		try await super.tearDown()
	}
	
	// MARK: - Medication Tests
	
	func testAddMedication() async throws {
		// Given
		let medication = createTestMedication(name: "Test Med")
		
		// When
		try await dataStore.addMedication(medication)
		
		// Then
		XCTAssertEqual(dataStore.medications.count, 1)
		XCTAssertEqual(dataStore.medications.first?.id, medication.id)
		XCTAssertEqual(dataStore.medications.first?.clinicalName, "Test Med")
	}
	
	func testUpdateMedication() async throws {
		// Given
		let medication = createTestMedication(name: "Original Name")
		try await dataStore.addMedication(medication)
		
		// When
		var updated = medication
		updated.clinicalName = "Updated Name"
		updated.nickname = "Updated Nickname"
		try await dataStore.updateMedication(updated)
		
		// Then
		XCTAssertEqual(dataStore.medications.count, 1)
		XCTAssertEqual(dataStore.medications.first?.clinicalName, "Updated Name")
		XCTAssertEqual(dataStore.medications.first?.nickname, "Updated Nickname")
	}
	
	func testDeleteMedication() async throws {
		// Given
		let medication = createTestMedication(name: "To Delete")
		try await dataStore.addMedication(medication)
		XCTAssertEqual(dataStore.medications.count, 1)
		
		// When
		try await dataStore.deleteMedication(medication)
		
		// Then
		XCTAssertEqual(dataStore.medications.count, 0)
	}
	
	func testDeleteMedicationWithAssociatedEvents() async throws {
		// Given
		let medication = createTestMedication(name: "Med with Events")
		try await dataStore.addMedication(medication)
		
		let event1 = createTestEvent(medication: medication)
		let event2 = createTestEvent(medication: medication)
		try await dataStore.addEvent(event1)
		try await dataStore.addEvent(event2)
		
		XCTAssertEqual(dataStore.events.count, 2)
		
		// When
		try await dataStore.deleteMedication(medication)
		
		// Then
		XCTAssertEqual(dataStore.medications.count, 0)
		XCTAssertEqual(dataStore.events.count, 0, "Associated events should be deleted")
	}
	
	// MARK: - Event Tests
	
	func testAddEvent() async throws {
		// Given
		let medication = createTestMedication(name: "Test Med")
		try await dataStore.addMedication(medication)
		let event = createTestEvent(medication: medication)
		
		// When
		try await dataStore.addEvent(event)
		
		// Then
		XCTAssertEqual(dataStore.events.count, 1)
		XCTAssertEqual(dataStore.events.first?.id, event.id)
		XCTAssertEqual(dataStore.events.first?.medication?.id, medication.id)
	}
	
	// MARK: - Export/Import Tests
	
	func testExportDataAsJSON() async throws {
		// Given
		let med1 = createTestMedication(name: "Med 1")
		let med2 = createTestMedication(name: "Med 2")
		try await dataStore.addMedication(med1)
		try await dataStore.addMedication(med2)
		
		let event = createTestEvent(medication: med1)
		try await dataStore.addEvent(event)
		
		// When
		let exportData = try await dataStore.exportDataAsJSON()
		
		// Then
		XCTAssertNotNil(exportData)
		XCTAssertGreaterThan(exportData.count, 0)
		
		// Verify JSON structure
		let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
		XCTAssertNotNil(json)
		XCTAssertNotNil(json?["medications"])
		XCTAssertNotNil(json?["events"])
		XCTAssertNotNil(json?["exportDate"])
		XCTAssertNotNil(json?["appVersion"])
	}
	
	func testExportDataWithRedaction() async throws {
		// Given
		let medication = createTestMedication(name: "Sensitive Med", nickname: "Secret")
		try await dataStore.addMedication(medication)
		
		// When
		let exportData = try await dataStore.exportDataAsJSON(redactNames: true)
		
		// Then
		let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
		let medications = json?["medications"] as? [[String: Any]]
		XCTAssertNotNil(medications)
		XCTAssertEqual(medications?.first?["clinicalName"] as? String, "[REDACTED]")
		XCTAssertEqual(medications?.first?["nickname"] as? String, "[REDACTED]")
	}
	
	func testImportDataFromJSON() async throws {
		// Given - Create and export data
		let originalMed = createTestMedication(name: "Import Test")
		try await dataStore.addMedication(originalMed)
		let originalEvent = createTestEvent(medication: originalMed)
		try await dataStore.addEvent(originalEvent)
		
		let exportData = try await dataStore.exportDataAsJSON()
		
		// Clear data
		try await dataStore.clearAllData()
		XCTAssertEqual(dataStore.medications.count, 0)
		XCTAssertEqual(dataStore.events.count, 0)
		
		// When - Import the data back
		try await dataStore.importDataFromJSON(exportData)
		
		// Then
		XCTAssertEqual(dataStore.medications.count, 1)
		XCTAssertEqual(dataStore.events.count, 1)
		XCTAssertEqual(dataStore.medications.first?.clinicalName, "Import Test")
	}
	
	func testImportWithMerge() async throws {
		// Given - Existing data
		let existingMed = createTestMedication(name: "Existing")
		try await dataStore.addMedication(existingMed)
		
		// Create export data with new medication
		let tempStore = DataStore(testIdentifier: "TempExport")
		let newMed = createTestMedication(name: "New Med")
		try await tempStore.addMedication(newMed)
		let exportData = try await tempStore.exportDataAsJSON()
		
		// When - Import with merge
		try await dataStore.importDataFromJSON(exportData, mergeExisting: true)
		
		// Then
		XCTAssertEqual(dataStore.medications.count, 2)
		XCTAssertTrue(dataStore.medications.contains { $0.clinicalName == "Existing" })
		XCTAssertTrue(dataStore.medications.contains { $0.clinicalName == "New Med" })
	}
	
	// MARK: - Clear Data Tests
	
	func testClearAllData() async throws {
		// Given
		let medication = createTestMedication(name: "To Clear")
		try await dataStore.addMedication(medication)
		let event = createTestEvent(medication: medication)
		try await dataStore.addEvent(event)
		
		XCTAssertEqual(dataStore.medications.count, 1)
		XCTAssertEqual(dataStore.events.count, 1)
		
		// When
		try await dataStore.clearAllData()
		
		// Then
		XCTAssertEqual(dataStore.medications.count, 0)
		XCTAssertEqual(dataStore.events.count, 0)
	}
	
	// MARK: - Performance Tests
	
	func testBulkOperationsPerformance() async throws {
		// Measure bulk insert performance
		let medications = (0..<100).map { i in
			createTestMedication(name: "Med \(i)")
		}
		
		let startTime = Date()
		
		for medication in medications {
			try await dataStore.addMedication(medication)
		}
		
		let elapsed = Date().timeIntervalSince(startTime)
		
		XCTAssertEqual(dataStore.medications.count, 100)
		XCTAssertLessThan(elapsed, 5.0, "Bulk insert should complete within 5 seconds")
	}
	
	// MARK: - Helper Methods
	
	private func createTestMedication(name: String, nickname: String? = nil) -> ANMedicationConcept {
		return ANMedicationConcept(
			clinicalName: name,
			nickname: nickname,
			prescribedUnit: .milligram,
			prescribedDoseAmount: 10.0
		)
	}
	
	private func createTestEvent(medication: ANMedicationConcept) -> ANEventConcept {
		return ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 10.0, unit: .milligram),
			date: Date()
		)
	}
}
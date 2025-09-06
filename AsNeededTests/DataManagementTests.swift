//
//  DataManagementTests.swift
//  AsNeededTests
//
//  Unit tests for data import/export/clear functionality
//

import Testing
import Foundation
@testable import AsNeeded
@testable import ANModelKit

@MainActor
struct DataManagementTests {
  
  // MARK: - Test Helpers

  func createTestDataStore() -> DataStore {
	// Create a test data store with isolated storage for testing
	return DataStore(testIdentifier: UUID().uuidString)
  }
  
  func createTestMedication(id: UUID = UUID()) -> ANMedicationConcept {
	return ANMedicationConcept(
	  id: id,
	  clinicalName: "Test Medication",
	  nickname: "Test Med",
	  quantity: 30.0,
	  lastRefillDate: Date(timeIntervalSince1970: 1640995200), // 2022-01-01
	  nextRefillDate: Date(timeIntervalSince1970: 1643673600), // 2022-02-01
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 500.0
	)
  }
  
  func createTestEvent(id: UUID = UUID(), medicationId: UUID = UUID()) -> ANEventConcept {
	let medication = createTestMedication(id: medicationId)
	let dose = ANDoseConcept(amount: 500.0, unit: ANUnitConcept.milligram)
	
	return ANEventConcept(
	  id: id,
	  eventType: .doseTaken,
	  medication: medication,
	  dose: dose,
	  date: Date(timeIntervalSince1970: 1640995200) // 2022-01-01
	)
  }
  
  // MARK: - Export Tests

  @Test("Export empty data store should produce valid JSON")
  func testExportEmptyDataStore() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let exportData = try await dataStore.exportDataAsJSON()
	
	#expect(exportData.count > 0)
	
	// Verify it's valid JSON
	let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
	#expect(json != nil)
	
	// Verify structure
	#expect(json?["medications"] as? [Any] != nil)
	#expect(json?["events"] as? [Any] != nil)
	#expect(json?["exportDate"] as? String != nil)
	#expect(json?["appVersion"] as? String != nil)
	
	// Verify empty arrays
	let medications = json?["medications"] as? [Any]
	let events = json?["events"] as? [Any]
	#expect(medications?.isEmpty == true)
	#expect(events?.isEmpty == true)
  }
  
  @Test("Export data store with medications should include all data")
  func testExportWithMedications() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let testMedication = createTestMedication()
	try await dataStore.addMedication(testMedication)
	
	let exportData = try await dataStore.exportDataAsJSON()
	let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
	
	let medications = json?["medications"] as? [[String: Any]]
	#expect(medications?.count == 1)
	
	let exportedMed = medications?.first
	#expect(exportedMed?["clinicalName"] as? String == "Test Medication")
	#expect(exportedMed?["nickname"] as? String == "Test Med")
	#expect(exportedMed?["quantity"] as? Double == 30.0)
	#expect(exportedMed?["prescribedDoseAmount"] as? Double == 500.0)
  }
  
  @Test("Export data store with events should include all data")
  func testExportWithEvents() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let testEvent = createTestEvent()
	try await dataStore.addEvent(testEvent)
	
	let exportData = try await dataStore.exportDataAsJSON()
	let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
	
	let events = json?["events"] as? [[String: Any]]
	#expect(events?.count == 1)
	
	let exportedEvent = events?.first
	#expect(exportedEvent?["eventType"] as? String == "dose_taken")
	
	// Verify nested medication data
	let medication = exportedEvent?["medication"] as? [String: Any]
	#expect(medication?["clinicalName"] as? String == "Test Medication")
	
	// Verify nested dose data
	let dose = exportedEvent?["dose"] as? [String: Any]
	#expect(dose?["amount"] as? Double == 500.0)
  }
  
  @Test("Export should use ISO 8601 date format")
  func testExportDateFormat() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let exportData = try await dataStore.exportDataAsJSON()
	guard let jsonString = String(data: exportData, encoding: .utf8) else {
	  #expect(Bool(false), "Failed to convert export data to string")
	  return
	}
	
	// Verify ISO 8601 format pattern exists
	let iso8601Pattern = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"#
	let regex = try NSRegularExpression(pattern: iso8601Pattern)
	let matches = regex.matches(in: jsonString, range: NSRange(jsonString.startIndex..., in: jsonString))
	
	#expect(matches.count > 0, "Export should contain ISO 8601 formatted dates")
  }
  
  // MARK: - Import Tests

  @Test("Import valid JSON should restore data correctly")
  func testImportValidJSON() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Create test JSON data
	let testJSON = """
	{
	  "medications": [
		{
		  "id": "123e4567-e89b-12d3-a456-426614174000",
		  "clinicalName": "Imported Medication",
		  "nickname": "Imported Med",
		  "quantity": 60.0,
		  "prescribedDoseAmount": 250.0,
		  "prescribedUnit": "milligram"
		}
	  ],
	  "events": [
		{
		  "id": "987e6543-e21c-34f5-b678-987654321000",
		  "eventType": "dose_taken",
		  "date": "2022-01-01T12:00:00Z",
		  "medication": {
			"id": "123e4567-e89b-12d3-a456-426614174000",
			"clinicalName": "Event Medication"
		  },
		  "dose": {
			"id": "456e7890-e12b-34c5-d678-123456789abc",
			"amount": 250.0,
			"unit": "milligram"
		  }
		}
	  ],
	  "exportDate": "2022-01-01T12:00:00Z",
	  "appVersion": "1.0.0"
	}
	""".data(using: .utf8)!
	
	try await dataStore.importDataFromJSON(testJSON)
	
	// Verify medications were imported
	let medications = dataStore.medications
	#expect(medications.count == 1)
	#expect(medications.first?.clinicalName == "Imported Medication")
	#expect(medications.first?.nickname == "Imported Med")
	#expect(medications.first?.quantity == 60.0)
	
	// Verify events were imported  
	let events = dataStore.events
	#expect(events.count == 1)
	#expect(events.first?.eventType == .doseTaken)
  }
  
  @Test("Import should clear existing data first")
  func testImportClearsExistingData() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Add existing data
	let existingMedication = createTestMedication()
	try await dataStore.addMedication(existingMedication)
	
	#expect(dataStore.medications.count == 1)
	
	// Import new data
	let importJSON = """
	{
	  "medications": [],
	  "events": [],
	  "exportDate": "2022-01-01T12:00:00Z",
	  "appVersion": "1.0.0"
	}
	""".data(using: .utf8)!
	
	try await dataStore.importDataFromJSON(importJSON)
	
	// Verify existing data was cleared
	#expect(dataStore.medications.count == 0)
	#expect(dataStore.events.count == 0)
  }
  
  @Test("Import invalid JSON should throw error")
  func testImportInvalidJSON() async throws {
	let dataStore = createTestDataStore()
	
	let invalidJSON = "{ invalid json }".data(using: .utf8)!
	
	await #expect(throws: (any Error).self) {
	  try await dataStore.importDataFromJSON(invalidJSON)
	}
  }
  
  @Test("Import JSON with missing required fields should throw error")
  func testImportIncompletJSON() async throws {
	let dataStore = createTestDataStore()
	
	let incompleteJSON = """
	{
	  "medications": []
	}
	""".data(using: .utf8)!
	
	await #expect(throws: (any Error).self) {
	  try await dataStore.importDataFromJSON(incompleteJSON)
	}
  }
  
  // MARK: - Clear Data Tests

  @Test("Clear all data should remove everything")
  func testClearAllData() async throws {
	let dataStore = createTestDataStore()
	
	// Add test data
	let testMedication = createTestMedication()
	let testEvent = createTestEvent()
	
	try await dataStore.addMedication(testMedication)
	try await dataStore.addEvent(testEvent)
	
	#expect(dataStore.medications.count == 1)
	#expect(dataStore.events.count == 1)
	
	// Clear all data
	try await dataStore.clearAllData()
	
	// Verify everything is gone
	#expect(dataStore.medications.count == 0)
	#expect(dataStore.events.count == 0)
  }
  
  // MARK: - Round-trip Tests

  @Test("Export then import should preserve data integrity")
  func testRoundTripDataIntegrity() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Add original test data
	let originalMedication = createTestMedication()
	let originalEvent = createTestEvent(medicationId: originalMedication.id)
	
	try await dataStore.addMedication(originalMedication)
	try await dataStore.addEvent(originalEvent)
	
	// Export data
	let exportedData = try await dataStore.exportDataAsJSON()
	
	// Clear and import
	try await dataStore.clearAllData()
	try await dataStore.importDataFromJSON(exportedData)
	
	// Verify data integrity
	let medications = dataStore.medications
	let events = dataStore.events
	
	#expect(medications.count == 1)
	#expect(events.count == 1)
	
	guard let importedMedication = medications.first else {
	  #expect(Bool(false), "No medications found after import")
	  return
	}
	guard let importedEvent = events.first else {
	  #expect(Bool(false), "No events found after import")
	  return
	}
	
	// Verify medication data
	#expect(importedMedication.id == originalMedication.id)
	#expect(importedMedication.clinicalName == originalMedication.clinicalName)
	#expect(importedMedication.nickname == originalMedication.nickname)
	#expect(importedMedication.quantity == originalMedication.quantity)
	#expect(importedMedication.prescribedDoseAmount == originalMedication.prescribedDoseAmount)
	
	// Verify event data  
	#expect(importedEvent.id == originalEvent.id)
	#expect(importedEvent.eventType == originalEvent.eventType)
	#expect(importedEvent.medication?.id == originalEvent.medication?.id)
	#expect(importedEvent.dose?.amount == originalEvent.dose?.amount)
  }
  
  @Test("Multiple round-trips should maintain data integrity")
  func testMultipleRoundTrips() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Add original data
	let originalMedication = createTestMedication()
	try await dataStore.addMedication(originalMedication)
	
	var lastExportedData: Data?
	
	// Perform multiple export/import cycles
	for cycle in 1...3 {
	  // Export
	  let exportedData = try await dataStore.exportDataAsJSON()
	  
	  // Clear and import
	  try await dataStore.clearAllData()
	  try await dataStore.importDataFromJSON(exportedData)
	  
	  // Verify data still intact
	  #expect(dataStore.medications.count == 1, "Cycle \(cycle): Should have 1 medication")
	  
	  let medication = dataStore.medications.first
	  #expect(medication?.clinicalName == "Test Medication", "Cycle \(cycle): Clinical name should be preserved")
	  #expect(medication?.quantity == 30.0, "Cycle \(cycle): Quantity should be preserved")
	  
	  lastExportedData = exportedData
	}
	
	// Final verification - parse the JSON to ensure it's still valid
	guard let lastData = lastExportedData else {
	  #expect(Bool(false), "No export data available")
	  return
	}
	let finalJSON = try JSONSerialization.jsonObject(with: lastData) as? [String: Any]
	#expect(finalJSON != nil, "Final JSON should be valid after multiple cycles")
  }
  
  // MARK: - Redaction Tests

  @Test("Export with name redaction should redact all clinical names and nicknames")
  func testExportWithRedaction() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Create medication with both clinical name and nickname
	let medication = ANMedicationConcept(
	  clinicalName: "Sensitive Medication Name",
	  nickname: "Secret Nickname"
	)
	
	let event = ANEventConcept(
	  eventType: .doseTaken,
	  medication: medication,
	  date: Date()
	)
	
	try await dataStore.addMedication(medication)
	try await dataStore.addEvent(event)
	
	// Export with redaction
	let redactedData = try await dataStore.exportDataAsJSON(redactNames: true)
	let redactedJSON = try JSONSerialization.jsonObject(with: redactedData) as? [String: Any]
	
	// Verify medication names are redacted
	guard let medications = redactedJSON?["medications"] as? [[String: Any]], 
		  let exportedMed = medications.first else {
	  #expect(Bool(false), "No medications found in redacted export")
	  return
	}
	
	#expect(exportedMed["clinicalName"] as? String == "[REDACTED]")
	#expect(exportedMed["nickname"] as? String == "[REDACTED]")
	
	// Verify event medication names are also redacted
	guard let events = redactedJSON?["events"] as? [[String: Any]],
		  let exportedEvent = events.first,
		  let eventMedication = exportedEvent["medication"] as? [String: Any] else {
	  #expect(Bool(false), "No events or medication found in redacted export")
	  return
	}
	
	#expect(eventMedication["clinicalName"] as? String == "[REDACTED]")
	#expect(eventMedication["nickname"] as? String == "[REDACTED]")
  }
  
  @Test("Export without redaction should preserve all names")
  func testExportWithoutRedaction() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let medication = ANMedicationConcept(
	  clinicalName: "Real Medication Name",
	  nickname: "Real Nickname"
	)
	
	try await dataStore.addMedication(medication)
	
	// Export without redaction (default behavior)
	let normalData = try await dataStore.exportDataAsJSON()
	let normalJSON = try JSONSerialization.jsonObject(with: normalData) as? [String: Any]
	
	// Verify names are preserved
	guard let medications = normalJSON?["medications"] as? [[String: Any]],
		  let exportedMed = medications.first else {
	  #expect(Bool(false), "No medications found in normal export")
	  return
	}
	
	#expect(exportedMed["clinicalName"] as? String == "Real Medication Name")
	#expect(exportedMed["nickname"] as? String == "Real Nickname")
  }

  // MARK: - Edge Cases

  @Test("Export with special characters should work")
  func testExportWithSpecialCharacters() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let specialMedication = ANMedicationConcept(
	  clinicalName: "Spéciäl Médication with émojis 💊",
	  nickname: "Tëst with ünîcødé & symbols!@#$%"
	)
	
	try await dataStore.addMedication(specialMedication)
	
	let exportedData = try await dataStore.exportDataAsJSON()
	
	// Should not throw and should be valid JSON
	let json = try JSONSerialization.jsonObject(with: exportedData) as? [String: Any]
	#expect(json != nil)
	
	// Import should work too
	try await dataStore.importDataFromJSON(exportedData)
	
	guard let importedMedication = dataStore.medications.first else {
	  #expect(Bool(false), "No medications found after import")
	  return
	}
	#expect(importedMedication.clinicalName == "Spéciäl Médication with émojis 💊")
	#expect(importedMedication.nickname == "Tëst with ünîcødé & symbols!@#$%")
  }
  
  @Test("Export with nil optional values should work")
  func testExportWithNilValues() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let minimalMedication = ANMedicationConcept(
	  clinicalName: "Minimal Medication"
	  // All other fields are nil
	)
	
	try await dataStore.addMedication(minimalMedication)
	
	let exportedData = try await dataStore.exportDataAsJSON()
	
	// Should be valid JSON
	let json = try JSONSerialization.jsonObject(with: exportedData) as? [String: Any]
	#expect(json != nil)
	
	// Round-trip should preserve nil values
	try await dataStore.importDataFromJSON(exportedData)
	
	guard let importedMedication = dataStore.medications.first else {
	  #expect(Bool(false), "No medications found after import")
	  return
	}
	#expect(importedMedication.clinicalName == "Minimal Medication")
	#expect(importedMedication.nickname == nil)
	#expect(importedMedication.quantity == nil)
	#expect(importedMedication.lastRefillDate == nil)
  }
}

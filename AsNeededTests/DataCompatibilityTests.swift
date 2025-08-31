//
//  DataCompatibilityTests.swift
//  AsNeededTests
//
//  Tests for backwards compatibility and future-proofing of data import/export
//

import Testing
import Foundation
@testable import AsNeeded
@testable import ANModelKit

@MainActor
struct DataCompatibilityTests {
  
  func createTestDataStore() -> DataStore {
	return DataStore(testIdentifier: UUID().uuidString)
  }
  
  // MARK: - Version Compatibility Tests

  @Test("Import data from hypothetical older version should work")
  func testImportOlderVersionFormat() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Simulate older version format (missing some new fields)
	let olderVersionJSONString = """
	{
	  "medications": [
		{
		  "id": "123e4567-e89b-12d3-a456-426614174000",
		  "clinicalName": "Old Format Med",
		  "quantity": 30.0
		}
	  ],
	  "events": [
		{
		  "id": "987e6543-e21c-34f5-b678-987654321000", 
		  "eventType": "dose_taken",
		  "date": "2022-01-01T12:00:00Z"
		}
	  ],
	  "exportDate": "2022-01-01T12:00:00Z",
	  "appVersion": "0.1.0"
	}
	"""
	
	guard let olderVersionJSON = olderVersionJSONString.data(using: .utf8) else {
	  #expect(false, "Failed to create test JSON data")
	  return
	}
	
	// Should import successfully despite missing optional fields
	try await dataStore.importDataFromJSON(olderVersionJSON)
	
	#expect(dataStore.medications.count == 1)
	#expect(dataStore.events.count == 1)
	
	let medication = dataStore.medications.first
	#expect(medication?.clinicalName == "Old Format Med")
	#expect(medication?.quantity == 30.0)
	#expect(medication?.nickname == nil) // Missing field should be nil
  }
  
  @Test("Import should handle missing optional fields gracefully")
  func testImportMissingOptionalFields() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let minimalJSONString = """
	{
	  "medications": [
		{
		  "id": "123e4567-e89b-12d3-a456-426614174000",
		  "clinicalName": "Minimal Med"
		}
	  ],
	  "events": [
		{
		  "id": "987e6543-e21c-34f5-b678-987654321000",
		  "eventType": "dose_taken",
		  "date": "2022-01-01T12:00:00Z"
		}
	  ],
	  "exportDate": "2022-01-01T12:00:00Z",
	  "appVersion": "1.0.0"
	}
	"""
	
	guard let minimalJSON = minimalJSONString.data(using: .utf8) else {
	  #expect(false, "Failed to create test JSON data")
	  return
	}
	
	try await dataStore.importDataFromJSON(minimalJSON)
	
	let medication = dataStore.medications.first
	#expect(medication?.clinicalName == "Minimal Med")
	#expect(medication?.nickname == nil)
	#expect(medication?.quantity == nil)
	#expect(medication?.prescribedDoseAmount == nil)
	#expect(medication?.prescribedUnit == nil)
	
	guard let event = dataStore.events.first else {
	  #expect(false, "No events found after import")
	  return
	}
	#expect(event.eventType == .doseTaken)
	#expect(event.medication == nil)
	#expect(event.dose == nil)
  }
  
  @Test("Export should include all current fields for future compatibility")
  func testExportIncludesAllFields() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Create medication with all fields populated
	let fullMedication = ANMedicationConcept(
	  clinicalName: "Full Medication",
	  nickname: "Full Med",
	  quantity: 60.0,
	  lastRefillDate: Date(timeIntervalSince1970: 1640995200),
	  nextRefillDate: Date(timeIntervalSince1970: 1643673600),
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 750.0
	)
	
	let fullEvent = ANEventConcept(
	  eventType: .doseTaken,
	  medication: fullMedication,
	  dose: ANDoseConcept(amount: 750.0, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1640995200)
	)
	
	try await dataStore.addMedication(fullMedication)
	try await dataStore.addEvent(fullEvent)
	
	let exportData = try await dataStore.exportDataAsJSON()
	guard let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any] else {
	  #expect(false, "Failed to parse exported JSON")
	  return
	}
	
	// Verify all medication fields are present
	guard let medications = json["medications"] as? [[String: Any]], !medications.isEmpty else {
	  #expect(false, "No medications found in exported JSON")
	  return
	}
	guard let medication = medications.first else {
	  #expect(false, "No medication data found")
	  return
	}
	
	#expect(medication["id"] != nil)
	#expect(medication["clinicalName"] != nil)
	#expect(medication["nickname"] != nil)
	#expect(medication["quantity"] != nil)
	#expect(medication["lastRefillDate"] != nil)
	#expect(medication["nextRefillDate"] != nil)
	#expect(medication["prescribedUnit"] != nil)
	#expect(medication["prescribedDoseAmount"] != nil)
	
	// Verify all event fields are present
	guard let events = json["events"] as? [[String: Any]], !events.isEmpty else {
	  #expect(false, "No events found in exported JSON")
	  return
	}
	guard let event = events.first else {
	  #expect(false, "No event data found")
	  return
	}
	
	#expect(event["id"] != nil)
	#expect(event["eventType"] != nil)
	#expect(event["date"] != nil)
	#expect(event["medication"] != nil)
	#expect(event["dose"] != nil)
  }
  
  // MARK: - Data Format Evolution Tests

  @Test("Import should handle unknown fields gracefully")
  func testImportWithUnknownFields() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// JSON with hypothetical future fields
	let futureJSONString = """
	{
	  "medications": [
		{
		  "id": "123e4567-e89b-12d3-a456-426614174000",
		  "clinicalName": "Future Med",
		  "nickname": "Future",
		  "quantity": 30.0,
		  "futureField": "unknown value",
		  "anotherNewField": {
			"nestedValue": 123
		  }
		}
	  ],
	  "events": [
		{
		  "id": "987e6543-e21c-34f5-b678-987654321000",
		  "eventType": "dose_taken", 
		  "date": "2022-01-01T12:00:00Z",
		  "futureEventField": "future data"
		}
	  ],
	  "exportDate": "2022-01-01T12:00:00Z",
	  "appVersion": "2.0.0",
	  "futureMetadata": {
		"newFeature": "enabled"
	  }
	}
	"""
	
	guard let futureJSON = futureJSONString.data(using: .utf8) else {
	  #expect(false, "Failed to create test JSON data")
	  return
	}
	
	// Should import successfully, ignoring unknown fields
	try await dataStore.importDataFromJSON(futureJSON)
	
	#expect(dataStore.medications.count == 1)
	#expect(dataStore.events.count == 1)
	
	guard let medication = dataStore.medications.first else {
	  #expect(false, "No medications found after import")
	  return
	}
	#expect(medication.clinicalName == "Future Med")
	#expect(medication.nickname == "Future")
	#expect(medication.quantity == 30.0)
  }
  
  // MARK: - Date Format Compatibility Tests

  @Test("Import should handle various date formats")
  func testImportVariousDateFormats() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Test with different valid ISO 8601 formats
	let dateVariationsJSONString = """
	{
	  "medications": [
		{
		  "id": "123e4567-e89b-12d3-a456-426614174000",
		  "clinicalName": "Date Test Med",
		  "lastRefillDate": "2022-01-01T12:00:00Z",
		  "nextRefillDate": "2022-02-01T12:00:00.000Z"
		}
	  ],
	  "events": [
		{
		  "id": "987e6543-e21c-34f5-b678-987654321000",
		  "eventType": "dose_taken",
		  "date": "2022-01-01T12:00:00.123Z"
		}
	  ],
	  "exportDate": "2022-01-01T12:00:00Z",
	  "appVersion": "1.0.0"
	}
	"""
	
	guard let dateVariationsJSON = dateVariationsJSONString.data(using: .utf8) else {
	  #expect(false, "Failed to create test JSON data")
	  return
	}
	
	try await dataStore.importDataFromJSON(dateVariationsJSON)
	
	guard let medication = dataStore.medications.first else {
	  #expect(false, "No medications found after import")
	  return
	}
	#expect(medication.lastRefillDate != nil)
	#expect(medication.nextRefillDate != nil)
	
	guard let event = dataStore.events.first else {
	  #expect(false, "No events found after import")
	  return
	}
	#expect(event.date.timeIntervalSince1970 > 0)
  }
  
  // MARK: - Large Data Set Tests

  @Test("Import/Export should handle large datasets")
  func testLargeDatasetHandling() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Create a reasonably large dataset
	let medicationCount = 50
	let eventCount = 200
	
	// Add medications
	for i in 1...medicationCount {
	  let medication = ANMedicationConcept(
		clinicalName: "Medication \(i)",
		nickname: "Med\(i)",
		quantity: Double(i * 10)
	  )
	  try await dataStore.addMedication(medication)
	}
	
	// Add events
	for i in 1...eventCount {
	  let event = ANEventConcept(
		eventType: .doseTaken,
		date: Date(timeIntervalSince1970: TimeInterval(1640995200 + i * 3600))
	  )
	  try await dataStore.addEvent(event)
	}
	
	// Export should complete successfully
	let exportData = try await dataStore.exportDataAsJSON()
	#expect(exportData.count > 10000) // Should be substantial amount of data
	
	// Clear and import back
	try await dataStore.clearAllData()
	try await dataStore.importDataFromJSON(exportData)
	
	// Verify all data was restored
	#expect(dataStore.medications.count == medicationCount)
	#expect(dataStore.events.count == eventCount)
	
	// Spot check some data
	guard let firstMed = dataStore.medications.first(where: { $0.clinicalName == "Medication 1" }) else {
	  #expect(false, "Could not find Medication 1 after import")
	  return
	}
	#expect(firstMed.nickname == "Med1")
	#expect(firstMed.quantity == 10.0)
  }
  
  // MARK: - Character Encoding Tests

  @Test("Import/Export should handle international characters")
  func testInternationalCharacters() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let internationalMeds = [
	  ANMedicationConcept(clinicalName: "Paracétamol", nickname: "Tylenol français"),
	  ANMedicationConcept(clinicalName: "Ibuproféno", nickname: "Advil español"),
	  ANMedicationConcept(clinicalName: "アスピリン", nickname: "日本語"),
	  ANMedicationConcept(clinicalName: "Аспирин", nickname: "русский"),
	  ANMedicationConcept(clinicalName: "阿司匹林", nickname: "中文"),
	  ANMedicationConcept(clinicalName: "💊 Emoji Med", nickname: "🩺⚕️🏥"),
	]
	
	for med in internationalMeds {
	  try await dataStore.addMedication(med)
	}
	
	// Export and import
	let exportData = try await dataStore.exportDataAsJSON()
	try await dataStore.clearAllData()
	try await dataStore.importDataFromJSON(exportData)
	
	// Verify all international characters preserved
	#expect(dataStore.medications.count == internationalMeds.count)
	
	for originalMed in internationalMeds {
	  guard let imported = dataStore.medications.first(where: { $0.clinicalName == originalMed.clinicalName }) else {
		#expect(false, "Should find medication with name: \(originalMed.clinicalName)")
		continue
	  }
	  #expect(imported.nickname == originalMed.nickname)
	}
  }
  
  // MARK: - JSON Structure Validation Tests

  @Test("Export should produce consistent JSON structure")
  func testConsistentJSONStructure() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Test multiple exports produce same structure
	let export1 = try await dataStore.exportDataAsJSON()
	let export2 = try await dataStore.exportDataAsJSON()
	
	guard let json1 = try JSONSerialization.jsonObject(with: export1) as? [String: Any] else {
	  #expect(false, "Failed to parse first export JSON")
	  return
	}
	guard let json2 = try JSONSerialization.jsonObject(with: export2) as? [String: Any] else {
	  #expect(false, "Failed to parse second export JSON")
	  return
	}
	
	// Should have same top-level keys
	let keys1 = Set(json1.keys)
	let keys2 = Set(json2.keys)
	#expect(keys1 == keys2)
	
	// Required keys should always be present
	let requiredKeys: Set<String> = ["medications", "events", "exportDate", "appVersion"]
	#expect(keys1.isSuperset(of: requiredKeys))
  }
  
  // MARK: - Error Recovery Tests

  @Test("Partial import failure should not corrupt existing data")
  func testPartialImportFailure() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Add some existing data
	let existingMed = ANMedicationConcept(clinicalName: "Existing Med")
	try await dataStore.addMedication(existingMed)
	
	#expect(dataStore.medications.count == 1)
	
	// Try to import malformed JSON that should fail
	let malformedJSONString = """
	{
	  "medications": [
		{
		  "id": "not-a-valid-uuid",
		  "clinicalName": "Bad Med"
		}
	  ],
	  "events": [],
	  "exportDate": "invalid-date",
	  "appVersion": "1.0.0"
	}
	"""
	
	guard let malformedJSON = malformedJSONString.data(using: .utf8) else {
	  #expect(false, "Failed to create test JSON data")
	  return
	}
	
	// Import should fail
	await #expect(throws: (any Error).self) {
	  try await dataStore.importDataFromJSON(malformedJSON)
	}
	
	// Since JSON parsing failed before clearing data, existing data should remain
	// (This is the expected behavior - only clear data if JSON is valid)
	#expect(dataStore.medications.count == 1)
  }
}

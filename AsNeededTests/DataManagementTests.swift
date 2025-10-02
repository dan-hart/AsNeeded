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
@Suite(.tags(.dataManagement, .unit))
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
	  initialQuantity: 60.0,
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

  // MARK: - Critical Integration Tests

  // ⚠️ DO NOT DELETE OR DISABLE THIS TEST ⚠️
  // This test ensures data import/export integrity is never broken.
  // If this test fails, users could lose their medication data.
  @Test("CRITICAL: Full data export-import cycle must preserve all data integrity")
  func testComprehensiveDataExportImportIntegrity() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()

	// MARK: Create comprehensive test dataset

	// Create diverse medications with various configurations
	let med1 = ANMedicationConcept(
	  id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
	  clinicalName: "Acetaminophen",
	  nickname: "Tylenol",
	  quantity: 100.0,
	  initialQuantity: 200.0,
	  lastRefillDate: Date(timeIntervalSince1970: 1640995200),
	  nextRefillDate: Date(timeIntervalSince1970: 1643673600),
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 500.0
	)

	let med2 = ANMedicationConcept(
	  id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
	  clinicalName: "Ibuprofen",
	  nickname: nil, // No nickname
	  quantity: 50.0,
	  initialQuantity: 100.0,
	  lastRefillDate: Date(timeIntervalSince1970: 1641081600),
	  nextRefillDate: nil, // No next refill
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 200.0
	)

	let med3 = ANMedicationConcept(
	  id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
	  clinicalName: "Spéciäl Médication with Ünîcødé 💊",
	  nickname: "Émoji Med! @#$%",
	  quantity: nil, // No quantity tracked
	  initialQuantity: 30.0,
	  lastRefillDate: nil,
	  nextRefillDate: nil,
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 10.0
	)

	let med4 = ANMedicationConcept(
	  id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
	  clinicalName: "Minimal Medication",
	  nickname: nil,
	  quantity: nil,
	  initialQuantity: nil,
	  lastRefillDate: nil,
	  nextRefillDate: nil,
	  prescribedUnit: nil,
	  prescribedDoseAmount: nil
	)

	let med5 = ANMedicationConcept(
	  id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
	  clinicalName: "Full Specification Medication",
	  nickname: "Full Spec",
	  quantity: 90.0,
	  initialQuantity: 180.0,
	  lastRefillDate: Date(timeIntervalSince1970: 1642291200),
	  nextRefillDate: Date(timeIntervalSince1970: 1644883200),
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 750.0
	)

	let med6 = ANMedicationConcept(
	  id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
	  clinicalName: "Test \"Quotes\" and 'Apostrophes'",
	  nickname: "Punctuation",
	  quantity: 30.0,
	  initialQuantity: 60.0,
	  lastRefillDate: Date(timeIntervalSince1970: 1640995200),
	  nextRefillDate: Date(timeIntervalSince1970: 1643673600),
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 100.0
	)

	let med7 = ANMedicationConcept(
	  id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
	  clinicalName: "Low Dose Medication",
	  nickname: "Low",
	  quantity: 15.0,
	  initialQuantity: 30.0,
	  lastRefillDate: nil,
	  nextRefillDate: Date(timeIntervalSince1970: 1650000000),
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 2.5
	)

	let med8 = ANMedicationConcept(
	  id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
	  clinicalName: "High Dose Medication",
	  nickname: "High",
	  quantity: 200.0,
	  initialQuantity: 300.0,
	  lastRefillDate: Date(timeIntervalSince1970: 1640995200),
	  nextRefillDate: Date(timeIntervalSince1970: 1643673600),
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 1000.0
	)

	let med9 = ANMedicationConcept(
	  id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
	  clinicalName: "Recent Medication",
	  nickname: "Recent",
	  quantity: 60.0,
	  initialQuantity: 120.0,
	  lastRefillDate: Date(timeIntervalSince1970: 1700000000),
	  nextRefillDate: Date(timeIntervalSince1970: 1705000000),
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 50.0
	)

	let med10 = ANMedicationConcept(
	  id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
	  clinicalName: "Old Medication",
	  nickname: "Old",
	  quantity: 5.0,
	  initialQuantity: 10.0,
	  lastRefillDate: Date(timeIntervalSince1970: 1600000000),
	  nextRefillDate: Date(timeIntervalSince1970: 1605000000),
	  prescribedUnit: ANUnitConcept.milligram,
	  prescribedDoseAmount: 25.0
	)

	// Add all medications
	let allMedications = [med1, med2, med3, med4, med5, med6, med7, med8, med9, med10]
	for medication in allMedications {
	  try await dataStore.addMedication(medication)
	}

	// Create diverse events for each medication
	var allEvents: [ANEventConcept] = []

	// Med1: Multiple events with different types and notes
	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000001-0000-0000-0000-000000000001")!,
	  eventType: .doseTaken,
	  medication: med1,
	  dose: ANDoseConcept(amount: 500.0, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1641000000),
	  note: "Took with breakfast"
	))

	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000001-0000-0000-0000-000000000002")!,
	  eventType: .doseTaken,
	  medication: med1,
	  dose: ANDoseConcept(amount: 500.0, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1641086400),
	  note: nil // No note
	))

	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000001-0000-0000-0000-000000000003")!,
	  eventType: .doseTaken,
	  medication: med1,
	  dose: nil,
	  date: Date(timeIntervalSince1970: 1641172800),
	  note: "Felt better, skipped evening dose"
	))

	// Med2: Events with special characters in notes
	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000002-0000-0000-0000-000000000001")!,
	  eventType: .doseTaken,
	  medication: med2,
	  dose: ANDoseConcept(amount: 200.0, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1641100000),
	  note: "Note with émojis 😊 and spëcial çharacters!"
	))

	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000002-0000-0000-0000-000000000002")!,
	  eventType: .doseTaken,
	  medication: med2,
	  dose: ANDoseConcept(amount: 200.0, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1641200000),
	  note: "Quotes \"test\" and 'apostrophes' in notes"
	))

	// Med3: Unicode medication with events
	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000003-0000-0000-0000-000000000001")!,
	  eventType: .doseTaken,
	  medication: med3,
	  dose: ANDoseConcept(amount: 10.0, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1641300000),
	  note: "Testing ünîcødé persistence"
	))

	// Med4: Minimal medication with minimal event
	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000004-0000-0000-0000-000000000001")!,
	  eventType: .doseTaken,
	  medication: med4,
	  dose: nil, // No dose information
	  date: Date(timeIntervalSince1970: 1641400000),
	  note: nil
	))

	// Med5: Multiple events at different times
	for i in 1...5 {
	  allEvents.append(ANEventConcept(
		id: UUID(uuidString: "e0000005-0000-0000-0000-00000000000\(i)")!,
		eventType: .doseTaken,
		medication: med5,
		dose: ANDoseConcept(amount: 750.0, unit: ANUnitConcept.milligram),
		date: Date(timeIntervalSince1970: 1642291200 + TimeInterval(i * 86400)),
		note: i % 2 == 0 ? "Even dose \(i)" : nil
	  ))
	}

	// Med6-10: Additional events to reach 30+ total
	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000006-0000-0000-0000-000000000001")!,
	  eventType: .doseTaken,
	  medication: med6,
	  dose: ANDoseConcept(amount: 100.0, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1641500000),
	  note: nil
	))

	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000007-0000-0000-0000-000000000001")!,
	  eventType: .doseTaken,
	  medication: med7,
	  dose: ANDoseConcept(amount: 2.5, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1641600000),
	  note: "Low dose test"
	))

	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000007-0000-0000-0000-000000000002")!,
	  eventType: .doseTaken,
	  medication: med7,
	  dose: nil,
	  date: Date(timeIntervalSince1970: 1641700000),
	  note: nil
	))

	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000008-0000-0000-0000-000000000001")!,
	  eventType: .doseTaken,
	  medication: med8,
	  dose: ANDoseConcept(amount: 1000.0, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1641800000),
	  note: "High dose medication"
	))

	allEvents.append(ANEventConcept(
	  id: UUID(uuidString: "e0000008-0000-0000-0000-000000000002")!,
	  eventType: .doseTaken,
	  medication: med8,
	  dose: ANDoseConcept(amount: 1000.0, unit: ANUnitConcept.milligram),
	  date: Date(timeIntervalSince1970: 1641900000),
	  note: nil
	))

	for i in 1...3 {
	  allEvents.append(ANEventConcept(
		id: UUID(uuidString: "e0000009-0000-0000-0000-00000000000\(i)")!,
		eventType: .doseTaken,
		medication: med9,
		dose: ANDoseConcept(amount: 50.0, unit: ANUnitConcept.milligram),
		date: Date(timeIntervalSince1970: 1700000000 + TimeInterval(i * 3600)),
		note: i == 2 ? "Recent medication note" : nil
	  ))
	}

	for i in 1...3 {
	  allEvents.append(ANEventConcept(
		id: UUID(uuidString: "e000000a-0000-0000-0000-00000000000\(i)")!,
		eventType: .doseTaken,
		medication: med10,
		dose: ANDoseConcept(amount: 25.0, unit: ANUnitConcept.milligram),
		date: Date(timeIntervalSince1970: 1600000000 + TimeInterval(i * 3600)),
		note: "Old medication event \(i)"
	  ))
	}

	// Add all events
	for event in allEvents {
	  try await dataStore.addEvent(event)
	}

	// Verify initial state
	#expect(dataStore.medications.count == 10, "Should have 10 medications before export")
	#expect(dataStore.events.count == allEvents.count, "Should have \(allEvents.count) events before export")

	// MARK: Export data

	let exportedData = try await dataStore.exportDataAsJSON()
	#expect(exportedData.count > 0, "Export data should not be empty")

	// Verify it's valid JSON
	let exportJSON = try JSONSerialization.jsonObject(with: exportedData) as? [String: Any]
	#expect(exportJSON != nil, "Export should produce valid JSON")

	// MARK: Clear all data

	try await dataStore.clearAllData()

	// Verify data is completely cleared
	#expect(dataStore.medications.count == 0, "All medications should be cleared")
	#expect(dataStore.events.count == 0, "All events should be cleared")

	// MARK: Import data back

	try await dataStore.importDataFromJSON(exportedData)

	// MARK: Verify complete data integrity

	// Verify counts
	#expect(dataStore.medications.count == 10, "Should restore exactly 10 medications")
	#expect(dataStore.events.count == allEvents.count, "Should restore exactly \(allEvents.count) events")

	// Verify each medication in detail
	for originalMed in allMedications {
	  guard let importedMed = dataStore.medications.first(where: { $0.id == originalMed.id }) else {
		#expect(Bool(false), "Medication \(originalMed.id) not found after import")
		continue
	  }

	  #expect(importedMed.clinicalName == originalMed.clinicalName,
		"Medication \(originalMed.id): Clinical name mismatch")
	  #expect(importedMed.nickname == originalMed.nickname,
		"Medication \(originalMed.id): Nickname mismatch")
	  #expect(importedMed.initialQuantity == originalMed.initialQuantity,
		"Medication \(originalMed.id): Initial quantity mismatch")
	  #expect(importedMed.quantity == originalMed.quantity,
		"Medication \(originalMed.id): Quantity mismatch")
	  #expect(importedMed.prescribedDoseAmount == originalMed.prescribedDoseAmount,
		"Medication \(originalMed.id): Prescribed dose amount mismatch")

	  // Compare dates with tolerance for JSON serialization
	  if let originalRefill = originalMed.lastRefillDate, let importedRefill = importedMed.lastRefillDate {
		#expect(abs(originalRefill.timeIntervalSince1970 - importedRefill.timeIntervalSince1970) < 1.0,
		  "Medication \(originalMed.id): Last refill date mismatch")
	  } else {
		#expect(originalMed.lastRefillDate == nil && importedMed.lastRefillDate == nil,
		  "Medication \(originalMed.id): Last refill date nil mismatch")
	  }

	  if let originalNext = originalMed.nextRefillDate, let importedNext = importedMed.nextRefillDate {
		#expect(abs(originalNext.timeIntervalSince1970 - importedNext.timeIntervalSince1970) < 1.0,
		  "Medication \(originalMed.id): Next refill date mismatch")
	  } else {
		#expect(originalMed.nextRefillDate == nil && importedMed.nextRefillDate == nil,
		  "Medication \(originalMed.id): Next refill date nil mismatch")
	  }
	}

	// Verify each event in detail
	for originalEvent in allEvents {
	  guard let importedEvent = dataStore.events.first(where: { $0.id == originalEvent.id }) else {
		#expect(Bool(false), "Event \(originalEvent.id) not found after import")
		continue
	  }

	  #expect(importedEvent.eventType == originalEvent.eventType,
		"Event \(originalEvent.id): Event type mismatch")
	  #expect(importedEvent.note == originalEvent.note,
		"Event \(originalEvent.id): Note mismatch")

	  // Verify medication reference
	  if let originalMed = originalEvent.medication, let importedMed = importedEvent.medication {
		#expect(importedMed.id == originalMed.id,
		  "Event \(originalEvent.id): Medication ID mismatch")
		#expect(importedMed.clinicalName == originalMed.clinicalName,
		  "Event \(originalEvent.id): Medication clinical name mismatch")
	  } else {
		#expect(originalEvent.medication == nil && importedEvent.medication == nil,
		  "Event \(originalEvent.id): Medication reference nil mismatch")
	  }

	  // Verify dose
	  if let originalDose = originalEvent.dose, let importedDose = importedEvent.dose {
		#expect(importedDose.amount == originalDose.amount,
		  "Event \(originalEvent.id): Dose amount mismatch")
	  } else {
		#expect(originalEvent.dose == nil && importedEvent.dose == nil,
		  "Event \(originalEvent.id): Dose nil mismatch")
	  }

	  // Verify date with tolerance
	  #expect(abs(importedEvent.date.timeIntervalSince1970 - originalEvent.date.timeIntervalSince1970) < 1.0,
		"Event \(originalEvent.id): Date mismatch")
	}

	// Verify relationships: all events should reference valid medications
	for event in dataStore.events {
	  if let eventMedication = event.medication {
		guard let matchingMed = dataStore.medications.first(where: { $0.id == eventMedication.id }) else {
		  #expect(Bool(false), "Event \(event.id) references non-existent medication \(eventMedication.id)")
		  continue
		}
		#expect(matchingMed.clinicalName == eventMedication.clinicalName,
		  "Event \(event.id) medication reference has mismatched clinical name")
	  }
	}
  }
}

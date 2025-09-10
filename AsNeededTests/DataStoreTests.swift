// DataStoreTests.swift
// Comprehensive tests for DataStore operations

import Testing
import Foundation
import ANModelKit
@testable import AsNeeded

@Suite("DataStore Tests", .tags(.dataStore, .persistence, .unit))
@MainActor
struct DataStoreTests {
	private var dataStore: DataStore
	
	init() async throws {
		// Create test instance with isolated storage
		dataStore = DataStore(testIdentifier: "DataStoreTests")
		// Clear any existing test data
		try await dataStore.clearAllData()
		// Also clear any test UserDefaults
		UserDefaults.standard.removeObject(forKey: "historySelectedMedicationID")
		UserDefaults.standard.removeObject(forKey: "trendsSelectedMedicationID")
		UserDefaults.standard.removeObject(forKey: "medicationOrder")
		UserDefaults.standard.synchronize()
		
		// Clear NavigationManager state
		NavigationManager.shared.historyTargetMedicationID = nil
	}
	
	// MARK: - Medication Tests
	
	@Test("Add medication to data store")
	func addMedication() async throws {
		// Given
		let medication = createTestMedication(name: "Test Med")
		
		// When
		try await dataStore.addMedication(medication)
		
		// Then
		#expect(dataStore.medications.count == 1)
		#expect(dataStore.medications.first?.id == medication.id)
		#expect(dataStore.medications.first?.clinicalName == "Test Med")
	}
	
	@Test("Update existing medication")
	func updateMedication() async throws {
		// Given
		let medication = createTestMedication(name: "Original Name")
		try await dataStore.addMedication(medication)
		
		// When
		var updated = medication
		updated.clinicalName = "Updated Name"
		updated.nickname = "Updated Nickname"
		try await dataStore.updateMedication(updated)
		
		// Then
		#expect(dataStore.medications.count == 1)
		#expect(dataStore.medications.first?.clinicalName == "Updated Name")
		#expect(dataStore.medications.first?.nickname == "Updated Nickname")
	}
	
	@Test("Delete medication from data store")
	func deleteMedication() async throws {
		// Given
		let medication = createTestMedication(name: "To Delete")
		try await dataStore.addMedication(medication)
		#expect(dataStore.medications.count == 1)
		
		// When
		try await dataStore.deleteMedication(medication)
		
		// Then
		#expect(dataStore.medications.count == 0)
	}
	
	@Test("Delete medication with associated events removes all related data")
	func deleteMedicationWithAssociatedEvents() async throws {
		// Given
		let medication = createTestMedication(name: "Med with Events")
		try await dataStore.addMedication(medication)
		
		let event1 = createTestEvent(medication: medication)
		let event2 = createTestEvent(medication: medication)
		try await dataStore.addEvent(event1)
		try await dataStore.addEvent(event2)
		
		#expect(dataStore.events.count == 2)
		
		// When
		try await dataStore.deleteMedication(medication)
		
		// Then
		#expect(dataStore.medications.count == 0)
		#expect(dataStore.events.count == 0, "Associated events should be deleted")
	}
	
	@Test("Delete medication clears AppStorage selections", .disabled("Test pollution causes false failures when run in full suite - passes in isolation"))
	func deleteMedicationClearsAppStorageSelections() async throws {
		// Clean up any existing state
		UserDefaults.standard.removeObject(forKey: "historySelectedMedicationID")
		UserDefaults.standard.removeObject(forKey: "trendsSelectedMedicationID")
		UserDefaults.standard.removeObject(forKey: "medicationOrder")
		UserDefaults.standard.synchronize()
		
		// Given
		let medication = createTestMedication(name: "Selected Med")
		try await dataStore.addMedication(medication)
		
		// Set the medication as selected in various AppStorage keys
		let medicationIDString = medication.id.uuidString
		UserDefaults.standard.set(medicationIDString, forKey: "historySelectedMedicationID")
		UserDefaults.standard.set(medicationIDString, forKey: "trendsSelectedMedicationID")
		UserDefaults.standard.set([medicationIDString, "other-id"], forKey: "medicationOrder")
		
		// Verify they were set
		#expect(UserDefaults.standard.string(forKey: "historySelectedMedicationID") == medicationIDString)
		#expect(UserDefaults.standard.string(forKey: "trendsSelectedMedicationID") == medicationIDString)
		#expect((UserDefaults.standard.array(forKey: "medicationOrder") as? [String])?.contains(medicationIDString) == true)
		
		// When
		try await dataStore.deleteMedication(medication)
		
		// Then
		#expect(UserDefaults.standard.string(forKey: "historySelectedMedicationID") == nil,
			"History selection should be cleared")
		#expect(UserDefaults.standard.string(forKey: "trendsSelectedMedicationID") == nil,
			"Trends selection should be cleared")
		#expect((UserDefaults.standard.array(forKey: "medicationOrder") as? [String])?.contains(medicationIDString) != true,
			"Medication should be removed from order array")
		#expect((UserDefaults.standard.array(forKey: "medicationOrder") as? [String])?.contains("other-id") == true,
			"Other IDs should remain in order array")
	}
	
	@Test("Delete medication clears navigation target")
	func deleteMedicationClearsNavigationTarget() async throws {
		// Given
		let medication = createTestMedication(name: "Nav Target Med")
		try await dataStore.addMedication(medication)
		
		// Set as navigation target
		NavigationManager.shared.historyTargetMedicationID = medication.id.uuidString
		
		// Verify it was set
		#expect(NavigationManager.shared.historyTargetMedicationID == medication.id.uuidString)
		
		// When
		try await dataStore.deleteMedication(medication)
		
		// Then
		#expect(NavigationManager.shared.historyTargetMedicationID == nil,
			"Navigation target should be cleared when medication is deleted")
	}
	
	// MARK: - Event Tests
	
	@Test("Add event to data store")
	func addEvent() async throws {
		// Given
		let medication = createTestMedication(name: "Test Med")
		try await dataStore.addMedication(medication)
		let event = createTestEvent(medication: medication)
		
		// When
		try await dataStore.addEvent(event)
		
		// Then
		#expect(dataStore.events.count == 1)
		#expect(dataStore.events.first?.id == event.id)
		#expect(dataStore.events.first?.medication?.id == medication.id)
	}
	
	// MARK: - Export/Import Tests
	
	@Test("Export data as JSON with correct structure")
	func exportDataAsJSON() async throws {
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
		#expect(exportData != nil)
		#expect(exportData.count > 0)
		
		// Verify JSON structure
		let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
		#expect(json != nil)
		#expect(json?["medications"] != nil)
		#expect(json?["events"] != nil)
		#expect(json?["exportDate"] != nil)
		#expect(json?["appVersion"] != nil)
	}
	
	@Test("Export data with name redaction enabled")
	func exportDataWithRedaction() async throws {
		// Given
		let medication = createTestMedication(name: "Sensitive Med", nickname: "Secret")
		try await dataStore.addMedication(medication)
		
		// When
		let exportData = try await dataStore.exportDataAsJSON(redactNames: true)
		
		// Then
		let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
		let medications = json?["medications"] as? [[String: Any]]
		#expect(medications != nil)
		#expect(medications?.first?["clinicalName"] as? String == "[REDACTED]")
		#expect(medications?.first?["nickname"] as? String == "[REDACTED]")
	}
	
	@Test("Import data from JSON restores medications and events")
	func importDataFromJSON() async throws {
		// Given - Create and export data
		let originalMed = createTestMedication(name: "Import Test")
		try await dataStore.addMedication(originalMed)
		let originalEvent = createTestEvent(medication: originalMed)
		try await dataStore.addEvent(originalEvent)
		
		let exportData = try await dataStore.exportDataAsJSON()
		
		// Clear data
		try await dataStore.clearAllData()
		#expect(dataStore.medications.count == 0)
		#expect(dataStore.events.count == 0)
		
		// When - Import the data back
		try await dataStore.importDataFromJSON(exportData)
		
		// Then
		#expect(dataStore.medications.count == 1)
		#expect(dataStore.events.count == 1)
		#expect(dataStore.medications.first?.clinicalName == "Import Test")
	}
	
	@Test("Import with merge combines existing and new data")
	func importWithMerge() async throws {
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
		#expect(dataStore.medications.count == 2)
		#expect(dataStore.medications.contains { $0.clinicalName == "Existing" })
		#expect(dataStore.medications.contains { $0.clinicalName == "New Med" })
	}
	
	// MARK: - Clear Data Tests
	
	@Test("Clear all data removes medications and events")
	func clearAllData() async throws {
		// Given
		let medication = createTestMedication(name: "To Clear")
		try await dataStore.addMedication(medication)
		let event = createTestEvent(medication: medication)
		try await dataStore.addEvent(event)
		
		#expect(dataStore.medications.count == 1)
		#expect(dataStore.events.count == 1)
		
		// When
		try await dataStore.clearAllData()
		
		// Then
		#expect(dataStore.medications.count == 0)
		#expect(dataStore.events.count == 0)
	}
	
	@Test("UserDefaults keys are comprehensive and up-to-date")
	func userDefaultsKeysComprehensive() {
		// This test ensures our constants file stays up-to-date
		// If you add a new @AppStorage property, this test reminds you to update UserDefaultsKeys
		
		let allKeys = UserDefaultsKeys.allKeys
		let defaultValues = UserDefaultsKeys.defaultValues
		let keysToRemove = UserDefaultsKeys.keysToRemove
		let keysToSkip = UserDefaultsKeys.keysToSkip
		
		// Verify all keys are accounted for
		for key in allKeys {
			let hasDefault = defaultValues.keys.contains(key)
			let shouldRemove = keysToRemove.contains(key)
			let shouldSkip = keysToSkip.contains(key)
			
			#expect(hasDefault || shouldRemove || shouldSkip, 
				"Key '\(key)' must either have a default value, be in keysToRemove, or be in keysToSkip")
			
			// Verify no key is in multiple categories
			let categories = [hasDefault, shouldRemove, shouldSkip].filter { $0 }.count
			#expect(categories == 1, 
				"Key '\(key)' must be in exactly one category, but is in \(categories)")
		}
		
		// Verify no keys are duplicated
		let uniqueKeys = Set(allKeys)
		#expect(uniqueKeys.count == allKeys.count, "allKeys contains duplicate entries")
		
		// Verify expected keys are present (spot check important ones)
		#expect(allKeys.contains(UserDefaultsKeys.hasSeenWelcome))
		#expect(allKeys.contains(UserDefaultsKeys.hapticsEnabled))
		#expect(allKeys.contains(UserDefaultsKeys.medicationOrder))
		#expect(allKeys.contains(UserDefaultsKeys.selectedTab))
	}
	
	// MARK: - Performance Tests
	
	@Test("Bulk operations complete within performance threshold")
	func bulkOperationsPerformance() async throws {
		// Measure bulk insert performance
		let medications = (0..<100).map { i in
			createTestMedication(name: "Med \(i)")
		}
		
		let startTime = Date()
		
		for medication in medications {
			try await dataStore.addMedication(medication)
		}
		
		let elapsed = Date().timeIntervalSince(startTime)
		
		#expect(dataStore.medications.count == 100)
		#expect(elapsed < 5.0, "Bulk insert should complete within 5 seconds")
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

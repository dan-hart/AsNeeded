// DataStoreClearTests.swift
// Tests for DataStore.clearAllData() AppStorage cleanup functionality

import Testing
import Foundation
@testable import AsNeeded
import ANModelKit

@MainActor
struct DataStoreClearTests {
	@Test("clearAllData removes all AppStorage medication selections")
	func testClearAllDataRemovesAppStorageSelections() async throws {
		// Given: Create test store
		let store = DataStore(testIdentifier: "cleartest")
		
		// Create and add test medications
		let med1 = ANMedicationConcept(clinicalName: "Test Med 1")
		let med2 = ANMedicationConcept(clinicalName: "Test Med 2")
		
		try await store.addMedication(med1)
		try await store.addMedication(med2)
		
		// Create and add test events
		let event1 = ANEventConcept(
			eventType: .doseTaken,
			medication: med1,
			dose: ANDoseConcept(amount: 1, unit: .unit),
			date: Date()
		)
		try await store.addEvent(event1)
		
		// Set AppStorage values to simulate user selections
		UserDefaults.standard.set(med1.id.uuidString, forKey: "historySelectedMedicationID")
		UserDefaults.standard.set(med2.id.uuidString, forKey: "trendsSelectedMedicationID")
		UserDefaults.standard.set([med1.id.uuidString, med2.id.uuidString], forKey: "medicationOrder")
		
		// Set navigation target
		NavigationManager.shared.historyTargetMedicationID = med1.id.uuidString
		
		// When: Clear all data
		try await store.clearAllData()
		
		// Then: Verify all data and AppStorage values are cleared
		#expect(store.medications.isEmpty)
		#expect(store.events.isEmpty)
		#expect(UserDefaults.standard.string(forKey: "historySelectedMedicationID") == nil)
		#expect(UserDefaults.standard.string(forKey: "trendsSelectedMedicationID") == nil)
		#expect(UserDefaults.standard.array(forKey: "medicationOrder") == nil)
		#expect(NavigationManager.shared.historyTargetMedicationID == nil)
	}
	
	@Test("clearAllData properly synchronizes UserDefaults")
	func testClearAllDataSynchronizesUserDefaults() async throws {
		// Given: Create test store
		let store = DataStore(testIdentifier: "synctest")
		
		// Create and add test medication
		let med = ANMedicationConcept(clinicalName: "Sync Test Med")
		try await store.addMedication(med)
		
		// Set multiple AppStorage values
		let medIDString = med.id.uuidString
		UserDefaults.standard.set(medIDString, forKey: "historySelectedMedicationID")
		UserDefaults.standard.set(medIDString, forKey: "trendsSelectedMedicationID")
		UserDefaults.standard.set([medIDString], forKey: "medicationOrder")
		
		// When: Clear all data
		try await store.clearAllData()
		
		// Force a synchronize to ensure changes are persisted
		UserDefaults.standard.synchronize()
		
		// Then: Re-read values to ensure they're actually cleared
		let historyID = UserDefaults.standard.string(forKey: "historySelectedMedicationID")
		let trendsID = UserDefaults.standard.string(forKey: "trendsSelectedMedicationID")
		let order = UserDefaults.standard.array(forKey: "medicationOrder")
		
		#expect(historyID == nil)
		#expect(trendsID == nil)
		#expect(order == nil)
		
		// Verify stores are also empty
		#expect(store.medications.isEmpty)
		#expect(store.events.isEmpty)
	}
	
	@Test("clearAllData handles missing AppStorage values gracefully")
	func testClearAllDataHandlesMissingValues() async throws {
		// Given: Create test store with no pre-existing AppStorage values
		let store = DataStore(testIdentifier: "missingtest")
		
		// Add a medication but don't set any AppStorage values
		let med = ANMedicationConcept(clinicalName: "Missing Test Med")
		try await store.addMedication(med)
		
		// Ensure AppStorage values don't exist
		UserDefaults.standard.removeObject(forKey: "historySelectedMedicationID")
		UserDefaults.standard.removeObject(forKey: "trendsSelectedMedicationID")
		UserDefaults.standard.removeObject(forKey: "medicationOrder")
		
		// When: Clear all data (should not throw even with missing values)
		try await store.clearAllData()
		
		// Then: Verify everything is cleared without errors
		#expect(store.medications.isEmpty)
		#expect(UserDefaults.standard.string(forKey: "historySelectedMedicationID") == nil)
		#expect(UserDefaults.standard.string(forKey: "trendsSelectedMedicationID") == nil)
		#expect(UserDefaults.standard.array(forKey: "medicationOrder") == nil)
	}
	
	@Test("clearAllData clears NavigationManager state")
	func testClearAllDataClearsNavigationManager() async throws {
		// Given: Create test store
		let store = DataStore(testIdentifier: "navtest")
		
		// Create and add test medication
		let med = ANMedicationConcept(clinicalName: "Nav Test Med")
		try await store.addMedication(med)
		
		// Set NavigationManager state
		NavigationManager.shared.historyTargetMedicationID = med.id.uuidString
		NavigationManager.shared.historyTargetDate = Date()
		
		// When: Clear all data
		try await store.clearAllData()
		
		// Then: Verify NavigationManager state is cleared
		#expect(NavigationManager.shared.historyTargetMedicationID == nil)
		#expect(NavigationManager.shared.historyTargetDate == nil)
	}
}
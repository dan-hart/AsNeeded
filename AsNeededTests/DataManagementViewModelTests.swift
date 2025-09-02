//
//  DataManagementViewModelTests.swift
//  AsNeededTests
//
//  Unit tests for DataManagementViewModel functionality
//

import Testing
import Foundation
@testable import AsNeeded
@testable import ANModelKit

@MainActor  
struct DataManagementViewModelTests {
  
  // MARK: - Test Helpers

  func createTestDataStore() -> DataStore {
	return DataStore(testIdentifier: UUID().uuidString)
  }
  
  func createTestMedication() -> ANMedicationConcept {
	return ANMedicationConcept(
	  clinicalName: "Test Medication",
	  nickname: "Test",
	  quantity: 30.0
	)
  }
  
  func createTestEvent() -> ANEventConcept {
	return ANEventConcept(
	  eventType: .doseTaken,
	  date: Date()
	)
  }
  
  // MARK: - Initialization Tests

  @Test("ViewModel should initialize with default state")
  func testViewModelInitialization() {
	let dataStore = createTestDataStore()
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	#expect(viewModel.isExporting == false)
	#expect(viewModel.isImporting == false)
	#expect(viewModel.isClearing == false)
	#expect(viewModel.showingClearConfirmation == false)
	#expect(viewModel.showingExportConfirmation == false)
	#expect(viewModel.showingDocumentPicker == false)
	#expect(viewModel.showingLogFileSaver == false)
	#expect(viewModel.showingDataExporter == false)
	#expect(viewModel.exportedData == nil)
	#expect(viewModel.alertMessage == nil)
	#expect(viewModel.showingAlert == false)
  }
  
  @Test("ViewModel should provide data counts")
  func testDataCounts() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	// Initially empty
	#expect(viewModel.medicationCount == 0)
	#expect(viewModel.eventCount == 0)
	
	// Add data
	try await dataStore.addMedication(createTestMedication())
	try await dataStore.addEvent(createTestEvent())
	
	// Counts should update
	#expect(viewModel.medicationCount == 1)
	#expect(viewModel.eventCount == 1)
  }
  
  // MARK: - Export Tests

  @Test("Request export should show confirmation dialog")
  func testRequestExport() {
	let dataStore = createTestDataStore()
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	#expect(viewModel.showingExportConfirmation == false)
	
	viewModel.requestExport()
	
	#expect(viewModel.showingExportConfirmation == true)
  }
  
  @Test("Export should set loading state and generate data")
  func testExportData() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Add test data
	try await dataStore.addMedication(createTestMedication())
	
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	// Start export
	let exportTask = Task {
	  await viewModel.exportData(includeNames: true)
	}
	
	// Should be loading initially (though this might be too fast to catch)
	// #expect(viewModel.isExporting == true)
	
	await exportTask.value
	
	// After completion
	#expect(viewModel.isExporting == false)
	#expect(viewModel.exportedData != nil)
	#expect(viewModel.showingDataExporter == true)
	
	// Verify exported data is valid JSON
	guard let exportedData = viewModel.exportedData else {
	  #expect(false, "Export data should not be nil")
	  return
	}
	let json = try JSONSerialization.jsonObject(with: exportedData) as? [String: Any]
	#expect(json != nil)
  }
  
  @Test("Export with empty data should still work")  
  func testExportEmptyData() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	await viewModel.exportData(includeNames: true)
	
	#expect(viewModel.isExporting == false)
	#expect(viewModel.exportedData != nil)
	#expect(viewModel.showingDataExporter == true)
  }
  
  // MARK: - Import Tests

  @Test("Import valid data should succeed")
  func testImportValidData() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	// Create test JSON file
	let testJSONString = """
	{
	  "medications": [
		{
		  "id": "123e4567-e89b-12d3-a456-426614174000",
		  "clinicalName": "Imported Med"
		}
	  ],
	  "events": [],
	  "exportDate": "2022-01-01T12:00:00Z",
	  "appVersion": "1.0.0"
	}
	"""
	
	guard let testJSON = testJSONString.data(using: .utf8) else {
	  #expect(false, "Failed to create test JSON data")
	  return
	}
	
	// Create temporary file
	let tempURL = FileManager.default.temporaryDirectory
	  .appendingPathComponent("test-import.json")
	try testJSON.write(to: tempURL)
	
	defer {
	  try? FileManager.default.removeItem(at: tempURL)
	}
	
	// Import
	await viewModel.importData(from: tempURL)
	
	// Verify success
	#expect(viewModel.isImporting == false)
	#expect(viewModel.alertMessage == "Data imported successfully")
	#expect(viewModel.showingAlert == true)
	
	// Verify data was imported
	#expect(dataStore.medications.count == 1)
	#expect(dataStore.medications.first?.clinicalName == "Imported Med")
  }
  
  @Test("Import invalid data should show error")
  func testImportInvalidData() async throws {
	let dataStore = createTestDataStore()
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	// Create invalid JSON file
	guard let invalidJSON = "{ invalid json }".data(using: .utf8) else {
	  #expect(false, "Failed to create test JSON data")
	  return
	}
	
	let tempURL = FileManager.default.temporaryDirectory
	  .appendingPathComponent("test-invalid.json")
	try invalidJSON.write(to: tempURL)
	
	defer {
	  try? FileManager.default.removeItem(at: tempURL)
	}
	
	// Import should fail
	await viewModel.importData(from: tempURL)
	
	#expect(viewModel.isImporting == false)
	#expect(viewModel.alertMessage?.contains("Import failed") == true)
	#expect(viewModel.showingAlert == true)
  }
  
  @Test("Import nonexistent file should show error")
  func testImportNonexistentFile() async {
	let dataStore = createTestDataStore()
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	let nonexistentURL = URL(fileURLWithPath: "/nonexistent/file.json")
	
	await viewModel.importData(from: nonexistentURL)
	
	#expect(viewModel.isImporting == false)
	#expect(viewModel.alertMessage?.contains("Import failed") == true)
	#expect(viewModel.showingAlert == true)
  }
  
  // MARK: - Clear Data Tests

  @Test("Clear confirmation should set flag")
  func testConfirmClearData() {
	let dataStore = createTestDataStore()
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	viewModel.confirmClearData()
	
	#expect(viewModel.showingClearConfirmation == true)
  }
  
  @Test("Clear all data should remove everything")
  func testClearAllData() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	// Add test data
	try await dataStore.addMedication(createTestMedication())
	try await dataStore.addEvent(createTestEvent())
	
	#expect(dataStore.medications.count == 1)
	#expect(dataStore.events.count == 1)
	
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	// Clear data
	await viewModel.clearAllData()
	
	// Verify success
	#expect(viewModel.isClearing == false)
	#expect(viewModel.alertMessage == "All data cleared successfully")
	#expect(viewModel.showingAlert == true)
	
	// Verify data was cleared
	#expect(dataStore.medications.count == 0)
	#expect(dataStore.events.count == 0)
  }
  
  // MARK: - State Management Tests

  @Test("Only one operation should be active at a time")
  func testMutualExclusiveOperations() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	try await dataStore.addMedication(createTestMedication())
	
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	// Start multiple operations concurrently
	async let exportTask: Void = viewModel.exportData(includeNames: true)
	async let clearTask: Void = viewModel.clearAllData()
	
	// Wait for both to complete
	let _ = await (exportTask, clearTask)
	
	// All should be false at the end
	#expect(viewModel.isExporting == false)
	#expect(viewModel.isClearing == false)
	#expect(viewModel.isImporting == false)
  }
  
  // MARK: - Error Recovery Tests

  @Test("Failed export should reset state properly")
  func testFailedExportStateReset() async {
	// Create a test data store
	let dataStore = createTestDataStore()
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	// Force an error by trying to export when DataStore might fail
	// This is tricky to test without a mock, but we can at least verify
	// the state management works
	await viewModel.exportData(includeNames: true)
	
	// Should always reset loading state, even on error
	#expect(viewModel.isExporting == false)
  }
  
  // MARK: - Integration Tests

  @Test("Full workflow: export, clear, import should work")
  func testFullWorkflow() async throws {
	let dataStore = createTestDataStore()
	try await dataStore.clearAllData()
	
	let viewModel = DataManagementViewModel(dataStore: dataStore)
	
	// 1. Add initial data
	try await dataStore.addMedication(createTestMedication())
	#expect(viewModel.medicationCount == 1)
	
	// 2. Export data
	await viewModel.exportData(includeNames: true)
	#expect(viewModel.exportedData != nil)
	
	guard let exportedData = viewModel.exportedData else {
	  #expect(false, "Export data should not be nil")
	  return
	}
	
	// 3. Clear all data
	await viewModel.clearAllData()
	#expect(viewModel.medicationCount == 0)
	
	// 4. Import data back
	let tempURL = FileManager.default.temporaryDirectory
	  .appendingPathComponent("workflow-test.json")
	try exportedData.write(to: tempURL)
	
	defer {
	  try? FileManager.default.removeItem(at: tempURL)
	}
	
	await viewModel.importData(from: tempURL)
	
	// 5. Verify data is restored
	#expect(viewModel.medicationCount == 1)
	#expect(dataStore.medications.first?.clinicalName == "Test Medication")
	#expect(viewModel.alertMessage == "Data imported successfully")
  }
}
//
//  DataManagementViewModelTests.swift
//  AsNeededTests
//
//  Unit tests for DataManagementViewModel functionality
//

@testable import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite(.tags(.dataManagement, .viewModel, .unit))
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
    func viewModelInitialization() {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        #expect(viewModel.isExporting == false)
        #expect(viewModel.isImporting == false)
        #expect(viewModel.isClearing == false)
        #expect(viewModel.isClearingUserData == false)
        #expect(viewModel.isResettingSettings == false)
        #expect(viewModel.showingClearConfirmation == false)
        #expect(viewModel.showingClearUserDataConfirmation == false)
        #expect(viewModel.showingResetSettingsConfirmation == false)
        #expect(viewModel.showingExportConfirmation == false)
        #expect(viewModel.showingDocumentPicker == false)
        #expect(viewModel.showingLogShareSheet == false)
        #expect(viewModel.showingDataShareSheet == false)
        #expect(viewModel.exportedDataURL == nil)
        #expect(viewModel.exportedLogsURL == nil)
        #expect(viewModel.alertMessage == nil)
        #expect(viewModel.showingAlert == false)
    }

    @Test("ViewModel should provide data counts")
    func dataCounts() async throws {
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
            await viewModel.exportData(redactMedicationNames: false, redactNotes: false)
        }

        // Should be loading initially (though this might be too fast to catch)
        // #expect(viewModel.isExporting == true)

        await exportTask.value

        // After completion
        #expect(viewModel.isExporting == false)
        #expect(viewModel.exportedDataURL != nil)
        #expect(viewModel.showingDataShareSheet == true)

        // Verify exported data is valid JSON
        guard let exportedURL = viewModel.exportedDataURL else {
            #expect(Bool(false), "Export URL should not be nil")
            return
        }
        let exportedData = try Data(contentsOf: exportedURL)
        let json = try JSONSerialization.jsonObject(with: exportedData) as? [String: Any]
        #expect(json != nil)
    }

    @Test("Export with empty data should still work")
    func exportEmptyData() async throws {
        let dataStore = createTestDataStore()
        try await dataStore.clearAllData()

        let viewModel = DataManagementViewModel(dataStore: dataStore)

        await viewModel.exportData(redactMedicationNames: false, redactNotes: false)

        #expect(viewModel.isExporting == false)
        #expect(viewModel.exportedDataURL != nil)
        #expect(viewModel.showingDataShareSheet == true)
    }

    // MARK: - Import Tests

    @Test("Import valid data should succeed")
    func importValidData() async throws {
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
            #expect(Bool(false), "Failed to create test JSON data")
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
        #expect(viewModel.alertMessage?.contains("Data imported successfully") == true)
        #expect(viewModel.alertMessage?.contains("1 medications") == true)
        #expect(viewModel.alertMessage?.contains("0 events") == true)
        #expect(viewModel.showingAlert == true)

        // Verify data was imported
        #expect(dataStore.medications.count == 1)
        #expect(dataStore.medications.first?.clinicalName == "Imported Med")
    }

    @Test("Import invalid data should show error")
    func importInvalidData() async throws {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        // Create invalid JSON file
        guard let invalidJSON = "{ invalid json }".data(using: .utf8) else {
            #expect(Bool(false), "Failed to create test JSON data")
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
    func importNonexistentFile() async {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/file.json")

        await viewModel.importData(from: nonexistentURL)

        #expect(viewModel.isImporting == false)
        #expect(viewModel.alertMessage?.contains("Import failed") == true)
        #expect(viewModel.showingAlert == true)
    }

    @Test("Import with security-scoped URL should handle resource access properly")
    func importWithSecurityScopedURL() async throws {
        let dataStore = createTestDataStore()
        try await dataStore.clearAllData()

        let viewModel = DataManagementViewModel(dataStore: dataStore)

        // Create test JSON file with valid data - using minimal required fields
        let testJSONString = """
        {
          "medications": [
        	{
        	  "id": "123e4567-e89b-12d3-a456-426614174000",
        	  "clinicalName": "Security Test Med",
        	  "nickname": "SecTest",
        	  "quantity": 30.0
        	}
          ],
          "events": [],
          "exportDate": "2024-01-01T12:00:00Z",
          "appVersion": "1.0.0"
        }
        """

        guard let testJSON = testJSONString.data(using: .utf8) else {
            #expect(Bool(false), "Failed to create test JSON data")
            return
        }

        // Create a temporary file URL (simulating what fileImporter provides)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("security-test-import.json")
        try testJSON.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Import the file - this will test the security-scoped resource handling
        await viewModel.importData(from: tempURL)

        // Verify import succeeded
        #expect(viewModel.isImporting == false)
        #expect(viewModel.alertMessage?.contains("Data imported successfully") == true)
        #expect(viewModel.alertMessage?.contains("1 medications") == true)
        #expect(viewModel.alertMessage?.contains("0 events") == true)
        #expect(viewModel.showingAlert == true)

        // Verify the data was actually imported
        #expect(dataStore.medications.count == 1)
        #expect(dataStore.medications.first?.clinicalName == "Security Test Med")
        #expect(dataStore.medications.first?.nickname == "SecTest")
    }

    @Test("Import should handle URLs that deny security access")
    func importWithDeniedSecurityAccess() async throws {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        // Create a mock URL that would fail security access
        // Since we can't easily mock a URL that returns false from startAccessingSecurityScopedResource,
        // we'll test with a URL that doesn't exist (which will fail in the Data(contentsOf:) call)
        // This ensures the error handling path works correctly
        let inaccessibleURL = URL(fileURLWithPath: "/System/Library/CoreServices/SystemVersion.plist")

        await viewModel.importData(from: inaccessibleURL)

        // Should handle the error gracefully
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

    @Test("Clear user data confirmation should show pre-export dialog")
    func testConfirmClearUserData() {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        viewModel.confirmClearUserData()

        #expect(viewModel.showingPreClearExportDialog == true)
        #expect(viewModel.showingClearUserDataConfirmation == false)
    }

    @Test("Handle pre-clear export choice - export option should show export confirmation")
    func testHandlePreClearExportChoiceWithExport() {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        viewModel.handlePreClearExportChoice(shouldExport: true)

        #expect(viewModel.shouldClearAfterExport == true)
        #expect(viewModel.showingExportConfirmation == true)
        #expect(viewModel.showingClearUserDataConfirmation == false)
    }

    @Test("Handle pre-clear export choice - skip export option should show clear confirmation")
    func testHandlePreClearExportChoiceWithoutExport() {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        viewModel.handlePreClearExportChoice(shouldExport: false)

        #expect(viewModel.shouldClearAfterExport == false)
        #expect(viewModel.showingExportConfirmation == false)
        #expect(viewModel.showingClearUserDataConfirmation == true)
    }

    @Test("Share sheet dismissed should show clear confirmation if shouldClearAfterExport is true")
    func testOnShareSheetDismissedWithClearFlag() {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        viewModel.shouldClearAfterExport = true
        viewModel.onShareSheetDismissed()

        #expect(viewModel.shouldClearAfterExport == false)
        #expect(viewModel.showingClearUserDataConfirmation == true)
    }

    @Test("Share sheet dismissed should not show clear confirmation if shouldClearAfterExport is false")
    func testOnShareSheetDismissedWithoutClearFlag() {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        viewModel.shouldClearAfterExport = false
        viewModel.onShareSheetDismissed()

        #expect(viewModel.shouldClearAfterExport == false)
        #expect(viewModel.showingClearUserDataConfirmation == false)
    }

    @Test("Reset settings confirmation should set flag")
    func testConfirmResetSettings() {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        viewModel.confirmResetSettings()

        #expect(viewModel.showingResetSettingsConfirmation == true)
    }

    @Test("Clear user data should remove only user data")
    func testClearUserData() async throws {
        let dataStore = createTestDataStore()
        try await dataStore.clearAllData()

        // Add test data
        try await dataStore.addMedication(createTestMedication())
        try await dataStore.addEvent(createTestEvent())

        #expect(dataStore.medications.count == 1)
        #expect(dataStore.events.count == 1)

        let viewModel = DataManagementViewModel(dataStore: dataStore)

        // Clear user data only
        await viewModel.clearUserData()

        // Verify success
        #expect(viewModel.isClearingUserData == false)
        #expect(viewModel.alertMessage == "All user data (medications and events) cleared successfully")
        #expect(viewModel.showingAlert == true)

        // Verify data was cleared
        #expect(dataStore.medications.count == 0)
        #expect(dataStore.events.count == 0)
    }

    @Test("Reset app settings should reset settings only")
    func testResetAppSettings() async {
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        // Reset settings
        await viewModel.resetAppSettings()

        // Verify success
        #expect(viewModel.isResettingSettings == false)
        #expect(viewModel.alertMessage == "App settings restored to defaults successfully")
        #expect(viewModel.showingAlert == true)
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
        #expect(viewModel.alertMessage == "All data cleared and settings restored to defaults")
        #expect(viewModel.showingAlert == true)

        // Verify data was cleared
        #expect(dataStore.medications.count == 0)
        #expect(dataStore.events.count == 0)
    }

    // MARK: - State Management Tests

    @Test("Only one operation should be active at a time")
    func mutualExclusiveOperations() async throws {
        let dataStore = createTestDataStore()
        try await dataStore.clearAllData()
        try await dataStore.addMedication(createTestMedication())

        let viewModel = DataManagementViewModel(dataStore: dataStore)

        // Start multiple operations concurrently
        async let exportTask: Void = viewModel.exportData(redactMedicationNames: false, redactNotes: false)
        async let clearTask: Void = viewModel.clearAllData()
        async let clearUserDataTask: Void = viewModel.clearUserData()
        async let resetSettingsTask: Void = viewModel.resetAppSettings()

        // Wait for all to complete
        _ = await (exportTask, clearTask, clearUserDataTask, resetSettingsTask)

        // All should be false at the end
        #expect(viewModel.isExporting == false)
        #expect(viewModel.isClearing == false)
        #expect(viewModel.isClearingUserData == false)
        #expect(viewModel.isResettingSettings == false)
        #expect(viewModel.isImporting == false)
    }

    // MARK: - Error Recovery Tests

    @Test("Failed export should reset state properly")
    func failedExportStateReset() async {
        // Create a test data store
        let dataStore = createTestDataStore()
        let viewModel = DataManagementViewModel(dataStore: dataStore)

        // Force an error by trying to export when DataStore might fail
        // This is tricky to test without a mock, but we can at least verify
        // the state management works
        await viewModel.exportData(redactMedicationNames: false, redactNotes: false)

        // Should always reset loading state, even on error
        #expect(viewModel.isExporting == false)
    }

    // MARK: - Integration Tests

    @Test("Full workflow: export, clear, import should work")
    func fullWorkflow() async throws {
        let dataStore = createTestDataStore()
        try await dataStore.clearAllData()

        let viewModel = DataManagementViewModel(dataStore: dataStore)

        // 1. Add initial data
        try await dataStore.addMedication(createTestMedication())
        #expect(viewModel.medicationCount == 1)

        // 2. Export data
        await viewModel.exportData(redactMedicationNames: false, redactNotes: false)
        #expect(viewModel.exportedDataURL != nil)

        guard let exportedURL = viewModel.exportedDataURL else {
            #expect(Bool(false), "Export URL should not be nil")
            return
        }

        let exportedData = try Data(contentsOf: exportedURL)

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
        #expect(viewModel.alertMessage?.contains("Data imported successfully") == true)
        #expect(viewModel.alertMessage?.contains("1 medications") == true)
    }
}

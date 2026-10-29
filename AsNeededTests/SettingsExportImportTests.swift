//
//  SettingsExportImportTests.swift
//  AsNeededTests
//
//  Unit tests for app settings export/import functionality
//

@testable import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite(.serialized, .tags(.dataManagement, .unit))
struct SettingsExportImportTests {
	// MARK: - Test Helpers

	private let suite = "SettingsExportImport-\(UUID().uuidString)"
	private let defaults: UserDefaults

	init() throws {
		defaults = try #require(UserDefaults(suiteName: suite))
	}

	func createTestDataStore() -> DataStore {
		DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: defaults, defaultsDomainName: suite)
	}

	func createTestSettings() -> AppSettings {
		var settings = AppSettings()
		settings.hapticsEnabled = false
		settings.selectedFontFamily = "OpenDyslexic"
		settings.trendsVisualizationType = 1
		settings.trendsDaysWindow = 30
		settings.showMedicationNamesInNotifications = true
		settings.automaticBackupEnabled = true
		settings.automaticBackupIncludeSettings = true
		return settings
	}

	func createTestMedication(id: UUID = UUID()) -> ANMedicationConcept {
		return ANMedicationConcept(
			id: id,
			clinicalName: "Test Medication",
			nickname: "Test Med",
			quantity: 30.0,
			initialQuantity: 60.0,
			lastRefillDate: Date(timeIntervalSince1970: 1_640_995_200),
			nextRefillDate: Date(timeIntervalSince1970: 1_643_673_600),
			prescribedUnit: ANUnitConcept.milligram,
			prescribedDoseAmount: 500.0
		)
	}

	@Test("Support banner opt-out survives settings export and import", arguments: [true, false])
	func supportBannerOptOut(_ applySettings: Bool) async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }
		defaults.set(true, forKey: UserDefaultsKeys.hideSupportBanners)
		let exported = try await dataStore.exportDataAsJSON(includeSettings: true)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let decoded = try decoder.decode(DataExport.self, from: exported)
		#expect(decoded.settings?.hideSupportBanners == true)
		defaults.set(false, forKey: UserDefaultsKeys.hideSupportBanners)
		try await dataStore.importDataFromJSON(exported, applySettings: applySettings)
		#expect(defaults.bool(forKey: UserDefaultsKeys.hideSupportBanners) == applySettings)
	}

	// MARK: - Export Tests

	@Test("Export without settings should not include settings field")
	func exportWithoutSettings() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }
		try await dataStore.clearAllData()

		let testMedication = createTestMedication()
		try await dataStore.addMedication(testMedication)

		let exportData = try await dataStore.exportDataAsJSON(includeSettings: false)

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let decoded = try decoder.decode(DataExport.self, from: exportData)

		#expect(decoded.settings == nil)
		#expect(decoded.medications.count == 1)
	}

	@Test("Export with settings should include settings field")
	func exportWithSettings() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }
		try await dataStore.clearAllData()

		// Set some test settings in UserDefaults
		defaults.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		defaults.set("OpenDyslexic", forKey: UserDefaultsKeys.selectedFontFamily)

		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let decoded = try decoder.decode(DataExport.self, from: exportData)

		#expect(decoded.settings != nil)
		#expect(decoded.settings?.hapticsEnabled == false)
		#expect(decoded.settings?.selectedFontFamily == "OpenDyslexic")
	}

	@Test("Export should never include sensitive keys from blocklist")
	func exportShouldNotIncludeSensitiveKeys() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }

		// Set sensitive keys that should never be exported
		defaults.set(Data(), forKey: UserDefaultsKeys.automaticBackupLocationBookmark)
		defaults.set(Date(), forKey: UserDefaultsKeys.analyticsFirstLaunchDate)
		defaults.set(false, forKey: UserDefaultsKeys.hapticsEnabled)

		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let decoded = try decoder.decode(DataExport.self, from: exportData)

		// These should not be in the exported settings
		let settings = try #require(decoded.settings)
		// AppSettings doesn't have these fields - they're blocked at export time
		// This test verifies they're not present by checking the struct only has safe fields

		// Verify safe fields are exported
		#expect(settings.hapticsEnabled == false)
		let object = try #require(JSONSerialization.jsonObject(with: exportData) as? [String: Any])
		let exportedSettings = try #require(object["settings"] as? [String: Any])
		#expect(exportedSettings[UserDefaultsKeys.automaticBackupLocationBookmark] == nil)
		#expect(exportedSettings[UserDefaultsKeys.analyticsFirstLaunchDate] == nil)
	}

	// MARK: - Import Tests

	@Test("Import without settings should not modify user defaults")
	func importWithoutSettingsShouldNotModifyDefaults() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }
		let previousHaptics = defaults.object(forKey: UserDefaultsKeys.hapticsEnabled)
		defer { defaults.set(previousHaptics, forKey: UserDefaultsKeys.hapticsEnabled) }

		// Set a test value
		defaults.set(false, forKey: UserDefaultsKeys.hapticsEnabled)

		// Create export without settings
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: false)

		// Import data
		try await dataStore.importDataFromJSON(exportData, applySettings: false)

		// Verify setting unchanged
		let hapticsEnabled = defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled)
		#expect(hapticsEnabled == false)
	}

	@Test("Import with applySettings=false should keep current settings")
	func importWithApplySettingsFalseShouldKeepSettings() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }

		// Set current settings
		defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		defaults.set("System", forKey: UserDefaultsKeys.selectedFontFamily)

		// Create export with different settings
		defaults.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		defaults.set("OpenDyslexic", forKey: UserDefaultsKeys.selectedFontFamily)
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Reset to original
		defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		defaults.set("System", forKey: UserDefaultsKeys.selectedFontFamily)

		// Import without applying settings
		try await dataStore.importDataFromJSON(exportData, applySettings: false)

		// Verify original settings preserved
		#expect(defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled) == true)
		#expect(defaults.string(forKey: UserDefaultsKeys.selectedFontFamily) == "System")
	}

	@Test("Import with applySettings=true should apply imported settings")
	func importWithApplySettingsTrueShouldApplySettings() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }

		// Set test settings
		defaults.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		defaults.set("OpenDyslexic", forKey: UserDefaultsKeys.selectedFontFamily)
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Change settings
		defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		defaults.set("System", forKey: UserDefaultsKeys.selectedFontFamily)

		// Import and apply settings
		try await dataStore.importDataFromJSON(exportData, applySettings: true)

		// Verify imported settings applied
		#expect(defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled) == false)
		#expect(defaults.string(forKey: UserDefaultsKeys.selectedFontFamily) == "OpenDyslexic")
	}

	// MARK: - Medication ID Validation Tests

	@Test("Import should validate and clear invalid medication ID references")
	func importShouldValidateAndClearInvalidMedicationIDs() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }
		try await dataStore.clearAllData()

		// Create medication with specific ID
		let validMedID = UUID()
		let validMed = createTestMedication(id: validMedID)
		try await dataStore.addMedication(validMed)

		// Create settings with invalid medication ID
		var settings = AppSettings()
		settings.historySelectedMedicationID = UUID().uuidString // Invalid ID

		// Export
		let exportWithInvalidID = DataExport(
			medications: [validMed],
			events: [],
			exportDate: Date(),
			appVersion: "1.0",
			dataVersion: "1.0",
			settings: settings
		)

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let data = try encoder.encode(exportWithInvalidID)

		// Import and apply settings
		try await dataStore.importDataFromJSON(data, applySettings: true)

		// Verify invalid ID was cleared
		let storedID = defaults.string(forKey: UserDefaultsKeys.historySelectedMedicationID)
		#expect(storedID == nil)
	}

	@Test("Import should preserve valid medication ID references")
	func importShouldPreserveValidMedicationIDs() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }
		try await dataStore.clearAllData()

		// Create medication with specific ID
		let validMedID = UUID()
		let validMed = createTestMedication(id: validMedID)
		try await dataStore.addMedication(validMed)

		// Create settings with valid medication ID
		var settings = AppSettings()
		settings.historySelectedMedicationID = validMedID.uuidString

		// Export
		let exportWithValidID = DataExport(
			medications: [validMed],
			events: [],
			exportDate: Date(),
			appVersion: "1.0",
			dataVersion: "1.0",
			settings: settings
		)

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let data = try encoder.encode(exportWithValidID)

		// Import and apply settings
		try await dataStore.importDataFromJSON(data, applySettings: true)

		// Verify valid ID was preserved
		let storedID = defaults.string(forKey: UserDefaultsKeys.historySelectedMedicationID)
		#expect(storedID == validMedID.uuidString)
	}

	// MARK: - Backward Compatibility Tests

	@Test("Import of data without settings field should work (backward compatibility)")
	func importWithoutSettingsFieldShouldWork() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }
		try await dataStore.clearAllData()

		let testMed = createTestMedication()

		// Create old-format export without settings
		let oldFormatExport = DataExport(
			medications: [testMed],
			events: [],
			exportDate: Date(),
			appVersion: "1.0",
			dataVersion: "1.0",
			settings: nil
		)

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let data = try encoder.encode(oldFormatExport)

		// Should import without errors
		try await dataStore.importDataFromJSON(data, applySettings: false)

		// Verify medication imported
		#expect(dataStore.medications.count == 1)
	}

	// MARK: - AppSettings Tests

	@Test("AppSettings should correctly identify settings categories")
	func appSettingsShouldIdentifyCategories() {
		var settings = AppSettings()
		#expect(settings.settingsCategories.isEmpty)

		settings.hapticsEnabled = true
		#expect(settings.settingsCategories.contains("App Preferences"))

		settings.selectedFontFamily = "OpenDyslexic"
		#expect(settings.settingsCategories.contains("Typography"))

		settings.automaticBackupEnabled = true
		#expect(settings.settingsCategories.contains("Automatic Backup Settings"))
	}

	// MARK: - Automatic Backup Alert Tests

	@Test("Import with automatic backups enabled should not break backups if settings not applied")
	func importWithBackupsEnabledShouldNotBreakIfSettingsNotApplied() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }

		// Setup: Enable automatic backups with bookmark
		defaults.set(true, forKey: UserDefaultsKeys.automaticBackupEnabled)
		defaults.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.automaticBackupLocationBookmark)

		// Create export
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Import without applying settings (keep current settings)
		try await dataStore.importDataFromJSON(exportData, applySettings: false)

		// Verify backups still enabled with bookmark
		#expect(defaults.bool(forKey: UserDefaultsKeys.automaticBackupEnabled) == true)
		#expect(defaults.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) != nil)
	}

	@Test("Import applying settings preserves this device's backup bookmark")
	func importApplyingSettingsPreservesBookmark() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }

		// Setup: Enable automatic backups with bookmark
		defaults.set(true, forKey: UserDefaultsKeys.automaticBackupEnabled)
		defaults.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.automaticBackupLocationBookmark)

		// Create export with backups enabled (but bookmark won't be exported due to blocklist)
		defaults.set(true, forKey: UserDefaultsKeys.automaticBackupEnabled)
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Add bookmark back for test
		defaults.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.automaticBackupLocationBookmark)

		// Import and apply settings
		try await dataStore.importDataFromJSON(exportData, applySettings: true)

		// Verify: the bookmark is device-specific and must not be replaced by import.
		let hasBookmark = defaults.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) != nil
		#expect(hasBookmark == true) // Bookmark should remain because it's not overwritten by import

		// Note: The alert logic triggers when both enabled AND bookmark are present before,
		// but either is missing after. Since bookmark is never exported, it stays, so no alert.
	}

	@Test("Import with backups disabled should not trigger alert")
	func importWithBackupsDisabledShouldNotTriggerAlert() async throws {
		let dataStore = createTestDataStore()
		defer { defaults.removePersistentDomain(forName: suite) }

		// Setup: Backups disabled
		defaults.set(false, forKey: UserDefaultsKeys.automaticBackupEnabled)
		defaults.removeObject(forKey: UserDefaultsKeys.automaticBackupLocationBookmark)

		// Create export
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Import and apply settings
		try await dataStore.importDataFromJSON(exportData, applySettings: true)

		// Verify: No change (backups were already disabled)
		#expect(defaults.bool(forKey: UserDefaultsKeys.automaticBackupEnabled) == false)
	}
}

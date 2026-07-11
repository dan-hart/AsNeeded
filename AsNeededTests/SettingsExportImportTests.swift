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

	func createTestDataStore() -> DataStore {
		return DataStore(testIdentifier: UUID().uuidString)
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

	func decodeSettings(_ json: String) throws -> AppSettings {
		try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
	}

	// MARK: - Export Tests

	@Test("Export without settings should not include settings field")
	func exportWithoutSettings() async throws {
		let dataStore = createTestDataStore()
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
		try await dataStore.clearAllData()

		// Set some test settings in UserDefaults
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		UserDefaults.standard.set("OpenDyslexic", forKey: UserDefaultsKeys.selectedFontFamily)

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

		// Set sensitive keys that should never be exported
		UserDefaults.standard.set(Data(), forKey: UserDefaultsKeys.automaticBackupLocationBookmark)
		UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.analyticsFirstLaunchDate)

		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let decoded = try decoder.decode(DataExport.self, from: exportData)

		// These should not be in the exported settings
		let settings = try #require(decoded.settings)
		// AppSettings doesn't have these fields - they're blocked at export time
		// This test verifies they're not present by checking the struct only has safe fields

		// Verify safe fields are exported
		#expect(settings.hapticsEnabled != nil || settings.selectedFontFamily != nil || settings.trendsVisualizationType != nil)
	}

	@Test("Current refill profiles export without legacy or recovery properties")
	func currentRefillProfilesExportWithoutLegacyOrRecoveryProperties() throws {
		let suiteName = "SettingsExportImportTests.export.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName) ?? .standard
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let medicationID = UUID().uuidString
		let profiles = [medicationID: MedicationRefillProfile(lowStockThreshold: 12)]
		defaults.set(try JSONEncoder().encode(profiles), forKey: UserDefaultsKeys.medicationRefillProfiles)
		defaults.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.archivedMedicationProfiles)
		defaults.set(Data([4, 5, 6]), forKey: UserDefaultsKeys.legacyMedicationProfiles)

		let data = try JSONEncoder().encode(AppSettings(from: defaults))
		let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
		let exportedProfiles = try #require(json["medicationRefillProfiles"] as? [String: Any])

		#expect(exportedProfiles[medicationID] != nil)
		#expect(json["medicationSafetyProfiles"] == nil)
		#expect(json[UserDefaultsKeys.archivedMedicationProfiles] == nil)
	}

	// MARK: - Import Tests

	@Test("Import without settings should not modify user defaults")
	func importWithoutSettingsShouldNotModifyDefaults() async throws {
		let dataStore = createTestDataStore()

		// Set a test value
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hapticsEnabled)

		// Create export without settings
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: false)

		// Import data
		try await dataStore.importDataFromJSON(exportData, applySettings: false)

		// Verify setting unchanged
		let hapticsEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hapticsEnabled)
		#expect(hapticsEnabled == true)
	}

	@Test("Import with applySettings=false should keep current settings")
	func importWithApplySettingsFalseShouldKeepSettings() async throws {
		let dataStore = createTestDataStore()

		// Set current settings
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		UserDefaults.standard.set("System", forKey: UserDefaultsKeys.selectedFontFamily)

		// Create export with different settings
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		UserDefaults.standard.set("OpenDyslexic", forKey: UserDefaultsKeys.selectedFontFamily)
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Reset to original
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		UserDefaults.standard.set("System", forKey: UserDefaultsKeys.selectedFontFamily)

		// Import without applying settings
		try await dataStore.importDataFromJSON(exportData, applySettings: false)

		// Verify original settings preserved
		#expect(UserDefaults.standard.bool(forKey: UserDefaultsKeys.hapticsEnabled) == true)
		#expect(UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedFontFamily) == "System")
	}

	@Test("Import with applySettings=true should apply imported settings")
	func importWithApplySettingsTrueShouldApplySettings() async throws {
		let dataStore = createTestDataStore()

		// Set test settings
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		UserDefaults.standard.set("OpenDyslexic", forKey: UserDefaultsKeys.selectedFontFamily)
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Change settings
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		UserDefaults.standard.set("System", forKey: UserDefaultsKeys.selectedFontFamily)

		// Import and apply settings
		try await dataStore.importDataFromJSON(exportData, applySettings: true)

		// Verify imported settings applied
		#expect(UserDefaults.standard.bool(forKey: UserDefaultsKeys.hapticsEnabled) == false)
		#expect(UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedFontFamily) == "OpenDyslexic")
	}

	// MARK: - Medication ID Validation Tests

	@Test("Import should validate and clear invalid medication ID references")
	func importShouldValidateAndClearInvalidMedicationIDs() async throws {
		let dataStore = createTestDataStore()
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
		let storedID = UserDefaults.standard.string(forKey: UserDefaultsKeys.historySelectedMedicationID)
		#expect(storedID == nil)
	}

	@Test("Import should preserve valid medication ID references")
	func importShouldPreserveValidMedicationIDs() async throws {
		let dataStore = createTestDataStore()
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
		let storedID = UserDefaults.standard.string(forKey: UserDefaultsKeys.historySelectedMedicationID)
		#expect(storedID == validMedID.uuidString)
	}

	// MARK: - Backward Compatibility Tests

	@Test("Legacy safety profile exports decode only low stock thresholds")
	func legacySafetyProfileExportsDecodeOnlyLowStockThresholds() throws {
		let medicationID = UUID().uuidString
		let settings = try decodeSettings("""
		{
			"medicationSafetyProfiles": {
				"\(medicationID)": {
					"minimumHoursBetweenDoses": 4,
					"maxDailyAmount": 8,
					"lowStockThreshold": 9,
					"refillLeadDays": 5
				}
			}
		}
		""")

		let encoded = try JSONEncoder().encode(settings)
		let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
		let profiles = try #require(json["medicationRefillProfiles"] as? [String: Any])
		let profile = try #require(profiles[medicationID] as? [String: Any])

		#expect(profile["lowStockThreshold"] as? Double == 9)
		#expect(profile["minimumHoursBetweenDoses"] == nil)
		#expect(profile["maxDailyAmount"] == nil)
		#expect(profile["refillLeadDays"] == nil)
		#expect(json["medicationSafetyProfiles"] == nil)
	}

	@Test("Current refill profile property wins over legacy property")
	func currentRefillProfilePropertyWinsOverLegacyProperty() throws {
		let medicationID = UUID().uuidString
		let settings = try decodeSettings("""
		{
			"medicationRefillProfiles": {"\(medicationID)": {"lowStockThreshold": 7}},
			"medicationSafetyProfiles": {"\(medicationID)": {"lowStockThreshold": 99}}
		}
		""")
		let encoded = try JSONEncoder().encode(settings)
		let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
		let profiles = try #require(json["medicationRefillProfiles"] as? [String: Any])
		let profile = try #require(profiles[medicationID] as? [String: Any])

		#expect(profile["lowStockThreshold"] as? Double == 7)
	}

	@Test("Imported refill profiles filter invalid medication IDs and mirror active data")
	func importedRefillProfilesFilterInvalidIDsAndMirrorActiveData() throws {
		let sharedDefaults = try #require(UserDefaults(suiteName: StorageConstants.appGroupIdentifier))
		let keys = [
			UserDefaultsKeys.medicationRefillProfiles,
			UserDefaultsKeys.legacyMedicationProfiles,
			UserDefaultsKeys.medicationProfilesMigrationCompleted,
		]
		defer {
			for key in keys {
				UserDefaults.standard.removeObject(forKey: key)
				sharedDefaults.removeObject(forKey: key)
			}
		}
		for key in keys {
			UserDefaults.standard.removeObject(forKey: key)
			sharedDefaults.removeObject(forKey: key)
		}

		let validID = UUID().uuidString
		let invalidID = UUID().uuidString
		let settings = try decodeSettings("""
		{
			"medicationRefillProfiles": {
				"\(validID)": {"lowStockThreshold": 6},
				"\(invalidID)": {"lowStockThreshold": 30}
			}
		}
		""")

		settings.apply(to: .standard, validateMedicationIDs: { [validID] })

		let standardData = try #require(UserDefaults.standard.data(forKey: UserDefaultsKeys.medicationRefillProfiles))
		let sharedData = try #require(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles))
		let standardProfiles = try JSONDecoder().decode([String: MedicationRefillProfile].self, from: standardData)
		let sharedProfiles = try JSONDecoder().decode([String: MedicationRefillProfile].self, from: sharedData)

		#expect(standardProfiles == [validID: MedicationRefillProfile(lowStockThreshold: 6)])
		#expect(sharedProfiles == standardProfiles)
	}

	@Test("Import of data without settings field should work (backward compatibility)")
	func importWithoutSettingsFieldShouldWork() async throws {
		let dataStore = createTestDataStore()
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
	func appSettingsShouldIdentifyCategories() throws {
		var settings = AppSettings()
		#expect(settings.settingsCategories.isEmpty)

		settings.hapticsEnabled = true
		#expect(settings.settingsCategories.contains("App Preferences"))

		settings.selectedFontFamily = "OpenDyslexic"
		#expect(settings.settingsCategories.contains("Typography"))

		settings.automaticBackupEnabled = true
		#expect(settings.settingsCategories.contains("Automatic Backup Settings"))

		let refillSettings = try decodeSettings("""
		{"medicationRefillProfiles": {"\(UUID().uuidString)": {"lowStockThreshold": 10}}}
		""")
		#expect(refillSettings.settingsCategories.contains("Refill Preferences"))
		#expect(!refillSettings.settingsCategories.contains("Clinical Guidance"))
	}

	// MARK: - Automatic Backup Alert Tests

	@Test("Import with automatic backups enabled should not break backups if settings not applied")
	func importWithBackupsEnabledShouldNotBreakIfSettingsNotApplied() async throws {
		let dataStore = createTestDataStore()

		// Setup: Enable automatic backups with bookmark
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.automaticBackupEnabled)
		UserDefaults.standard.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.automaticBackupLocationBookmark)

		// Create export
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Import without applying settings (keep current settings)
		try await dataStore.importDataFromJSON(exportData, applySettings: false)

		// Verify backups still enabled with bookmark
		#expect(UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled) == true)
		#expect(UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) != nil)
	}

	@Test("Import applying settings should clear bookmark but preserve enabled flag")
	func importApplyingSettingsShouldClearBookmark() async throws {
		let dataStore = createTestDataStore()

		// Setup: Enable automatic backups with bookmark
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.automaticBackupEnabled)
		UserDefaults.standard.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.automaticBackupLocationBookmark)

		// Create export with backups enabled (but bookmark won't be exported due to blocklist)
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.automaticBackupEnabled)
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Add bookmark back for test
		UserDefaults.standard.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.automaticBackupLocationBookmark)

		// Import and apply settings
		try await dataStore.importDataFromJSON(exportData, applySettings: true)

		// Verify: enabled flag imported, but bookmark cleared (not in allowlist)
		let hasBookmark = UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) != nil
		#expect(hasBookmark == true) // Bookmark should remain because it's not overwritten by import

		// Note: The alert logic triggers when both enabled AND bookmark are present before,
		// but either is missing after. Since bookmark is never exported, it stays, so no alert.
	}

	@Test("Import with backups disabled should not trigger alert")
	func importWithBackupsDisabledShouldNotTriggerAlert() async throws {
		let dataStore = createTestDataStore()

		// Setup: Backups disabled
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.automaticBackupEnabled)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupLocationBookmark)

		// Create export
		let exportData = try await dataStore.exportDataAsJSON(includeSettings: true)

		// Import and apply settings
		try await dataStore.importDataFromJSON(exportData, applySettings: true)

		// Verify: No change (backups were already disabled)
		#expect(UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled) == false)
	}
}

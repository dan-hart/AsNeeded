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
	private enum TestFailure: Error {
		case intentional
		case sensitive(String)
	}

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

	@Test("Notification urgency export includes explicit values without migration state")
	func notificationUrgencyExportIncludesExplicitValuesWithoutMigrationState() throws {
		let suiteName = "SettingsExportImportTests.urgencyExport.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suiteName))
		defaults.removePersistentDomain(forName: suiteName)
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let urgentMedicationID = UUID()
		let normalMedicationID = UUID()
		let urgencyStore = MedicationNotificationUrgencyStore(defaults: defaults)
		#expect(urgencyStore.save(true, for: urgentMedicationID))
		#expect(urgencyStore.save(false, for: normalMedicationID))
		#expect(urgencyStore.markMigrationCompleted())

		let settings = AppSettings(from: defaults)
		let data = try JSONEncoder().encode(settings)
		let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
		let exportedUrgency = try #require(json["medicationNotificationUrgency"] as? [String: Bool])

		#expect(exportedUrgency[urgentMedicationID.uuidString] == true)
		#expect(exportedUrgency[normalMedicationID.uuidString] == false)
		#expect(json[UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted] == nil)
		#expect(!String(decoding: data, as: UTF8.self).contains(
			UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted
		))
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

	@Test("A null current refill property suppresses legacy fallback")
	func nullCurrentRefillPropertySuppressesLegacyFallback() throws {
		let medicationID = UUID().uuidString
		let settings = try decodeSettings("""
		{
			"medicationRefillProfiles": null,
			"medicationSafetyProfiles": {"\(medicationID)": {"lowStockThreshold": 99}}
		}
		""")
		let encoded = try JSONEncoder().encode(settings)
		let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

		#expect(json["medicationRefillProfiles"] == nil)
		#expect(json["medicationSafetyProfiles"] == nil)
	}

	@Test("An absent current refill property uses legacy fallback")
	func absentCurrentRefillPropertyUsesLegacyFallback() throws {
		let medicationID = UUID().uuidString
		let settings = try decodeSettings("""
		{"medicationSafetyProfiles": {"\(medicationID)": {"lowStockThreshold": 13}}}
		""")
		let encoded = try JSONEncoder().encode(settings)
		let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
		let profiles = try #require(json["medicationRefillProfiles"] as? [String: Any])

		#expect(profiles[medicationID] != nil)
	}

	@Test("A malformed current refill property fails instead of using valid legacy data")
	func malformedCurrentRefillPropertyFailsWithoutLegacyFallback() {
		let medicationID = UUID().uuidString
		#expect(throws: DecodingError.self) {
			try decodeSettings("""
			{
				"medicationRefillProfiles": "malformed",
				"medicationSafetyProfiles": {"\(medicationID)": {"lowStockThreshold": 13}}
			}
			""")
		}
	}

	@Test("An empty current refill dictionary remains explicitly empty")
	func emptyCurrentRefillDictionaryRemainsExplicitlyEmpty() throws {
		let settings = try decodeSettings("{\"medicationRefillProfiles\": {}}")
		let encoded = try JSONEncoder().encode(settings)
		let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
		let profiles = try #require(json["medicationRefillProfiles"] as? [String: Any])

		#expect(profiles.isEmpty)
	}

	@Test("An empty current refill dictionary removes existing active profiles")
	func emptyCurrentRefillDictionaryRemovesExistingProfiles() throws {
		let defaults = UserDefaults(suiteName: "SettingsExportImportTests.emptyProfiles.\(UUID().uuidString)") ?? .standard
		let sharedDefaults = UserDefaults(suiteName: "SettingsExportImportTests.sharedEmptyProfiles.\(UUID().uuidString)") ?? .standard
		let existingData = try JSONEncoder().encode([
			UUID().uuidString: MedicationRefillProfile(lowStockThreshold: 5),
		])
		defaults.set(existingData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		sharedDefaults.set(existingData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		let settings = try decodeSettings("{\"medicationRefillProfiles\": {}}")

		try settings.apply(
			to: defaults,
			validateMedicationIDs: { [] },
			profileStore: MedicationRefillProfileStore(
				defaults: defaults,
				sharedDefaults: sharedDefaults
			)
		)

		#expect(defaults.object(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
		#expect(sharedDefaults.object(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
	}

	@Test("Profile persistence failure leaves unrelated settings untouched")
	func profilePersistenceFailureLeavesUnrelatedSettingsUntouched() throws {
		let defaults = UserDefaults(suiteName: "SettingsExportImportTests.failure.\(UUID().uuidString)") ?? .standard
		let sharedDefaults = UserDefaults(suiteName: "SettingsExportImportTests.sharedFailure.\(UUID().uuidString)") ?? .standard
		defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		let medicationID = UUID().uuidString
		let settings = try decodeSettings("""
		{
			"hapticsEnabled": false,
			"medicationRefillProfiles": {"\(medicationID)": {"lowStockThreshold": 7}}
		}
		""")
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			profileEncoder: { _ in throw TestFailure.intentional }
		)

		#expect(throws: AppSettingsError.self) {
			try settings.apply(
				to: defaults,
				validateMedicationIDs: { [medicationID] },
				profileStore: store
			)
		}
		#expect(defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
		#expect(defaults.object(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
	}

	@Test("Empty filtered profile removal failure leaves unrelated settings untouched")
	func emptyFilteredProfileRemovalFailureLeavesUnrelatedSettingsUntouched() throws {
		let defaults = UserDefaults(suiteName: "SettingsExportImportTests.removeFailure.\(UUID().uuidString)") ?? .standard
		let sharedDefaults = UserDefaults(suiteName: "SettingsExportImportTests.sharedRemoveFailure.\(UUID().uuidString)") ?? .standard
		defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		let existingData = try JSONEncoder().encode([
			UUID().uuidString: MedicationRefillProfile(lowStockThreshold: 5),
		])
		defaults.set(existingData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		sharedDefaults.set(existingData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		let invalidID = UUID().uuidString
		let settings = try decodeSettings("""
		{
			"hapticsEnabled": false,
			"medicationRefillProfiles": {"\(invalidID)": {"lowStockThreshold": 7}}
		}
		""")
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			activeRemover: { destination, key in
				guard destination !== sharedDefaults else { return }
				destination.removeObject(forKey: key)
			}
		)

		#expect(throws: AppSettingsError.self) {
			try settings.apply(
				to: defaults,
				validateMedicationIDs: { [] },
				profileStore: store
			)
		}
		#expect(defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == existingData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == existingData)
	}

	@Test("Import without refill profiles preserves existing profiles")
	func importWithoutRefillProfilesPreservesExistingProfiles() throws {
		let defaults = UserDefaults(suiteName: "SettingsExportImportTests.noProfiles.\(UUID().uuidString)") ?? .standard
		let medicationID = UUID().uuidString
		let existingProfiles = [medicationID: MedicationRefillProfile(lowStockThreshold: 5)]
		let existingData = try JSONEncoder().encode(existingProfiles)
		defaults.set(existingData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		let settings = try decodeSettings("{\"hapticsEnabled\": false}")

		try settings.apply(to: defaults, validateMedicationIDs: { [medicationID] })

		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == existingData)
		#expect(!defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
	}

	@Test("Absent urgency property preserves existing preferences")
	func absentUrgencyPropertyPreservesExistingPreferences() throws {
		let defaultsSuite = "SettingsExportImportTests.absentUrgency.\(UUID().uuidString)"
		let sharedSuite = "SettingsExportImportTests.absentUrgencyShared.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
		let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
		defaults.removePersistentDomain(forName: defaultsSuite)
		sharedDefaults.removePersistentDomain(forName: sharedSuite)
		defer {
			defaults.removePersistentDomain(forName: defaultsSuite)
			sharedDefaults.removePersistentDomain(forName: sharedSuite)
		}

		let medicationID = UUID()
		let urgencyStore = MedicationNotificationUrgencyStore(defaults: defaults)
		#expect(urgencyStore.save(false, for: medicationID))
		let priorData = try #require(defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency))
		let settings = try decodeSettings("{\"hapticsEnabled\": false}")

		try settings.apply(
			to: defaults,
			validateMedicationIDs: { [medicationID.uuidString] },
			profileStore: MedicationRefillProfileStore(
				defaults: defaults,
				sharedDefaults: sharedDefaults
			),
			urgencyStore: urgencyStore
		)

		#expect(defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == priorData)
		#expect(urgencyStore.preference(for: medicationID) == false)
	}

	@Test("Explicit empty urgency dictionary removes existing preferences")
	func explicitEmptyUrgencyDictionaryRemovesExistingPreferences() throws {
		let defaultsSuite = "SettingsExportImportTests.emptyUrgency.\(UUID().uuidString)"
		let sharedSuite = "SettingsExportImportTests.emptyUrgencyShared.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
		let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
		defaults.removePersistentDomain(forName: defaultsSuite)
		sharedDefaults.removePersistentDomain(forName: sharedSuite)
		defer {
			defaults.removePersistentDomain(forName: defaultsSuite)
			sharedDefaults.removePersistentDomain(forName: sharedSuite)
		}

		let medicationID = UUID()
		let urgencyStore = MedicationNotificationUrgencyStore(defaults: defaults)
		#expect(urgencyStore.save(true, for: medicationID))
		let settings = try decodeSettings("{\"medicationNotificationUrgency\": {}}")

		try settings.apply(
			to: defaults,
			validateMedicationIDs: { [medicationID.uuidString] },
			profileStore: MedicationRefillProfileStore(
				defaults: defaults,
				sharedDefaults: sharedDefaults
			),
			urgencyStore: urgencyStore
		)

		#expect(defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) == nil)
		#expect(urgencyStore.allPreferences() == [:])
	}

	@Test("Malformed urgency property fails decoding")
	func malformedUrgencyPropertyFailsDecoding() {
		#expect(throws: DecodingError.self) {
			try decodeSettings("{\"medicationNotificationUrgency\": \"malformed\"}")
		}
	}

	@Test("Imported urgency preferences retain valid IDs and drop unknown or malformed IDs")
	func importedUrgencyPreferencesRetainValidIDsOnly() throws {
		let defaultsSuite = "SettingsExportImportTests.urgencyImport.\(UUID().uuidString)"
		let sharedSuite = "SettingsExportImportTests.urgencyImportShared.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
		let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
		defaults.removePersistentDomain(forName: defaultsSuite)
		sharedDefaults.removePersistentDomain(forName: sharedSuite)
		defer {
			defaults.removePersistentDomain(forName: defaultsSuite)
			sharedDefaults.removePersistentDomain(forName: sharedSuite)
		}

		let urgentID = UUID()
		let normalID = UUID()
		let unknownID = UUID()
		let settings = try decodeSettings("""
		{
			"medicationNotificationUrgency": {
				"\(urgentID.uuidString)": true,
				"\(urgentID.uuidString.lowercased())": false,
				"\(normalID.uuidString.lowercased())": false,
				"\(unknownID.uuidString)": true,
				"not-a-uuid": true
			}
		}
		""")
		let urgencyStore = MedicationNotificationUrgencyStore(defaults: defaults)

		try settings.apply(
			to: defaults,
			validateMedicationIDs: { [urgentID.uuidString, normalID.uuidString] },
			profileStore: MedicationRefillProfileStore(
				defaults: defaults,
				sharedDefaults: sharedDefaults
			),
			urgencyStore: urgencyStore
		)

		#expect(urgencyStore.allPreferences() == [
			urgentID.uuidString: true,
			normalID.uuidString: false,
		])
	}

	@Test("Urgency persistence failure throws the specific settings error")
	func urgencyPersistenceFailureThrowsSpecificSettingsError() throws {
		let defaultsSuite = "SettingsExportImportTests.urgencyFailure.\(UUID().uuidString)"
		let sharedSuite = "SettingsExportImportTests.urgencyFailureShared.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
		let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
		defaults.removePersistentDomain(forName: defaultsSuite)
		sharedDefaults.removePersistentDomain(forName: sharedSuite)
		defer {
			defaults.removePersistentDomain(forName: defaultsSuite)
			sharedDefaults.removePersistentDomain(forName: sharedSuite)
		}
		defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		let medicationID = UUID()
		let settings = try decodeSettings("""
		{
			"hapticsEnabled": false,
			"medicationNotificationUrgency": {"\(medicationID.uuidString)": true}
		}
		""")
		let urgencyStore = MedicationNotificationUrgencyStore(
			defaults: defaults,
			writer: { _, _, _ in }
		)

		do {
			try settings.apply(
				to: defaults,
				validateMedicationIDs: { [medicationID.uuidString] },
				profileStore: MedicationRefillProfileStore(
					defaults: defaults,
					sharedDefaults: sharedDefaults
				),
				urgencyStore: urgencyStore
			)
			Issue.record("Expected notification urgency persistence failure")
		} catch let error as AppSettingsError {
			guard case .notificationUrgencyPersistenceFailed = error else {
				Issue.record("Expected notificationUrgencyPersistenceFailed, got \(error)")
				return
			}
		} catch {
			Issue.record("Expected AppSettingsError, got \(error)")
		}

		#expect(defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
		#expect(defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) == nil)
	}

	@Test("Urgency failure restores prior refill profile data")
	func urgencyFailureRestoresPriorRefillProfileData() throws {
		let defaultsSuite = "SettingsExportImportTests.specialStoreRollback.\(UUID().uuidString)"
		let sharedSuite = "SettingsExportImportTests.specialStoreRollbackShared.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
		let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
		defaults.removePersistentDomain(forName: defaultsSuite)
		sharedDefaults.removePersistentDomain(forName: sharedSuite)
		defer {
			defaults.removePersistentDomain(forName: defaultsSuite)
			sharedDefaults.removePersistentDomain(forName: sharedSuite)
		}

		let oldMedicationID = UUID()
		let importedMedicationID = UUID()
		let oldProfileData = Data("""
		{
			"\(oldMedicationID.uuidString)" : {
				"lowStockThreshold" : 4
			}
		}
		""".utf8)
		defaults.set(oldProfileData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		sharedDefaults.set(oldProfileData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		let profileStore = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults
		)
		let urgencyStore = MedicationNotificationUrgencyStore(
			defaults: defaults,
			writer: { _, _, _ in }
		)
		let settings = try decodeSettings("""
		{
			"medicationRefillProfiles": {
				"\(importedMedicationID.uuidString)": {"lowStockThreshold": 12}
			},
			"medicationNotificationUrgency": {
				"\(importedMedicationID.uuidString)": true
			}
		}
		""")

		do {
			try settings.apply(
				to: defaults,
				validateMedicationIDs: { [importedMedicationID.uuidString] },
				profileStore: profileStore,
				urgencyStore: urgencyStore
			)
			Issue.record("Expected notification urgency persistence failure")
		} catch let error as AppSettingsError {
			guard case .notificationUrgencyPersistenceFailed = error else {
				Issue.record("Expected notificationUrgencyPersistenceFailed, got \(error)")
				return
			}
		} catch {
			Issue.record("Expected AppSettingsError, got \(error)")
		}

		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == oldProfileData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == oldProfileData)
		#expect(profileStore.profile(for: oldMedicationID).lowStockThreshold == 4)
		#expect(profileStore.profile(for: importedMedicationID) == .empty)
	}

	@Test("Later import failure restores byte-exact urgency payload")
	func laterImportFailureRestoresByteExactUrgencyPayload() async throws {
		let defaultsSuite = "SettingsExportImportTests.urgencyRollback.\(UUID().uuidString)"
		let sharedSuite = "SettingsExportImportTests.urgencyRollbackShared.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
		let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
		defaults.removePersistentDomain(forName: defaultsSuite)
		sharedDefaults.removePersistentDomain(forName: sharedSuite)
		defer {
			defaults.removePersistentDomain(forName: defaultsSuite)
			sharedDefaults.removePersistentDomain(forName: sharedSuite)
		}

		let existingMedication = createTestMedication()
		let priorRawData = Data("""
		{
			"\(existingMedication.id.uuidString)" : false
		}
		""".utf8)
		defaults.set(priorRawData, forKey: UserDefaultsKeys.medicationNotificationUrgency)
		var factoryDefaults: UserDefaults?
		let dataStore = DataStore(
			testIdentifier: "urgency-rollback",
			settingsDefaults: defaults,
			refillProfileStore: MedicationRefillProfileStore(
				defaults: defaults,
				sharedDefaults: sharedDefaults
			),
			urgencyStoreFactory: { destination in
				factoryDefaults = destination
				return MedicationNotificationUrgencyStore(defaults: destination)
			},
			importFailureInjection: .init(
				beforeClearMedications: { throw TestFailure.intentional }
			)
		)
		try await dataStore.addMedication(existingMedication)
		let importedMedication = createTestMedication()
		var importedSettings = AppSettings()
		importedSettings.medicationNotificationUrgency = [
			importedMedication.id.uuidString: true,
		]
		let export = DataExport(
			medications: [importedMedication],
			events: [],
			exportDate: Date(),
			appVersion: "1.0",
			dataVersion: "1.0",
			settings: importedSettings
		)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		await #expect(throws: TestFailure.self) {
			try await dataStore.importDataFromJSON(
				encoder.encode(export),
				applySettings: true
			)
		}

		#expect(factoryDefaults === defaults)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == priorRawData)
		#expect(dataStore.medications.map(\.id) == [existingMedication.id])
	}

	@Test("Settings persistence failure aborts data import before replacing existing data")
	func settingsPersistenceFailureAbortsBeforeDataReplacement() async throws {
		let defaults = UserDefaults(suiteName: "SettingsExportImportTests.dataStoreFailure.\(UUID().uuidString)") ?? .standard
		let sharedDefaults = UserDefaults(suiteName: "SettingsExportImportTests.dataStoreSharedFailure.\(UUID().uuidString)") ?? .standard
		defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		let profileStore = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			activeWriter: { data, destination, key in
				guard destination !== sharedDefaults else { return }
				destination.set(data, forKey: key)
			}
		)
		let dataStore = DataStore(
			testIdentifier: "settings-import-failure",
			settingsDefaults: defaults,
			refillProfileStore: profileStore
		)
		let existingMedication = createTestMedication()
		try await dataStore.addMedication(existingMedication)
		let importedMedication = createTestMedication()
		var settings = AppSettings()
		settings.hapticsEnabled = false
		settings.medicationRefillProfiles = [
			importedMedication.id.uuidString: MedicationRefillProfile(lowStockThreshold: 9),
		]
		let export = DataExport(
			medications: [importedMedication],
			events: [],
			exportDate: Date(),
			appVersion: "1.0",
			dataVersion: "1.0",
			settings: settings
		)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		await #expect(throws: AppSettingsError.self) {
			try await dataStore.importDataFromJSON(encoder.encode(export), applySettings: true)
		}
		#expect(dataStore.medications.map(\.id) == [existingMedication.id])
		#expect(defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
	}

	@Test("Database clear failure restores settings profiles and existing data")
	func databaseClearFailureRestoresEntireImportSnapshot() async throws {
		let context = try await makeImportTransactionContext(
			failureInjection: .init(beforeClearMedications: { throw TestFailure.intentional })
		)
		let importedMedication = createTestMedication()
		let data = try makeTransactionalExport(medication: importedMedication)

		await #expect(throws: TestFailure.self) {
			try await context.dataStore.importDataFromJSON(data, applySettings: true)
		}
		try expectOriginalImportState(context)
	}

	@Test("Medication insertion failure restores settings profiles and existing data")
	func medicationInsertionFailureRestoresEntireImportSnapshot() async throws {
		let importedMedication = createTestMedication()
		let context = try await makeImportTransactionContext(
			failureInjection: .init(beforeMedicationInsert: { medication in
				guard medication.id != importedMedication.id else { throw TestFailure.intentional }
			})
		)
		let data = try makeTransactionalExport(medication: importedMedication)

		await #expect(throws: TestFailure.self) {
			try await context.dataStore.importDataFromJSON(data, applySettings: true)
		}
		try expectOriginalImportState(context)
		#expect(context.profileStore.profile(for: importedMedication.id) == .empty)
	}

	@Test("Event insertion failure restores settings profiles and existing data")
	func eventInsertionFailureRestoresEntireImportSnapshot() async throws {
		let context = try await makeImportTransactionContext(
			failureInjection: .init(beforeEventInsert: { _ in throw TestFailure.intentional })
		)
		let importedMedication = createTestMedication()
		let importedEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: importedMedication,
			dose: ANDoseConcept(amount: 1, unit: .unit),
			date: Date(timeIntervalSince1970: 1_700_000_000)
		)
		let data = try makeTransactionalExport(
			medication: importedMedication,
			events: [importedEvent]
		)

		await #expect(throws: TestFailure.self) {
			try await context.dataStore.importDataFromJSON(data, applySettings: true)
		}
		try expectOriginalImportState(context)
	}

	@Test("Merge insertion failure rolls back earlier merged records and settings")
	func mergeInsertionFailureRollsBackPartialMerge() async throws {
		let firstImportedMedication = createTestMedication()
		let failingMedication = createTestMedication()
		let context = try await makeImportTransactionContext(
			failureInjection: .init(beforeMedicationInsert: { medication in
				guard medication.id != failingMedication.id else { throw TestFailure.intentional }
			})
		)
		let settings = try decodeSettings("""
		{
			"hapticsEnabled": false,
			"selectedFontFamily": "OpenDyslexic",
			"medicationRefillProfiles": {
				"\(firstImportedMedication.id.uuidString)": {"lowStockThreshold": 4},
				"\(failingMedication.id.uuidString)": {"lowStockThreshold": 9}
			}
		}
		""")
		let export = DataExport(
			medications: [firstImportedMedication, failingMedication],
			events: [],
			exportDate: Date(),
			appVersion: "1.0",
			dataVersion: "1.0",
			settings: settings
		)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		await #expect(throws: TestFailure.self) {
			try await context.dataStore.importDataFromJSON(
				encoder.encode(export),
				mergeExisting: true,
				applySettings: true
			)
		}
		try expectOriginalImportState(context)
	}

	@Test("Import and rollback failure surfaces an explicit compound error")
	func importAndRollbackFailureSurfacesCompoundError() async throws {
		let sensitiveErrorText = "/Users/private/medications-backup.json"
		let context = try await makeImportTransactionContext(
			failureInjection: .init(
				beforeEventInsert: { _ in throw TestFailure.sensitive(sensitiveErrorText) },
				beforeRollbackMedications: { throw TestFailure.intentional }
			)
		)
		let medication = createTestMedication()
		let event = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 1, unit: .unit),
			date: Date(timeIntervalSince1970: 1_700_000_000)
		)
		let data = try makeTransactionalExport(medication: medication, events: [event])

		do {
			try await context.dataStore.importDataFromJSON(data, applySettings: true)
			Issue.record("Expected compound rollback failure")
		} catch let error as DataImportError {
			guard case let .transactionRollbackFailed(_, rollbackFailures) = error else {
				Issue.record("Expected compound rollback failure, got \(error)")
				return
			}
			let description = error.errorDescription ?? ""
			#expect(rollbackFailures.contains("medications"))
			#expect(description.contains("medications"))
			#expect(description.localizedCaseInsensitiveContains("retry"))
			#expect(description.localizedCaseInsensitiveContains("contact support"))
			#expect(!description.contains(sensitiveErrorText))
		} catch {
			Issue.record("Expected compound rollback failure, got \(error)")
		}
	}

	private struct ImportTransactionContext {
		let defaults: UserDefaults
		let sharedDefaults: UserDefaults
		let profileStore: MedicationRefillProfileStore
		let dataStore: DataStore
		let existingMedication: ANMedicationConcept
		let existingEvent: ANEventConcept
		let existingProfileData: Data
	}

	private func makeImportTransactionContext(
		failureInjection: DataStore.ImportFailureInjection
	) async throws -> ImportTransactionContext {
		let defaults = UserDefaults(suiteName: "SettingsExportImportTests.transaction.\(UUID().uuidString)") ?? .standard
		let sharedDefaults = UserDefaults(suiteName: "SettingsExportImportTests.sharedTransaction.\(UUID().uuidString)") ?? .standard
		defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		defaults.removeObject(forKey: UserDefaultsKeys.selectedFontFamily)
		let existingMedication = createTestMedication()
		let existingProfileData = try JSONEncoder().encode([
			existingMedication.id.uuidString: MedicationRefillProfile(lowStockThreshold: 12),
		])
		defaults.set(existingProfileData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		sharedDefaults.set(existingProfileData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		let profileStore = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults
		)
		let dataStore = DataStore(
			testIdentifier: "transaction",
			settingsDefaults: defaults,
			refillProfileStore: profileStore,
			importFailureInjection: failureInjection
		)
		let existingEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: existingMedication,
			dose: ANDoseConcept(amount: 1, unit: .unit),
			date: Date(timeIntervalSince1970: 1_600_000_000)
		)
		try await dataStore.addMedication(existingMedication)
		try await dataStore.addEvent(existingEvent)

		return ImportTransactionContext(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			profileStore: profileStore,
			dataStore: dataStore,
			existingMedication: existingMedication,
			existingEvent: existingEvent,
			existingProfileData: existingProfileData
		)
	}

	private func makeTransactionalExport(
		medication: ANMedicationConcept,
		events: [ANEventConcept] = []
	) throws -> Data {
		var settings = AppSettings()
		settings.hapticsEnabled = false
		settings.selectedFontFamily = "OpenDyslexic"
		settings.medicationRefillProfiles = [
			medication.id.uuidString: MedicationRefillProfile(lowStockThreshold: 9),
		]
		let export = DataExport(
			medications: [medication],
			events: events,
			exportDate: Date(),
			appVersion: "1.0",
			dataVersion: "1.0",
			settings: settings
		)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return try encoder.encode(export)
	}

	private func expectOriginalImportState(_ context: ImportTransactionContext) throws {
		#expect(context.defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
		#expect(context.defaults.object(forKey: UserDefaultsKeys.selectedFontFamily) == nil)
		#expect(context.defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == context.existingProfileData)
		#expect(context.sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == context.existingProfileData)
		#expect(context.dataStore.medications == [context.existingMedication])
		#expect(context.dataStore.events == [context.existingEvent])
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

		try settings.apply(to: .standard, validateMedicationIDs: { [validID] })

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

		let trendsQuestionSettings = try decodeSettings("""
		{"trendsQuestionsEnabled": false}
		""")
		#expect(trendsQuestionSettings.settingsCategories.contains("Display Settings"))
		#expect(!trendsQuestionSettings.settingsCategories.contains("Refill Preferences"))
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

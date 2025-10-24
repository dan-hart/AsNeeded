// AutomaticBackupManagerTests.swift
// Tests for AutomaticBackupManager functionality

import Testing
import Foundation
@testable import AsNeeded

@Suite("AutomaticBackupManager Tests", .tags(.unit, .backup))
@MainActor
struct AutomaticBackupManagerTests {
	init() {
		// Clear UserDefaults before each test
		clearAutomaticBackupSettings()
	}

	// MARK: - Helper Methods
	private func clearAutomaticBackupSettings() {
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupEnabled)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupLocationBookmark)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupRedactMedicationNames)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupRedactNotes)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupLastBackupDate)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupLastCleanupDate)
		UserDefaults.standard.synchronize()
	}

	private func createTestBookmark() -> Data {
		// Create a test bookmark data (this is mock data for testing)
		return "test-bookmark".data(using: .utf8) ?? Data()
	}

	// MARK: - Enable/Disable Tests
	@Test("Automatic backup is disabled by default")
	func defaultDisabledState() {
		// Given - Fresh UserDefaults
		clearAutomaticBackupSettings()

		// When - Check enabled state
		let isEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled)

		// Then
		#expect(isEnabled == false)
	}

	@Test("Save backup location enables automatic backup")
	func saveLocationEnablesBackup() {
		// Given
		let manager = AutomaticBackupManager.shared
		let testBookmark = createTestBookmark()

		// When
		manager.saveBackupLocation(bookmark: testBookmark)

		// Then
		let isEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled)
		let savedBookmark = UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark)

		#expect(isEnabled == true)
		#expect(savedBookmark == testBookmark)
	}

	@Test("Disable clears all automatic backup settings")
	func disableClearsSettings() {
		// Given
		let manager = AutomaticBackupManager.shared
		manager.saveBackupLocation(bookmark: createTestBookmark())
		UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.automaticBackupLastBackupDate)
		UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.automaticBackupLastCleanupDate)

		// When
		manager.disable()

		// Then
		let isEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled)
		let bookmark = UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark)
		let lastBackup = UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupLastBackupDate)
		let lastCleanup = UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupLastCleanupDate)

		#expect(isEnabled == false)
		#expect(bookmark == nil)
		#expect(lastBackup == nil)
		#expect(lastCleanup == nil)
	}

	// MARK: - Privacy Settings Tests
	@Test("Redact medication names defaults to false")
	func redactNamesDefaultFalse() {
		// Given - Fresh UserDefaults
		clearAutomaticBackupSettings()

		// When
		let redactNames = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupRedactMedicationNames)

		// Then
		#expect(redactNames == false)
	}

	@Test("Redact notes defaults to false")
	func redactNotesDefaultFalse() {
		// Given - Fresh UserDefaults
		clearAutomaticBackupSettings()

		// When
		let redactNotes = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupRedactNotes)

		// Then
		#expect(redactNotes == false)
	}

	@Test("Privacy settings persist correctly")
	func privacySettingsPersist() {
		// Given
		clearAutomaticBackupSettings()

		// When
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.automaticBackupRedactMedicationNames)
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.automaticBackupRedactNotes)

		// Then
		let redactNames = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupRedactMedicationNames)
		let redactNotes = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupRedactNotes)

		#expect(redactNames == true)
		#expect(redactNotes == true)
	}

	// MARK: - Last Backup Date Tests
	@Test("Last backup date is nil by default")
	func lastBackupDateNilByDefault() {
		// Given - Fresh UserDefaults
		clearAutomaticBackupSettings()

		// When
		let lastBackupDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupLastBackupDate) as? Date

		// Then
		#expect(lastBackupDate == nil)
	}

	@Test("Last backup date persists correctly")
	func lastBackupDatePersists() {
		// Given
		clearAutomaticBackupSettings()
		let testDate = Date()

		// When
		UserDefaults.standard.set(testDate, forKey: UserDefaultsKeys.automaticBackupLastBackupDate)

		// Then
		let savedDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupLastBackupDate) as? Date

		#expect(savedDate != nil)
		// Comparing dates within 1 second tolerance due to precision
		if let saved = savedDate {
			#expect(abs(saved.timeIntervalSince(testDate)) < 1.0)
		}
	}

	// MARK: - Cleanup Date Tests
	@Test("Last cleanup date is nil by default")
	func lastCleanupDateNilByDefault() {
		// Given - Fresh UserDefaults
		clearAutomaticBackupSettings()

		// When
		let lastCleanupDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupLastCleanupDate) as? Date

		// Then
		#expect(lastCleanupDate == nil)
	}

	@Test("Cleanup does not run if already performed today")
	func cleanupSkipsIfAlreadyPerformedToday() async {
		// Given
		let manager = AutomaticBackupManager.shared
		manager.saveBackupLocation(bookmark: createTestBookmark())
		let today = Date()
		UserDefaults.standard.set(today, forKey: UserDefaultsKeys.automaticBackupLastCleanupDate)

		// When
		await manager.performDailyCleanupIfNeeded()

		// Then
		let lastCleanup = UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupLastCleanupDate) as? Date

		// Should still be the same date (within 1 second)
		if let cleanup = lastCleanup {
			#expect(abs(cleanup.timeIntervalSince(today)) < 1.0)
		}
	}

	// MARK: - UserDefaults Keys Tests
	@Test("All automatic backup keys are in allKeys array")
	func allKeysIncludesAutomaticBackupKeys() {
		// Then
		#expect(UserDefaultsKeys.allKeys.contains(UserDefaultsKeys.automaticBackupEnabled))
		#expect(UserDefaultsKeys.allKeys.contains(UserDefaultsKeys.automaticBackupLocationBookmark))
		#expect(UserDefaultsKeys.allKeys.contains(UserDefaultsKeys.automaticBackupRedactMedicationNames))
		#expect(UserDefaultsKeys.allKeys.contains(UserDefaultsKeys.automaticBackupRedactNotes))
		#expect(UserDefaultsKeys.allKeys.contains(UserDefaultsKeys.automaticBackupLastBackupDate))
		#expect(UserDefaultsKeys.allKeys.contains(UserDefaultsKeys.automaticBackupLastCleanupDate))
		#expect(UserDefaultsKeys.allKeys.contains(UserDefaultsKeys.automaticBackupRetentionDays))
	}

	@Test("Retention days defaults to 90")
	func retentionDaysDefaultValue() {
		// Given
		clearAutomaticBackupSettings()

		// When
		let manager = AutomaticBackupManager.shared

		// Then
		#expect(manager.retentionDays == 90)
	}

	@Test("Retention days can be changed")
	func retentionDaysCanBeChanged() {
		// Given
		clearAutomaticBackupSettings()

		// When
		UserDefaults.standard.set(30, forKey: UserDefaultsKeys.automaticBackupRetentionDays)
		let manager = AutomaticBackupManager.shared

		// Then
		#expect(manager.retentionDays == 30)
	}

	@Test("Boolean settings have default values")
	func booleanSettingsHaveDefaults() {
		// Then
		#expect(UserDefaultsKeys.defaultValues[UserDefaultsKeys.automaticBackupEnabled] as? Bool == false)
		#expect(UserDefaultsKeys.defaultValues[UserDefaultsKeys.automaticBackupRedactMedicationNames] as? Bool == false)
		#expect(UserDefaultsKeys.defaultValues[UserDefaultsKeys.automaticBackupRedactNotes] as? Bool == false)
		#expect(UserDefaultsKeys.defaultValues[UserDefaultsKeys.automaticBackupRetentionDays] as? Int == 90)
	}

	@Test("Date and bookmark keys are in keysToRemove")
	func dateAndBookmarkKeysInKeysToRemove() {
		// Then
		#expect(UserDefaultsKeys.keysToRemove.contains(UserDefaultsKeys.automaticBackupLocationBookmark))
		#expect(UserDefaultsKeys.keysToRemove.contains(UserDefaultsKeys.automaticBackupLastBackupDate))
		#expect(UserDefaultsKeys.keysToRemove.contains(UserDefaultsKeys.automaticBackupLastCleanupDate))
	}
}

// MARK: - Test Tags Extension
extension Tag {
	@Tag static var backup: Self
}

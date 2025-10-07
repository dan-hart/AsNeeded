// HealthKitSyncManagerTests.swift
// Comprehensive tests for HealthKit synchronization manager.

import Testing
@testable import AsNeeded
import Foundation
import ANModelKit

@Suite("HealthKit Sync Manager")
struct HealthKitSyncManagerTests {

	// MARK: - Availability Tests

	@Test("HealthKit availability check")
	func healthKitAvailability() async {
		let manager = HealthKitSyncManager.shared

		#if canImport(HealthKit)
		// HealthKit should be available on iOS
		#expect(manager.isHealthKitAvailable == true)
		#else
		// Not available on other platforms
		#expect(manager.isHealthKitAvailable == false)
		#endif
	}

	// MARK: - Sync Mode Tests

	@Test("Current sync mode retrieval")
	func currentSyncMode() {
		let manager = HealthKitSyncManager.shared

		// Default should be bidirectional
		UserDefaults.standard.set("bidirectional", forKey: UserDefaultsKeys.healthKitSyncMode)
		let mode = manager.currentSyncMode
		#expect(mode == .bidirectional)

		// Test other modes
		UserDefaults.standard.set("healthKitSOT", forKey: UserDefaultsKeys.healthKitSyncMode)
		let mode2 = manager.currentSyncMode
		#expect(mode2 == .healthKitSOT)

		UserDefaults.standard.set("asNeededSOT", forKey: UserDefaultsKeys.healthKitSyncMode)
		let mode3 = manager.currentSyncMode
		#expect(mode3 == .asNeededSOT)
	}

	@Test("Invalid sync mode handling")
	func invalidSyncMode() {
		let manager = HealthKitSyncManager.shared

		// Set invalid mode
		UserDefaults.standard.set("invalid_mode", forKey: UserDefaultsKeys.healthKitSyncMode)

		// Should return nil for invalid mode
		let mode = manager.currentSyncMode
		#expect(mode == nil)
	}

	@Test("Sync enabled state")
	func syncEnabledState() {
		let manager = HealthKitSyncManager.shared

		// Test enabled
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitSyncEnabled)
		#expect(manager.isSyncEnabled == true)

		// Test disabled
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.healthKitSyncEnabled)
		#expect(manager.isSyncEnabled == false)
	}

	// MARK: - Sync Mode Properties Tests

	@Test("Sync mode display names")
	func syncModeDisplayNames() {
		#expect(HealthKitSyncMode.bidirectional.displayName.contains("Sync"))
		#expect(HealthKitSyncMode.healthKitSOT.displayName.contains("Health"))
		#expect(HealthKitSyncMode.asNeededSOT.displayName.contains("AsNeeded"))
	}

	@Test("Sync mode descriptions")
	func syncModeDescriptions() {
		#expect(HealthKitSyncMode.bidirectional.description.count > 20)
		#expect(HealthKitSyncMode.healthKitSOT.description.count > 20)
		#expect(HealthKitSyncMode.asNeededSOT.description.count > 20)
	}

	@Test("Data export availability by sync mode")
	func dataExportAvailability() {
		// Bidirectional allows export
		#expect(HealthKitSyncMode.bidirectional.allowsDataExport == true)

		// HealthKit SOT does not allow export (data lives in HealthKit)
		#expect(HealthKitSyncMode.healthKitSOT.allowsDataExport == false)

		// AsNeeded SOT allows export
		#expect(HealthKitSyncMode.asNeededSOT.allowsDataExport == true)
	}

	@Test("Local storage writing by sync mode")
	func localStorageWriting() {
		// Bidirectional writes locally
		#expect(HealthKitSyncMode.bidirectional.writesToLocalStorage == true)

		// HealthKit SOT does not write locally
		#expect(HealthKitSyncMode.healthKitSOT.writesToLocalStorage == false)

		// AsNeeded SOT writes locally
		#expect(HealthKitSyncMode.asNeededSOT.writesToLocalStorage == true)
	}

	// MARK: - Authorization Status Tests

	@Test("Authorization status display text")
	func authorizationStatusDisplayText() {
		#expect(HealthKitAuthorizationStatus.notDetermined.displayText.count > 0)
		#expect(HealthKitAuthorizationStatus.notAvailable.displayText.count > 0)
		#expect(HealthKitAuthorizationStatus.denied.displayText.count > 0)
		#expect(HealthKitAuthorizationStatus.authorized.displayText.count > 0)
		#expect(HealthKitAuthorizationStatus.unknown.displayText.count > 0)
	}

	@Test("Authorization status detail text")
	func authorizationStatusDetailText() {
		#expect(HealthKitAuthorizationStatus.notDetermined.detailText.count > 20)
		#expect(HealthKitAuthorizationStatus.notAvailable.detailText.contains("device"))
		#expect(HealthKitAuthorizationStatus.denied.detailText.contains("Settings"))
		#expect(HealthKitAuthorizationStatus.authorized.detailText.contains("connected"))
	}

	@Test("Authorization action availability")
	func authorizationActionAvailability() {
		// Not determined should have action
		#expect(HealthKitAuthorizationStatus.notDetermined.actionButtonText != nil)

		// Not available should not have action
		#expect(HealthKitAuthorizationStatus.notAvailable.actionButtonText == nil)

		// Denied should have action to open settings
		#expect(HealthKitAuthorizationStatus.denied.actionButtonText != nil)

		// Authorized should not need action
		#expect(HealthKitAuthorizationStatus.authorized.actionButtonText == nil)
	}

	// MARK: - Background Sync Tests

	@Test("Background sync setting persistence")
	func backgroundSyncPersistence() {
		// Enable background sync
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitBackgroundSyncEnabled)
		let enabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitBackgroundSyncEnabled)
		#expect(enabled == true)

		// Disable background sync
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.healthKitBackgroundSyncEnabled)
		let disabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitBackgroundSyncEnabled)
		#expect(disabled == false)
	}

	// MARK: - Last Sync Date Tests

	@Test("Last sync date persistence")
	func lastSyncDatePersistence() {
		let testDate = Date()

		// Store sync date
		UserDefaults.standard.set(testDate, forKey: UserDefaultsKeys.healthKitLastSyncDate)

		// Retrieve and verify
		let retrievedDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.healthKitLastSyncDate) as? Date
		#expect(retrievedDate != nil)

		// Dates should be within 1 second (accounting for precision)
		if let retrieved = retrievedDate {
			let difference = abs(testDate.timeIntervalSince(retrieved))
			#expect(difference < 1.0)
		}
	}

	// MARK: - Initial Setup Tests

	@Test("Initial setup completion flag")
	func initialSetupCompletion() {
		// Not completed initially
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.healthKitHasCompletedInitialSetup)
		let notCompleted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitHasCompletedInitialSetup)
		#expect(notCompleted == false)

		// Mark as completed
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitHasCompletedInitialSetup)
		let completed = UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitHasCompletedInitialSetup)
		#expect(completed == true)
	}

	// MARK: - Error Handling Tests

	@Test("HealthKit sync error descriptions")
	func syncErrorDescriptions() {
		let notAvailableError = HealthKitSyncError.healthKitNotAvailable
		#expect(notAvailableError.errorDescription?.contains("not available") == true)

		let deniedError = HealthKitSyncError.authorizationDenied
		#expect(deniedError.errorDescription?.contains("denied") == true)

		let disabledError = HealthKitSyncError.syncDisabled
		#expect(disabledError.errorDescription?.contains("not enabled") == true)

		let invalidModeError = HealthKitSyncError.invalidSyncMode
		#expect(invalidModeError.errorDescription?.contains("Invalid") == true)

		let failedError = HealthKitSyncError.syncFailed("Test reason")
		#expect(failedError.errorDescription?.contains("Test reason") == true)
	}

	// MARK: - Sync Result Tests

	@Test("Sync result success determination")
	func syncResultSuccess() {
		// Result with no errors should be successful
		let successResult = HealthKitSyncResult(
			medicationsSynced: 5,
			eventsSynced: 10,
			errors: [],
			duration: 1.5
		)
		#expect(successResult.success == true)

		// Result with errors should not be successful
		let failedResult = HealthKitSyncResult(
			medicationsSynced: 3,
			eventsSynced: 7,
			errors: [NSError(domain: "Test", code: -1)],
			duration: 2.0
		)
		#expect(failedResult.success == false)
	}

	// MARK: - Integration Tests

	@Test("Sync mode affects data store export availability")
	func syncModeAffectsExport() async {
		let dataStore = DataStore(testIdentifier: "syncModeExport")

		// When HealthKit sync is disabled, export should be available
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.healthKitSyncEnabled)
		#expect(dataStore.canExportData == true)

		// When bidirectional sync, export should be available
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitSyncEnabled)
		UserDefaults.standard.set("bidirectional", forKey: UserDefaultsKeys.healthKitSyncMode)
		#expect(dataStore.canExportData == true)

		// When HealthKit SOT, export should NOT be available
		UserDefaults.standard.set("healthKitSOT", forKey: UserDefaultsKeys.healthKitSyncMode)
		#expect(dataStore.canExportData == false)

		// When AsNeeded SOT, export should be available
		UserDefaults.standard.set("asNeededSOT", forKey: UserDefaultsKeys.healthKitSyncMode)
		#expect(dataStore.canExportData == true)

		// Cleanup
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.healthKitSyncEnabled)
	}

	@Test("Show onboarding preference")
	func showOnboardingPreference() {
		// Default should be true (show onboarding)
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitShowOnboarding)
		let shouldShow = UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitShowOnboarding)
		#expect(shouldShow == true)

		// User dismisses onboarding
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.healthKitShowOnboarding)
		let shouldHide = !UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitShowOnboarding)
		#expect(shouldHide == true)
	}
}

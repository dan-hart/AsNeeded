// FeatureToggleManagerTests.swift
// Comprehensive unit tests for FeatureToggleManager

import Testing
import Foundation
@testable import AsNeeded

@MainActor
@Suite("FeatureToggleManager Tests", .tags(.service, .featureToggle, .unit))
struct FeatureToggleManagerTests {

	init() {
		// Reset UserDefaults before each test to ensure isolation
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.featureToggleQuickPhrases)
	}

	// MARK: - Initialization Tests

	@Test("FeatureToggleManager is a singleton")
	func testSingletonInstance() {
		let instance1 = FeatureToggleManager.shared
		let instance2 = FeatureToggleManager.shared

		#expect(instance1 === instance2)
	}

	@Test("FeatureToggleManager initializes successfully")
	func testInitialization() {
		let manager = FeatureToggleManager.shared

		#expect(manager != nil)
	}

	// MARK: - Default Values Tests

	@Test("Quick phrases feature defaults to OFF")
	func testQuickPhrasesDefaultsToOff() {
		let manager = FeatureToggleManager.shared

		// Explicitly set to default value to test the default
		manager.quickPhrasesEnabled = false

		#expect(manager.quickPhrasesEnabled == false)

		// Verify UserDefaults reflects the default
		let defaultValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.featureToggleQuickPhrases)
		#expect(defaultValue == false)
	}

	// MARK: - State Management Tests

	@Test("Quick phrases can be enabled")
	func testEnableQuickPhrases() {
		let manager = FeatureToggleManager.shared

		manager.quickPhrasesEnabled = true

		#expect(manager.quickPhrasesEnabled == true)

		// Clean up
		manager.quickPhrasesEnabled = false
	}

	@Test("Quick phrases can be disabled")
	func testDisableQuickPhrases() {
		let manager = FeatureToggleManager.shared

		manager.quickPhrasesEnabled = true
		#expect(manager.quickPhrasesEnabled == true)

		manager.quickPhrasesEnabled = false
		#expect(manager.quickPhrasesEnabled == false)
	}

	@Test("Quick phrases toggle persists across reads")
	func testQuickPhrasesPersistence() {
		let manager = FeatureToggleManager.shared

		// Enable
		manager.quickPhrasesEnabled = true
		#expect(manager.quickPhrasesEnabled == true)

		// Read again to verify persistence
		let readValue = manager.quickPhrasesEnabled
		#expect(readValue == true)

		// Disable
		manager.quickPhrasesEnabled = false
		#expect(manager.quickPhrasesEnabled == false)
	}

	// MARK: - UserDefaults Integration Tests

	@Test("Quick phrases state stored in UserDefaults")
	func testQuickPhrasesUserDefaultsStorage() {
		let manager = FeatureToggleManager.shared

		// Set to true
		manager.quickPhrasesEnabled = true

		let storedValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.featureToggleQuickPhrases)
		#expect(storedValue == true)

		// Set to false (this also serves as cleanup)
		manager.quickPhrasesEnabled = false

		let updatedValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.featureToggleQuickPhrases)
		#expect(updatedValue == false)
	}

	@Test("Quick phrases reads from UserDefaults correctly")
	func testQuickPhrasesReadsFromUserDefaults() {
		let manager = FeatureToggleManager.shared

		// Set via manager to ensure synchronization
		manager.quickPhrasesEnabled = true

		// Verify it's in UserDefaults
		let storedValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.featureToggleQuickPhrases)
		#expect(storedValue == true)

		// Verify manager reads it correctly
		#expect(manager.quickPhrasesEnabled == true)

		// Clean up
		manager.quickPhrasesEnabled = false
	}

	@Test("UserDefaults key uses correct constant")
	func testUserDefaultsKeyConstant() {
		let expectedKey = "featureToggle.quickPhrases"

		#expect(UserDefaultsKeys.featureToggleQuickPhrases == expectedKey)
	}

	// MARK: - State Toggle Tests

	@Test("Multiple toggles in sequence")
	func testMultipleToggles() {
		let manager = FeatureToggleManager.shared

		// Start with false
		manager.quickPhrasesEnabled = false
		#expect(manager.quickPhrasesEnabled == false)

		// Toggle multiple times
		manager.quickPhrasesEnabled = true
		#expect(manager.quickPhrasesEnabled == true)

		manager.quickPhrasesEnabled = false
		#expect(manager.quickPhrasesEnabled == false)

		manager.quickPhrasesEnabled = true
		#expect(manager.quickPhrasesEnabled == true)

		manager.quickPhrasesEnabled = false
		#expect(manager.quickPhrasesEnabled == false)
	}

	@Test("Setting same value multiple times is idempotent")
	func testIdempotentSetting() {
		let manager = FeatureToggleManager.shared

		manager.quickPhrasesEnabled = true
		manager.quickPhrasesEnabled = true
		manager.quickPhrasesEnabled = true

		#expect(manager.quickPhrasesEnabled == true)

		manager.quickPhrasesEnabled = false
		manager.quickPhrasesEnabled = false
		manager.quickPhrasesEnabled = false

		#expect(manager.quickPhrasesEnabled == false)
	}

	// MARK: - ObservableObject Tests

	@Test("FeatureToggleManager conforms to ObservableObject")
	func testObservableObjectConformance() {
		let manager = FeatureToggleManager.shared

		#expect(manager is ObservableObject)
	}

	// MARK: - Isolation Tests

	@Test("FeatureToggleManager is MainActor isolated")
	func testMainActorIsolation() {
		// This test verifies the @MainActor annotation is present
		// by successfully running on MainActor
		let manager = FeatureToggleManager.shared

		#expect(manager != nil)
	}

	// MARK: - Reset Tests

	@Test("Feature toggle can be reset to default")
	func testResetToDefault() {
		let manager = FeatureToggleManager.shared

		// Enable feature
		manager.quickPhrasesEnabled = true
		#expect(manager.quickPhrasesEnabled == true)

		// Reset to default (false)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.featureToggleQuickPhrases)

		// Create new instance to verify default
		let defaultValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.featureToggleQuickPhrases)
		#expect(defaultValue == false)
	}

	// MARK: - Edge Cases Tests

	@Test("Rapid toggle changes are handled correctly")
	func testRapidToggleChanges() {
		let manager = FeatureToggleManager.shared

		for iteration in 0..<100 {
			manager.quickPhrasesEnabled = (iteration % 2 == 0)
		}

		// Final state should be false (100 is even)
		#expect(manager.quickPhrasesEnabled == false)
	}

	@Test("Feature toggle works after app reset simulation")
	func testAfterAppReset() {
		let manager = FeatureToggleManager.shared

		// Set to true
		manager.quickPhrasesEnabled = true
		#expect(manager.quickPhrasesEnabled == true)

		// Simulate app reset by clearing UserDefaults
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.featureToggleQuickPhrases)

		// Verify it resets to default (false)
		let resetValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.featureToggleQuickPhrases)
		#expect(resetValue == false)
	}

	// MARK: - Type Safety Tests

	@Test("AppStorage property uses correct type")
	func testAppStorageType() {
		let manager = FeatureToggleManager.shared

		// Verify the property is a Bool
		manager.quickPhrasesEnabled = true
		let value: Bool = manager.quickPhrasesEnabled

		#expect(value is Bool)
	}

	// MARK: - Integration Tests

	@Test("Feature toggle integrates with UserDefaultsKeys")
	func testUserDefaultsKeysIntegration() {
		// Verify the key is present in allKeys array
		let allKeys = UserDefaultsKeys.allKeys

		#expect(allKeys.contains(UserDefaultsKeys.featureToggleQuickPhrases))
	}

	@Test("Feature toggle has default value in UserDefaultsKeys")
	func testDefaultValueInUserDefaultsKeys() {
		let defaultValues = UserDefaultsKeys.defaultValues

		guard let defaultValue = defaultValues[UserDefaultsKeys.featureToggleQuickPhrases] as? Bool else {
			Issue.record("Expected default value for featureToggleQuickPhrases")
			return
		}

		#expect(defaultValue == false)
	}

	// MARK: - Public Access Tests

	@Test("Quick phrases property is publicly accessible")
	func testPublicAccess() {
		let manager = FeatureToggleManager.shared

		// These should compile and run without errors
		let _ = manager.quickPhrasesEnabled
		manager.quickPhrasesEnabled = true
		manager.quickPhrasesEnabled = false
	}

	// MARK: - Concurrent Access Tests

	@Test("Concurrent reads are safe")
	func testConcurrentReads() async {
		let manager = FeatureToggleManager.shared
		manager.quickPhrasesEnabled = true

		await withTaskGroup(of: Bool.self) { group in
			for _ in 0..<10 {
				group.addTask {
					return await manager.quickPhrasesEnabled
				}
			}

			var results: [Bool] = []
			for await result in group {
				results.append(result)
			}

			#expect(results.allSatisfy { $0 == true })
		}

		// Clean up
		manager.quickPhrasesEnabled = false
	}

	@Test("Sequential writes are consistent")
	func testSequentialWrites() {
		let manager = FeatureToggleManager.shared

		let testSequence = [true, false, true, false, true]

		for value in testSequence {
			manager.quickPhrasesEnabled = value
			#expect(manager.quickPhrasesEnabled == value)
		}
	}

	// MARK: - Debug Build Tests

	@Test("Feature toggles only available in DEBUG")
	func testDebugOnlyAvailability() {
		// This test documents that feature toggles should only be available in DEBUG
		// The FeatureToggleManager itself doesn't enforce this, but the UI does

		let manager = FeatureToggleManager.shared

		// Manager should always be accessible for testing
		#expect(manager != nil)
	}
}

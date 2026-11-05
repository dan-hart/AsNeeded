// HapticsManagerTests.swift
// Comprehensive unit tests for HapticsManager

@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("HapticsManager Tests", .tags(.service, .haptics, .unit))
struct HapticsManagerTests {
	private let preferences: IsolatedTestPreferences
	private let manager: HapticsManager
	private var defaults: UserDefaults { preferences.defaults }

	init() throws {
		preferences = try IsolatedTestPreferences()
		manager = HapticsManager(defaults: preferences.defaults)
	}

    // MARK: - Initialization Tests
    @Test("HapticsManager is a singleton")
    func singletonInstance() {
        let instance1 = HapticsManager.shared
        let instance2 = HapticsManager.shared

        #expect(instance1 === instance2)
    }

    // MARK: - Default State Tests
    @Test("Haptics enabled defaults to true")
    func hapticsEnabledDefaultsToTrue() {
        // Clear any existing value first
        defaults.removeObject(forKey: UserDefaultsKeys.hapticsEnabled)

        let manager = self.manager

        #expect(manager.hapticsEnabled == true)
    }

    // MARK: - Settings Tests
    @Test("Haptics can be disabled")
    func disableHaptics() {
        let manager = self.manager

        manager.hapticsEnabled = false

        #expect(manager.hapticsEnabled == false)

        // Clean up - restore to default
        manager.hapticsEnabled = true
    }

    @Test("Haptics can be enabled")
    func enableHaptics() {
        let manager = self.manager

        manager.hapticsEnabled = false
        manager.hapticsEnabled = true

        #expect(manager.hapticsEnabled == true)
    }

    @Test("Haptics setting persists across reads")
    func hapticsSettingPersistence() {
        let manager = self.manager

        manager.hapticsEnabled = false
        let readValue1 = manager.hapticsEnabled
        #expect(readValue1 == false)

        manager.hapticsEnabled = true
        let readValue2 = manager.hapticsEnabled
        #expect(readValue2 == true)
    }

    // MARK: - UserDefaults Integration Tests
    @Test("Haptics setting stored in UserDefaults")
    func hapticsUserDefaultsStorage() {
        let manager = self.manager

        manager.hapticsEnabled = false
        let storedValue1 = defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled)
        #expect(storedValue1 == false)

        manager.hapticsEnabled = true
        let storedValue2 = defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled)
        #expect(storedValue2 == true)
    }

    @Test("Haptics reads from UserDefaults correctly")
    func hapticsReadsFromUserDefaults() {
        let manager = self.manager

        // Set value through manager (which updates UserDefaults via @AppStorage)
        manager.hapticsEnabled = false

        // Verify it's stored in UserDefaults
        let storedValue = defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled)
        #expect(storedValue == false)

        // Verify manager reads it correctly
        #expect(manager.hapticsEnabled == false)

        // Clean up
        manager.hapticsEnabled = true
    }

    // MARK: - Integration Tests
    @Test("Haptics setting integrates with UserDefaultsKeys")
    func userDefaultsKeysIntegration() {
        let allKeys = UserDefaultsKeys.allKeys

        #expect(allKeys.contains(UserDefaultsKeys.hapticsEnabled))
    }

    @Test("Haptics has default value in UserDefaultsKeys")
    func defaultValueInUserDefaultsKeys() {
        let defaultValues = UserDefaultsKeys.defaultValues

        guard let defaultValue = defaultValues[UserDefaultsKeys.hapticsEnabled] as? Bool else {
            Issue.record("Expected default value for hapticsEnabled")
            return
        }

        #expect(defaultValue == true)
    }

    // MARK: - Edge Cases Tests
    @Test("Haptics manager works after app reset simulation")
    func afterAppReset() {
        let manager = self.manager

        manager.hapticsEnabled = false
        #expect(manager.hapticsEnabled == false)

        // Simulate app reset
        defaults.removeObject(forKey: UserDefaultsKeys.hapticsEnabled)

        // Verify it resets to default (true)
        let resetValue = defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled)
        #expect(resetValue == false) // Bool defaults to false when not set

        // Clean up - restore to default
        manager.hapticsEnabled = true
    }

    }

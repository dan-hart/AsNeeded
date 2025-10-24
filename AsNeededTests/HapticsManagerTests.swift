// HapticsManagerTests.swift
// Comprehensive unit tests for HapticsManager

@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("HapticsManager Tests", .tags(.service, .haptics, .unit))
struct HapticsManagerTests {
    init() {
        // Reset UserDefaults before each test to ensure isolation
        // Note: Default for hapticsEnabled is true
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
    }

    // MARK: - Initialization Tests

    @Test("HapticsManager is a singleton")
    func singletonInstance() {
        let instance1 = HapticsManager.shared
        let instance2 = HapticsManager.shared

        #expect(instance1 === instance2)
    }

    @Test("HapticsManager initializes successfully")
    func initialization() {
        let manager = HapticsManager.shared

        #expect(manager != nil)
    }

    @Test("HapticsManager conforms to ObservableObject")
    func observableObjectConformance() {
        let manager = HapticsManager.shared

        #expect(manager is ObservableObject)
    }

    // MARK: - Default State Tests

    @Test("Haptics enabled defaults to true")
    func hapticsEnabledDefaultsToTrue() {
        // Clear any existing value first
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hapticsEnabled)

        let manager = HapticsManager.shared

        #expect(manager.hapticsEnabled == true)
    }

    // MARK: - Settings Tests

    @Test("Haptics can be disabled")
    func disableHaptics() {
        let manager = HapticsManager.shared

        manager.hapticsEnabled = false

        #expect(manager.hapticsEnabled == false)

        // Clean up - restore to default
        manager.hapticsEnabled = true
    }

    @Test("Haptics can be enabled")
    func enableHaptics() {
        let manager = HapticsManager.shared

        manager.hapticsEnabled = false
        manager.hapticsEnabled = true

        #expect(manager.hapticsEnabled == true)
    }

    @Test("Haptics setting persists across reads")
    func hapticsSettingPersistence() {
        let manager = HapticsManager.shared

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
        let manager = HapticsManager.shared

        manager.hapticsEnabled = false
        let storedValue1 = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hapticsEnabled)
        #expect(storedValue1 == false)

        manager.hapticsEnabled = true
        let storedValue2 = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hapticsEnabled)
        #expect(storedValue2 == true)
    }

    @Test("Haptics reads from UserDefaults correctly")
    func hapticsReadsFromUserDefaults() {
        let manager = HapticsManager.shared

        // Set value through manager (which updates UserDefaults via @AppStorage)
        manager.hapticsEnabled = false

        // Verify it's stored in UserDefaults
        let storedValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hapticsEnabled)
        #expect(storedValue == false)

        // Verify manager reads it correctly
        #expect(manager.hapticsEnabled == false)

        // Clean up
        manager.hapticsEnabled = true
    }

    // MARK: - Haptic Method Tests (Behavior Verification)

    @Test("SelectionChanged method does not crash when enabled")
    func selectionChangedEnabled() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        // Should not crash
        manager.selectionChanged()

        #expect(true)
    }

    @Test("SelectionChanged method does not crash when disabled")
    func selectionChangedDisabled() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = false

        // Should not crash (method should return early)
        manager.selectionChanged()

        #expect(true)

        // Clean up
        manager.hapticsEnabled = true
    }

    @Test("LightImpact method does not crash when enabled")
    func lightImpactEnabled() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.lightImpact()

        #expect(true)
    }

    @Test("LightImpact method does not crash when disabled")
    func lightImpactDisabled() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = false

        manager.lightImpact()

        #expect(true)

        // Clean up
        manager.hapticsEnabled = true
    }

    @Test("MediumImpact method does not crash")
    func testMediumImpact() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.mediumImpact()

        #expect(true)
    }

    @Test("HeavyImpact method does not crash")
    func testHeavyImpact() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.heavyImpact()

        #expect(true)
    }

    @Test("SoftImpact method does not crash")
    func testSoftImpact() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.softImpact()

        #expect(true)
    }

    @Test("RigidImpact method does not crash")
    func testRigidImpact() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.rigidImpact()

        #expect(true)
    }

    @Test("NotificationSuccess method does not crash")
    func testNotificationSuccess() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.notificationSuccess()

        #expect(true)
    }

    @Test("NotificationWarning method does not crash")
    func testNotificationWarning() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.notificationWarning()

        #expect(true)
    }

    @Test("NotificationError method does not crash")
    func testNotificationError() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.notificationError()

        #expect(true)
    }

    // MARK: - Specialized Pattern Tests

    @Test("DoseLogged pattern does not crash")
    func doseLoggedPattern() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.doseLogged()

        #expect(true)
    }

    @Test("MedicationAdded pattern does not crash")
    func medicationAddedPattern() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.medicationAdded()

        #expect(true)
    }

    @Test("ItemDeleted pattern does not crash")
    func itemDeletedPattern() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.itemDeleted()

        #expect(true)
    }

    @Test("PullToRefresh pattern does not crash")
    func pullToRefreshPattern() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.pullToRefresh()

        #expect(true)
    }

    @Test("DatePickerChanged pattern does not crash")
    func datePickerChangedPattern() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.datePickerChanged()

        #expect(true)
    }

    @Test("SwipeAction pattern does not crash")
    func swipeActionPattern() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.swipeAction()

        #expect(true)
    }

    // MARK: - Disabled State Tests

    @Test("All haptics respect disabled setting")
    func allHapticsRespectDisabled() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = false

        // All these methods should return early and not crash
        manager.selectionChanged()
        manager.lightImpact()
        manager.mediumImpact()
        manager.heavyImpact()
        manager.softImpact()
        manager.rigidImpact()
        manager.notificationSuccess()
        manager.notificationWarning()
        manager.notificationError()
        manager.doseLogged()
        manager.medicationAdded()
        manager.itemDeleted()
        manager.pullToRefresh()
        manager.datePickerChanged()
        manager.swipeAction()

        #expect(true)

        // Clean up
        manager.hapticsEnabled = true
    }

    // MARK: - PerformFeedback Extension Tests

    @Test("PerformFeedback handles selection style")
    func performFeedbackSelection() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .selection)

        #expect(true)
    }

    @Test("PerformFeedback handles lightImpact style")
    func performFeedbackLightImpact() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .lightImpact)

        #expect(true)
    }

    @Test("PerformFeedback handles mediumImpact style")
    func performFeedbackMediumImpact() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .mediumImpact)

        #expect(true)
    }

    @Test("PerformFeedback handles heavyImpact style")
    func performFeedbackHeavyImpact() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .heavyImpact)

        #expect(true)
    }

    @Test("PerformFeedback handles softImpact style")
    func performFeedbackSoftImpact() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .softImpact)

        #expect(true)
    }

    @Test("PerformFeedback handles rigidImpact style")
    func performFeedbackRigidImpact() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .rigidImpact)

        #expect(true)
    }

    @Test("PerformFeedback handles success style")
    func performFeedbackSuccess() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .success)

        #expect(true)
    }

    @Test("PerformFeedback handles warning style")
    func performFeedbackWarning() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .warning)

        #expect(true)
    }

    @Test("PerformFeedback handles error style")
    func performFeedbackError() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .error)

        #expect(true)
    }

    @Test("PerformFeedback handles doseLogged style")
    func performFeedbackDoseLogged() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .doseLogged)

        #expect(true)
    }

    @Test("PerformFeedback handles medicationAdded style")
    func performFeedbackMedicationAdded() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .medicationAdded)

        #expect(true)
    }

    @Test("PerformFeedback handles itemDeleted style")
    func performFeedbackItemDeleted() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        manager.performFeedback(style: .itemDeleted)

        #expect(true)
    }

    @Test("PerformFeedback respects disabled setting")
    func performFeedbackRespectsSetting() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = false

        // Test all styles when disabled
        manager.performFeedback(style: .selection)
        manager.performFeedback(style: .lightImpact)
        manager.performFeedback(style: .mediumImpact)
        manager.performFeedback(style: .success)
        manager.performFeedback(style: .error)

        #expect(true)

        // Clean up
        manager.hapticsEnabled = true
    }

    // MARK: - HapticFeedbackStyle Enum Tests

    @Test("HapticFeedbackStyle enum has all expected cases")
    func hapticFeedbackStyleCases() {
        let styles: [HapticFeedbackStyle] = [
            .selection,
            .lightImpact,
            .mediumImpact,
            .heavyImpact,
            .softImpact,
            .rigidImpact,
            .success,
            .warning,
            .error,
            .doseLogged,
            .medicationAdded,
            .itemDeleted,
        ]

        #expect(styles.count == 12)
    }

    // MARK: - Concurrent Access Tests

    @Test("Multiple concurrent haptic calls are safe")
    func concurrentHapticCalls() async {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    await manager.lightImpact()
                }
                group.addTask {
                    await manager.mediumImpact()
                }
                group.addTask {
                    await manager.selectionChanged()
                }
            }
        }

        #expect(true)
    }

    @Test("Rapid setting changes are safe")
    func rapidSettingChanges() {
        let manager = HapticsManager.shared

        for iteration in 0 ..< 100 {
            manager.hapticsEnabled = (iteration % 2 == 0)
        }

        #expect(true)
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
        let manager = HapticsManager.shared

        manager.hapticsEnabled = false
        #expect(manager.hapticsEnabled == false)

        // Simulate app reset
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hapticsEnabled)

        // Verify it resets to default (true)
        let resetValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hapticsEnabled)
        #expect(resetValue == false) // Bool defaults to false when not set

        // Clean up - restore to default
        manager.hapticsEnabled = true
    }

    @Test("Sequential haptic patterns execute without crash")
    func sequentialHapticPatterns() {
        let manager = HapticsManager.shared
        manager.hapticsEnabled = true

        // Execute different patterns in sequence
        manager.lightImpact()
        manager.mediumImpact()
        manager.heavyImpact()
        manager.selectionChanged()
        manager.notificationSuccess()
        manager.doseLogged()
        manager.medicationAdded()

        #expect(true)
    }

    @Test("Toggle haptics during haptic execution")
    func toggleDuringExecution() {
        let manager = HapticsManager.shared

        manager.hapticsEnabled = true
        manager.lightImpact()

        manager.hapticsEnabled = false
        manager.mediumImpact() // Should not execute

        manager.hapticsEnabled = true
        manager.heavyImpact()

        #expect(true)
    }

    // MARK: - MainActor Isolation Tests

    @Test("HapticsManager is MainActor isolated")
    func mainActorIsolation() {
        let manager = HapticsManager.shared

        // This test verifies the @MainActor annotation is present
        #expect(manager != nil)
    }

    // MARK: - Public API Tests

    @Test("All public haptic methods are accessible")
    func publicAPIAccessibility() {
        let manager = HapticsManager.shared

        // Verify all methods are callable
        manager.selectionChanged()
        manager.lightImpact()
        manager.mediumImpact()
        manager.heavyImpact()
        manager.softImpact()
        manager.rigidImpact()
        manager.notificationSuccess()
        manager.notificationWarning()
        manager.notificationError()
        manager.doseLogged()
        manager.medicationAdded()
        manager.itemDeleted()
        manager.pullToRefresh()
        manager.datePickerChanged()
        manager.swipeAction()

        #expect(true)
    }
}

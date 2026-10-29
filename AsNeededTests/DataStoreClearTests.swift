// DataStoreClearTests.swift
// Tests for DataStore.clearAllData() AppStorage cleanup functionality

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct DataStoreClearTests {
	private let preferences: IsolatedTestPreferences
	private let navigation: NavigationManager
	private var defaults: UserDefaults { preferences.defaults }

	init() throws {
		let preferences = try IsolatedTestPreferences()
		self.preferences = preferences
		navigation = NavigationManager(defaults: preferences.defaults)
	}

	private func makeStore() -> DataStore {
		DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: defaults, defaultsDomainName: preferences.name, navigationManager: navigation)
	}

	@Test("Reset preserves device storage version and legacy recovery paths")
	func resetPreservesStorageRecoveryMetadata() throws {
		let suite = "DataStoreClearTests.recovery.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		let recoveryKeys = [UserDefaultsKeys.storageSchemaVersion, UserDefaultsKeys.archivedLegacyMedicationsPath, UserDefaultsKeys.archivedLegacyEventsPath]
		for key in recoveryKeys {
			#expect(UserDefaultsKeys.keysToSkip.contains(key))
			defaults.set("recovery metadata", forKey: key)
		}
		DataStore.resetAppSettings(defaults: defaults, sharedDefaults: nil, navigationManager: navigation)
		for key in recoveryKeys {
			#expect(defaults.string(forKey: key) == "recovery metadata")
		}
	}

	private func makeDefaults(suiteName: String) throws -> UserDefaults {
		let defaults = try #require(UserDefaults(suiteName: suiteName))
		defaults.removePersistentDomain(forName: suiteName)
		return defaults
	}

	@Test("resetAppSettings clears mirrored safety profiles from shared defaults")
	func resetAppSettingsClearsMirroredSafetyProfiles() throws {
		let defaultsSuite = "DataStoreClearTests.defaults.\(UUID().uuidString)"
		let sharedSuite = "DataStoreClearTests.shared.\(UUID().uuidString)"
		let defaults = try makeDefaults(suiteName: defaultsSuite)
		let sharedDefaults = try makeDefaults(suiteName: sharedSuite)
		defer {
			defaults.removePersistentDomain(forName: defaultsSuite)
			sharedDefaults.removePersistentDomain(forName: sharedSuite)
		}

		let profile = MedicationSafetyProfile(
			minimumHoursBetweenDoses: 4,
			cautionHoursBetweenDoses: 6,
			maxDailyAmount: 8,
			duplicateDoseWindowMinutes: 30,
			lowStockThreshold: 10,
			refillLeadDays: 5
		)
		let encoded = try? JSONEncoder().encode([UUID().uuidString: profile])
		defaults.set(encoded, forKey: UserDefaultsKeys.medicationSafetyProfiles)
		sharedDefaults.set(encoded, forKey: UserDefaultsKeys.medicationSafetyProfiles)

		DataStore.resetAppSettings(defaults: defaults, sharedDefaults: sharedDefaults, navigationManager: navigation)

		#expect(defaults.data(forKey: UserDefaultsKeys.medicationSafetyProfiles) == nil)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationSafetyProfiles) == nil)
	}

    @Test("clearAllData removes all AppStorage medication selections")
    func clearAllDataRemovesAppStorageSelections() async throws {
        // Given: Create test store
        let store = makeStore()

        // Create and add test medications
        let med1 = ANMedicationConcept(clinicalName: "Test Med 1")
        let med2 = ANMedicationConcept(clinicalName: "Test Med 2")

        try await store.addMedication(med1)
        try await store.addMedication(med2)

        // Create and add test events
        let event1 = ANEventConcept(
            eventType: .doseTaken,
            medication: med1,
            dose: ANDoseConcept(amount: 1, unit: .unit),
            date: Date()
        )
        try await store.addEvent(event1)

        // Set AppStorage values to simulate user selections
        defaults.set(med1.id.uuidString, forKey: "historySelectedMedicationID")
        defaults.set(med2.id.uuidString, forKey: "trendsSelectedMedicationID")
        defaults.set([med1.id.uuidString, med2.id.uuidString], forKey: "medicationOrder")

        // Set navigation target
        navigation.historyTargetMedicationID = med1.id.uuidString

        // When: Clear all data
        try await store.clearAllData()

        // Then: Verify all data and AppStorage values are cleared
        #expect(store.medications.isEmpty)
        #expect(store.events.isEmpty)
        #expect(defaults.string(forKey: "historySelectedMedicationID") == nil)
        #expect(defaults.string(forKey: "trendsSelectedMedicationID") == nil)
        #expect(defaults.array(forKey: "medicationOrder") == nil)
        #expect(navigation.historyTargetMedicationID == nil)
    }

    @Test("clearAllData properly synchronizes UserDefaults")
    func clearAllDataSynchronizesUserDefaults() async throws {
        // Given: Create test store
        let store = makeStore()

        // Create and add test medication
        let med = ANMedicationConcept(clinicalName: "Sync Test Med")
        try await store.addMedication(med)

        // Set multiple AppStorage values
        let medIDString = med.id.uuidString
        defaults.set(medIDString, forKey: "historySelectedMedicationID")
        defaults.set(medIDString, forKey: "trendsSelectedMedicationID")
        defaults.set([medIDString], forKey: "medicationOrder")

        // When: Clear all data
        try await store.clearAllData()

        // Force a synchronize to ensure changes are persisted


        // Then: Re-read values to ensure they're actually cleared
        let historyID = defaults.string(forKey: "historySelectedMedicationID")
        let trendsID = defaults.string(forKey: "trendsSelectedMedicationID")
        let order = defaults.array(forKey: "medicationOrder")

        #expect(historyID == nil)
        #expect(trendsID == nil)
        #expect(order == nil)

        // Verify stores are also empty
        #expect(store.medications.isEmpty)
        #expect(store.events.isEmpty)
    }

    @Test("clearAllData handles missing AppStorage values gracefully")
    func clearAllDataHandlesMissingValues() async throws {
        // Given: Create test store with no pre-existing AppStorage values
        let store = makeStore()

        // Add a medication but don't set any AppStorage values
        let med = ANMedicationConcept(clinicalName: "Missing Test Med")
        try await store.addMedication(med)

        // Ensure AppStorage values don't exist
        defaults.removeObject(forKey: "historySelectedMedicationID")
        defaults.removeObject(forKey: "trendsSelectedMedicationID")
        defaults.removeObject(forKey: "medicationOrder")

        // When: Clear all data (should not throw even with missing values)
        try await store.clearAllData()

        // Then: Verify everything is cleared without errors
        #expect(store.medications.isEmpty)
        #expect(defaults.string(forKey: "historySelectedMedicationID") == nil)
        #expect(defaults.string(forKey: "trendsSelectedMedicationID") == nil)
        #expect(defaults.array(forKey: "medicationOrder") == nil)
    }

    @Test("clearAllData clears NavigationManager state")
    func clearAllDataClearsNavigationManager() async throws {
        // Given: Create test store
        let store = makeStore()

        // Create and add test medication
        let med = ANMedicationConcept(clinicalName: "Nav Test Med")
        try await store.addMedication(med)

        // Set NavigationManager state
        navigation.historyTargetMedicationID = med.id.uuidString
        navigation.historyTargetDate = Date()

        // When: Clear all data
        try await store.clearAllData()

        // Then: Verify NavigationManager state is cleared
        #expect(navigation.historyTargetMedicationID == nil)
        #expect(navigation.historyTargetDate == nil)
    }
}

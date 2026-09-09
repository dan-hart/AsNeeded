// DataStoreClearTests.swift
// Tests for DataStore.clearAllData() AppStorage cleanup functionality

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct DataStoreClearTests {
	private func makeDefaults(suiteName: String) -> UserDefaults {
		let defaults = UserDefaults(suiteName: suiteName) ?? .standard
		defaults.removePersistentDomain(forName: suiteName)
		return defaults
	}

	@Test("resetAppSettings clears active refill preferences and preserves recovery state")
	func resetAppSettingsClearsActiveRefillPreferencesAndPreservesRecoveryState() throws {
		let defaultsSuite = "DataStoreClearTests.defaults.\(UUID().uuidString)"
		let sharedSuite = "DataStoreClearTests.shared.\(UUID().uuidString)"
		let defaults = makeDefaults(suiteName: defaultsSuite)
		let sharedDefaults = makeDefaults(suiteName: sharedSuite)
		defer {
			defaults.removePersistentDomain(forName: defaultsSuite)
			sharedDefaults.removePersistentDomain(forName: sharedSuite)
		}

		let profile = MedicationRefillProfile(lowStockThreshold: 10)
		let encoded = try JSONEncoder().encode([UUID().uuidString: profile])
		let archive = Data([1, 2, 3])
		for destination in [defaults, sharedDefaults] {
			destination.set(encoded, forKey: UserDefaultsKeys.medicationRefillProfiles)
			destination.set(encoded, forKey: UserDefaultsKeys.legacyMedicationProfiles)
			destination.set(archive, forKey: UserDefaultsKeys.archivedMedicationProfiles)
			destination.set(true, forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted)
		}

		let resetSucceeded = DataStore.resetAppSettings(defaults: defaults, sharedDefaults: sharedDefaults)

		#expect(resetSucceeded)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == archive)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == archive)
		#expect(defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
		#expect(sharedDefaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
		#expect(defaults.bool(forKey: UserDefaultsKeys.trendsQuestionsEnabled) == false)
	}

	@Test("resetAppSettings clears urgency preferences and preserves migration marker")
	func resetAppSettingsClearsUrgencyPreferencesAndPreservesMigrationMarker() throws {
		let defaultsSuite = "DataStoreClearTests.urgencyDefaults.\(UUID().uuidString)"
		let sharedSuite = "DataStoreClearTests.urgencyShared.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
		let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuite))
		defaults.removePersistentDomain(forName: defaultsSuite)
		sharedDefaults.removePersistentDomain(forName: sharedSuite)
		defer {
			defaults.removePersistentDomain(forName: defaultsSuite)
			sharedDefaults.removePersistentDomain(forName: sharedSuite)
		}

		let urgencyStore = MedicationNotificationUrgencyStore(defaults: defaults)
		#expect(urgencyStore.save(true, for: UUID()))
		#expect(urgencyStore.markMigrationCompleted())

		let resetSucceeded = DataStore.resetAppSettings(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			profileStore: MedicationRefillProfileStore(
				defaults: defaults,
				sharedDefaults: sharedDefaults
			)
		)

		#expect(resetSucceeded)
		#expect(defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) == nil)
		#expect(defaults.bool(forKey: UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted))
	}

	@Test("clearAllData erases refill migration state and recovery archives")
	func clearAllDataErasesRefillMigrationStateAndRecoveryArchives() async throws {
		let sharedDefaults = try #require(UserDefaults(suiteName: StorageConstants.appGroupIdentifier))
		let activeData = try JSONEncoder().encode([
			UUID().uuidString: MedicationRefillProfile(lowStockThreshold: 8),
		])
		let legacyMedicationID = UUID()
		let legacyData = try JSONSerialization.data(withJSONObject: [
			legacyMedicationID.uuidString: ["lowStockThreshold": 14],
		])
		let archive = Data([9, 8, 7])
		let keys = [
			UserDefaultsKeys.medicationRefillProfiles,
			UserDefaultsKeys.legacyMedicationProfiles,
			UserDefaultsKeys.archivedMedicationProfiles,
			UserDefaultsKeys.medicationProfilesMigrationCompleted,
		]
		defer {
			for key in keys {
				UserDefaults.standard.removeObject(forKey: key)
				sharedDefaults.removeObject(forKey: key)
			}
		}

		for destination in [UserDefaults.standard, sharedDefaults] {
			destination.set(activeData, forKey: UserDefaultsKeys.medicationRefillProfiles)
			destination.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
			destination.set(archive, forKey: UserDefaultsKeys.archivedMedicationProfiles)
			destination.set(true, forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted)
		}

		let store = DataStore(testIdentifier: "clear-refill-state-\(UUID().uuidString)")
		try await store.clearAllData()

		for destination in [UserDefaults.standard, sharedDefaults] {
			#expect(destination.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
			#expect(destination.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
			#expect(destination.object(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted) == nil)
			#expect(destination.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == nil)
		}

		let restartedStore = MedicationRefillProfileStore(
			defaults: .standard,
			sharedDefaults: sharedDefaults
		)
		#expect(restartedStore.profile(for: legacyMedicationID) == .empty)
	}

	@Test("resetAppSettings failure preserves unrelated settings and profile state")
	func resetAppSettingsFailurePreservesUnrelatedSettingsAndProfileState() throws {
		let defaults = makeDefaults(suiteName: "DataStoreClearTests.resetFailure.\(UUID().uuidString)")
		let sharedDefaults = makeDefaults(suiteName: "DataStoreClearTests.sharedResetFailure.\(UUID().uuidString)")
		let medicationID = UUID()
		let activeData = try JSONEncoder().encode([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 10),
		])
		for destination in [defaults, sharedDefaults] {
			destination.set(activeData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		}
		defaults.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		let profileStore = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			activeRemover: { destination, key in
				guard destination !== sharedDefaults else { return }
				destination.removeObject(forKey: key)
			}
		)

		let succeeded = DataStore.resetAppSettings(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			profileStore: profileStore
		)

		#expect(!succeeded)
		#expect(!defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == activeData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == activeData)
		let recreatedStore = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: sharedDefaults)
		#expect(recreatedStore.profile(for: medicationID).lowStockThreshold == 10)
	}

	@Test("clearAllData surfaces profile erasure failure before deleting user data")
	func clearAllDataSurfacesProfileErasureFailureBeforeDeletingUserData() async throws {
		let defaults = makeDefaults(suiteName: "DataStoreClearTests.clearFailure.\(UUID().uuidString)")
		let sharedDefaults = makeDefaults(suiteName: "DataStoreClearTests.sharedClearFailure.\(UUID().uuidString)")
		let medicationID = UUID()
		let activeData = try JSONEncoder().encode([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 10),
		])
		for destination in [defaults, sharedDefaults] {
			destination.set(activeData, forKey: UserDefaultsKeys.medicationRefillProfiles)
			destination.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.archivedMedicationProfiles)
		}
		let profileStore = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			activeRemover: { destination, key in
				guard destination !== sharedDefaults else { return }
				destination.removeObject(forKey: key)
			}
		)
		let dataStore = DataStore(
			testIdentifier: "clear-profile-failure",
			settingsDefaults: defaults,
			refillProfileStore: profileStore
		)
		let medication = ANMedicationConcept(id: medicationID, clinicalName: "Preserved")
		try await dataStore.addMedication(medication)

		await #expect(throws: AppSettingsError.self) {
			try await dataStore.clearAllData()
		}
		#expect(dataStore.medications.map(\.id) == [medicationID])
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == activeData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == activeData)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == Data([1, 2, 3]))
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == Data([1, 2, 3]))
	}

	@Test("clearAllData surfaces Boutique clear failure after destructive privacy erasure")
	func clearAllDataSurfacesDatabaseFailureAfterPrivacyErasure() async throws {
		let defaults = makeDefaults(suiteName: "DataStoreClearTests.databaseFailure.\(UUID().uuidString)")
		let sharedDefaults = makeDefaults(suiteName: "DataStoreClearTests.sharedDatabaseFailure.\(UUID().uuidString)")
		let medicationID = UUID()
		let profileData = try JSONEncoder().encode([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 10),
		])
		for destination in [defaults, sharedDefaults] {
			destination.set(profileData, forKey: UserDefaultsKeys.medicationRefillProfiles)
			destination.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.archivedMedicationProfiles)
		}
		let profileStore = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: sharedDefaults)
		let dataStore = DataStore(
			testIdentifier: "clear-database-failure",
			settingsDefaults: defaults,
			refillProfileStore: profileStore,
			importFailureInjection: .init(
				beforeExplicitClearUserData: { throw ClearFailure.intentional }
			)
		)
		let medication = ANMedicationConcept(id: medicationID, clinicalName: "Still Stored")
		try await dataStore.addMedication(medication)

		await #expect(throws: ClearFailure.self) {
			try await dataStore.clearAllData()
		}
		#expect(dataStore.medications.map(\.id) == [medicationID])
		for destination in [defaults, sharedDefaults] {
			#expect(destination.object(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
			#expect(destination.object(forKey: UserDefaultsKeys.archivedMedicationProfiles) == nil)
		}
	}

	private enum ClearFailure: Error {
		case intentional
	}

    @Test("clearAllData removes all AppStorage medication selections")
    func clearAllDataRemovesAppStorageSelections() async throws {
        // Given: Create test store
        let store = DataStore(testIdentifier: "cleartest")

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
        UserDefaults.standard.set(med1.id.uuidString, forKey: "historySelectedMedicationID")
        UserDefaults.standard.set(med2.id.uuidString, forKey: "trendsSelectedMedicationID")
        UserDefaults.standard.set([med1.id.uuidString, med2.id.uuidString], forKey: "medicationOrder")

        // Set navigation target
        NavigationManager.shared.historyTargetMedicationID = med1.id.uuidString

        // When: Clear all data
        try await store.clearAllData()

        // Then: Verify all data and AppStorage values are cleared
        #expect(store.medications.isEmpty)
        #expect(store.events.isEmpty)
        #expect(UserDefaults.standard.string(forKey: "historySelectedMedicationID") == nil)
        #expect(UserDefaults.standard.string(forKey: "trendsSelectedMedicationID") == nil)
        #expect(UserDefaults.standard.array(forKey: "medicationOrder") == nil)
        #expect(NavigationManager.shared.historyTargetMedicationID == nil)
    }

    @Test("clearAllData properly synchronizes UserDefaults")
    func clearAllDataSynchronizesUserDefaults() async throws {
        // Given: Create test store
        let store = DataStore(testIdentifier: "synctest")

        // Create and add test medication
        let med = ANMedicationConcept(clinicalName: "Sync Test Med")
        try await store.addMedication(med)

        // Set multiple AppStorage values
        let medIDString = med.id.uuidString
        UserDefaults.standard.set(medIDString, forKey: "historySelectedMedicationID")
        UserDefaults.standard.set(medIDString, forKey: "trendsSelectedMedicationID")
        UserDefaults.standard.set([medIDString], forKey: "medicationOrder")

        // When: Clear all data
        try await store.clearAllData()

        // Force a synchronize to ensure changes are persisted


        // Then: Re-read values to ensure they're actually cleared
        let historyID = UserDefaults.standard.string(forKey: "historySelectedMedicationID")
        let trendsID = UserDefaults.standard.string(forKey: "trendsSelectedMedicationID")
        let order = UserDefaults.standard.array(forKey: "medicationOrder")

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
        let store = DataStore(testIdentifier: "missingtest")

        // Add a medication but don't set any AppStorage values
        let med = ANMedicationConcept(clinicalName: "Missing Test Med")
        try await store.addMedication(med)

        // Ensure AppStorage values don't exist
        UserDefaults.standard.removeObject(forKey: "historySelectedMedicationID")
        UserDefaults.standard.removeObject(forKey: "trendsSelectedMedicationID")
        UserDefaults.standard.removeObject(forKey: "medicationOrder")

        // When: Clear all data (should not throw even with missing values)
        try await store.clearAllData()

        // Then: Verify everything is cleared without errors
        #expect(store.medications.isEmpty)
        #expect(UserDefaults.standard.string(forKey: "historySelectedMedicationID") == nil)
        #expect(UserDefaults.standard.string(forKey: "trendsSelectedMedicationID") == nil)
        #expect(UserDefaults.standard.array(forKey: "medicationOrder") == nil)
    }

    @Test("clearAllData clears NavigationManager state")
    func clearAllDataClearsNavigationManager() async throws {
        // Given: Create test store
        let store = DataStore(testIdentifier: "navtest")

        // Create and add test medication
        let med = ANMedicationConcept(clinicalName: "Nav Test Med")
        try await store.addMedication(med)

        // Set NavigationManager state
        NavigationManager.shared.historyTargetMedicationID = med.id.uuidString
        NavigationManager.shared.historyTargetDate = Date()

        // When: Clear all data
        try await store.clearAllData()

        // Then: Verify NavigationManager state is cleared
        #expect(NavigationManager.shared.historyTargetMedicationID == nil)
        #expect(NavigationManager.shared.historyTargetDate == nil)
    }
}

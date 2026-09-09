// DataStoreTests.swift
// Comprehensive tests for DataStore operations

import ANModelKit
@testable import AsNeeded
import Boutique
import Foundation
import Testing

@Suite("DataStore Tests", .serialized, .tags(.dataStore, .persistence, .unit))
@MainActor
struct DataStoreTests {
    private var dataStore: DataStore

    init() async throws {
        // Create test instance with isolated storage
        dataStore = DataStore(testIdentifier: "DataStoreTests")
        // Clear any existing test data
        try await dataStore.clearAllData()
        // Also clear any test UserDefaults
        UserDefaults.standard.removeObject(forKey: "historySelectedMedicationID")
        UserDefaults.standard.removeObject(forKey: "trendsSelectedMedicationID")
        UserDefaults.standard.removeObject(forKey: "medicationOrder")


        // Clear NavigationManager state
        NavigationManager.shared.historyTargetMedicationID = nil
    }

    // MARK: - Medication Tests

	@Test("Current medication IDs wait for inventory readiness")
	func currentMedicationIDsWaitForInventoryReadiness() async throws {
		let medication = createTestMedication(name: "Loaded Medication")
		let readinessGate = DataStoreTestAsyncGate()
		var receivedStore: Store<ANMedicationConcept>?
		let store = DataStore(
			testIdentifier: "medication-inventory-readiness",
			medicationInventoryReadiness: { medicationsStore in
				receivedStore = medicationsStore
				await readinessGate.suspend()
			}
		)
		try await store.addMedication(medication)
		var returnedIDs: Set<UUID>?
		let inventoryTask = Task {
			returnedIDs = try await store.currentMedicationIDsWhenReady()
		}

		await readinessGate.waitUntilSuspended()

		#expect(receivedStore === store.medicationsStore)
		#expect(returnedIDs == nil)

		readinessGate.resume()
		try await inventoryTask.value

		#expect(returnedIDs == [medication.id])
	}

	@Test("Medication inventory readiness failure propagates without returning IDs")
	func medicationInventoryReadinessFailurePropagates() async throws {
		let medication = createTestMedication(name: "Unavailable Medication")
		var receivedStore: Store<ANMedicationConcept>?
		let store = DataStore(
			testIdentifier: "medication-inventory-readiness-failure",
			medicationInventoryReadiness: { medicationsStore in
				receivedStore = medicationsStore
				throw DataStoreTestError.medicationInventoryUnavailable
			}
		)
		try await store.addMedication(medication)
		var returnedIDs: Set<UUID>?

		do {
			returnedIDs = try await store.currentMedicationIDsWhenReady()
			Issue.record("Expected medication inventory readiness to fail")
		} catch {
			#expect(error as? DataStoreTestError == .medicationInventoryUnavailable)
		}

		#expect(receivedStore === store.medicationsStore)
		#expect(returnedIDs == nil)
	}

    @Test("Add medication to data store")
    func addMedication() async throws {
        // Given
        let medication = createTestMedication(name: "Test Med")

        // When
        try await dataStore.addMedication(medication)

        // Then
        #expect(dataStore.medications.count == 1)
        #expect(dataStore.medications.first?.id == medication.id)
        #expect(dataStore.medications.first?.clinicalName == "Test Med")
    }

    @Test("Update existing medication")
    func updateMedication() async throws {
        // Given
        let medication = createTestMedication(name: "Original Name")
        try await dataStore.addMedication(medication)

        // When
        var updated = medication
        updated.clinicalName = "Updated Name"
        updated.nickname = "Updated Nickname"
        try await dataStore.updateMedication(updated)

        // Then
        #expect(dataStore.medications.count == 1)
        #expect(dataStore.medications.first?.clinicalName == "Updated Name")
        #expect(dataStore.medications.first?.nickname == "Updated Nickname")
    }

    @Test("Update medication preserves existing medication order")
    func updateMedicationPreservesExistingOrder() async throws {
        // Given
        let firstMedication = createTestMedication(name: "First Med")
        let secondMedication = createTestMedication(name: "Second Med")
        try await dataStore.addMedication(firstMedication)
        try await dataStore.addMedication(secondMedication)

        // When
        var updatedFirstMedication = firstMedication
        updatedFirstMedication.quantity = 5.0
        try await dataStore.updateMedication(updatedFirstMedication)

        // Then
        #expect(dataStore.medications.map(\.id) == [firstMedication.id, secondMedication.id])
    }

    @Test("Delete medication from data store")
    func deleteMedication() async throws {
        // Given
        let medication = createTestMedication(name: "To Delete")
        try await dataStore.addMedication(medication)
        #expect(dataStore.medications.count == 1)

        // When
        try await dataStore.deleteMedication(medication)

        // Then
        #expect(dataStore.medications.count == 0)
    }

	@Test("Deleting medication removes only its urgency preference")
	func deletingMedicationRemovesOnlyItsUrgencyPreference() async throws {
		let suiteName = "DataStoreTests.deleteUrgency.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suiteName))
		defaults.removePersistentDomain(forName: suiteName)
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let urgencyStore = MedicationNotificationUrgencyStore(defaults: defaults)
		let deletedMedication = createTestMedication(name: "Urgent")
		let retainedMedication = createTestMedication(name: "Normal")
		#expect(urgencyStore.save(true, for: deletedMedication.id))
		#expect(urgencyStore.save(false, for: retainedMedication.id))
		var factoryDefaults: UserDefaults?
		var cleanupIDs: Set<UUID>?
		var deletedMedicationWasAbsentAtCleanup = false
		var store: DataStore?
		let createdStore = DataStore(
			testIdentifier: "delete-urgency",
			settingsDefaults: defaults,
			refillProfileStore: MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil),
			urgencyStoreFactory: { destination in
				factoryDefaults = destination
				return MedicationNotificationUrgencyStore(defaults: destination)
			},
			notificationArtifactCleanup: { medicationIDs in
				cleanupIDs = medicationIDs
				deletedMedicationWasAbsentAtCleanup =
					store?.medications.contains { $0.id == deletedMedication.id } == false
				for medicationID in medicationIDs {
					#expect(urgencyStore.removePreference(for: medicationID))
				}
			}
		)
		store = createdStore
		try await createdStore.addMedication(deletedMedication)
		try await createdStore.addMedication(retainedMedication)

		try await createdStore.deleteMedication(deletedMedication)

		#expect(factoryDefaults === defaults)
		#expect(cleanupIDs == [deletedMedication.id])
		#expect(deletedMedicationWasAbsentAtCleanup)
		#expect(createdStore.medications.map(\.id) == [retainedMedication.id])
		#expect(urgencyStore.preference(for: deletedMedication.id) == nil)
		#expect(urgencyStore.preference(for: retainedMedication.id) == false)
	}

	@Test("Urgency cleanup failure does not restore medication or mutate preferences")
	func urgencyCleanupFailureDoesNotRestoreMedicationOrMutatePreferences() async throws {
		let suiteName = "DataStoreTests.deleteUrgencyFailure.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suiteName))
		defaults.removePersistentDomain(forName: suiteName)
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let deletedMedication = createTestMedication(name: "Deleted")
		let retainedMedication = createTestMedication(name: "Retained")
		let writableStore = MedicationNotificationUrgencyStore(defaults: defaults)
		#expect(writableStore.save(true, for: deletedMedication.id))
		#expect(writableStore.save(false, for: retainedMedication.id))
		let priorData = try #require(defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency))
		let failingUrgencyStore = MedicationNotificationUrgencyStore(
			defaults: defaults,
			writer: { _, _, _ in }
		)
		var cleanupIDs: Set<UUID>?
		let store = DataStore(
			testIdentifier: "delete-urgency-failure",
			settingsDefaults: defaults,
			refillProfileStore: MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil),
			urgencyStoreFactory: { _ in
				failingUrgencyStore
			},
			notificationArtifactCleanup: { medicationIDs in
				cleanupIDs = medicationIDs
				for medicationID in medicationIDs {
					#expect(!failingUrgencyStore.removePreference(for: medicationID))
				}
			}
		)
		try await store.addMedication(deletedMedication)
		try await store.addMedication(retainedMedication)

		try await store.deleteMedication(deletedMedication)

		#expect(cleanupIDs == [deletedMedication.id])
		#expect(store.medications.map(\.id) == [retainedMedication.id])
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == priorData)
		#expect(writableStore.preference(for: deletedMedication.id) == true)
		#expect(writableStore.preference(for: retainedMedication.id) == false)
	}

	@Test("Clearing user data cleans all prior medication artifacts after both stores commit")
	func clearingUserDataCleansAllPriorMedicationArtifactsAfterCommit() async throws {
		let firstMedication = createTestMedication(name: "First")
		let secondMedication = createTestMedication(name: "Second")
		var cleanedMedicationIDs: Set<UUID>?
		var storesWereEmptyAtCleanup = false
		var store: DataStore?
		let createdStore = DataStore(
			testIdentifier: "clear-user-data-notifications",
			settingsDefaults: .standard,
			refillProfileStore: MedicationRefillProfileStore(),
			notificationArtifactCleanup: { medicationIDs in
				cleanedMedicationIDs = medicationIDs
				storesWereEmptyAtCleanup =
					store?.medications.isEmpty == true &&
					store?.events.isEmpty == true
			}
		)
		store = createdStore
		try await createdStore.addMedication(firstMedication)
		try await createdStore.addMedication(secondMedication)
		try await createdStore.addEvent(createTestEvent(medication: firstMedication))

		try await createdStore.clearUserData()

		#expect(cleanedMedicationIDs == [firstMedication.id, secondMedication.id])
		#expect(storesWereEmptyAtCleanup)
	}

	@Test("Clear failure after medication removal cleans absent medication artifacts and preserves the error")
	func clearFailureAfterMedicationRemovalCleansAbsentMedicationArtifacts() async throws {
		let firstMedication = createTestMedication(name: "First")
		let secondMedication = createTestMedication(name: "Second")
		var cleanedMedicationIDs: Set<UUID>?
		var stateAtCleanup: (medications: Int, events: Int)?
		var store: DataStore?
		let createdStore = DataStore(
			testIdentifier: "partial-clear-notification-cleanup",
			settingsDefaults: .standard,
			refillProfileStore: MedicationRefillProfileStore(),
			importFailureInjection: .init(
				beforeExplicitClearEvents: { throw DataStoreTestError.clearFailed }
			),
			notificationArtifactCleanup: { medicationIDs in
				cleanedMedicationIDs = medicationIDs
				stateAtCleanup = (
					medications: store?.medications.count ?? -1,
					events: store?.events.count ?? -1
				)
			}
		)
		store = createdStore
		try await createdStore.addMedication(firstMedication)
		try await createdStore.addMedication(secondMedication)
		try await createdStore.addEvent(createTestEvent(medication: firstMedication))

		await #expect(throws: DataStoreTestError.self) {
			try await createdStore.clearUserData()
		}

		#expect(createdStore.medications.isEmpty)
		#expect(createdStore.events.count == 1)
		#expect(cleanedMedicationIDs == [firstMedication.id, secondMedication.id])
		#expect(stateAtCleanup?.medications == 0)
		#expect(stateAtCleanup?.events == 1)
	}

    @Test("Delete medication with associated events removes all related data")
    func deleteMedicationWithAssociatedEvents() async throws {
        // Given
        let medication = createTestMedication(name: "Med with Events")
        try await dataStore.addMedication(medication)

        let event1 = createTestEvent(medication: medication)
        let event2 = createTestEvent(medication: medication)
        try await dataStore.addEvent(event1)
        try await dataStore.addEvent(event2)

        #expect(dataStore.events.count == 2)

        // When
        try await dataStore.deleteMedication(medication)

        // Then
        #expect(dataStore.medications.count == 0)
        #expect(dataStore.events.count == 0, "Associated events should be deleted")
    }

    @Test("Delete medication clears AppStorage selections", .disabled("Test pollution causes false failures when run in full suite - passes in isolation"))
    func deleteMedicationClearsAppStorageSelections() async throws {
        // Clean up any existing state
        UserDefaults.standard.removeObject(forKey: "historySelectedMedicationID")
        UserDefaults.standard.removeObject(forKey: "trendsSelectedMedicationID")
        UserDefaults.standard.removeObject(forKey: "medicationOrder")


        // Given
        let medication = createTestMedication(name: "Selected Med")
        try await dataStore.addMedication(medication)

        // Set the medication as selected in various AppStorage keys
        let medicationIDString = medication.id.uuidString
        UserDefaults.standard.set(medicationIDString, forKey: "historySelectedMedicationID")
        UserDefaults.standard.set(medicationIDString, forKey: "trendsSelectedMedicationID")
        UserDefaults.standard.set([medicationIDString, "other-id"], forKey: "medicationOrder")

        // Verify they were set
        #expect(UserDefaults.standard.string(forKey: "historySelectedMedicationID") == medicationIDString)
        #expect(UserDefaults.standard.string(forKey: "trendsSelectedMedicationID") == medicationIDString)
        #expect((UserDefaults.standard.array(forKey: "medicationOrder") as? [String])?.contains(medicationIDString) == true)

        // When
        try await dataStore.deleteMedication(medication)

        // Then
        #expect(UserDefaults.standard.string(forKey: "historySelectedMedicationID") == nil,
                "History selection should be cleared")
        #expect(UserDefaults.standard.string(forKey: "trendsSelectedMedicationID") == nil,
                "Trends selection should be cleared")
        #expect((UserDefaults.standard.array(forKey: "medicationOrder") as? [String])?.contains(medicationIDString) != true,
                "Medication should be removed from order array")
        #expect((UserDefaults.standard.array(forKey: "medicationOrder") as? [String])?.contains("other-id") == true,
                "Other IDs should remain in order array")
    }

    @Test("Delete medication clears navigation target")
    func deleteMedicationClearsNavigationTarget() async throws {
        // Given
        let medication = createTestMedication(name: "Nav Target Med")
        try await dataStore.addMedication(medication)

        // Set as navigation target
        NavigationManager.shared.historyTargetMedicationID = medication.id.uuidString

        // Verify it was set
        #expect(NavigationManager.shared.historyTargetMedicationID == medication.id.uuidString)

        // When
        try await dataStore.deleteMedication(medication)

        // Then
        #expect(NavigationManager.shared.historyTargetMedicationID == nil,
                "Navigation target should be cleared when medication is deleted")
    }

    // MARK: - Event Tests

    @Test("Add event to data store")
    func addEvent() async throws {
        // Given
        let medication = createTestMedication(name: "Test Med")
        try await dataStore.addMedication(medication)
        let event = createTestEvent(medication: medication)

        // When
        try await dataStore.addEvent(event)

        // Then
        #expect(dataStore.events.count == 1)
        #expect(dataStore.events.first?.id == event.id)
        #expect(dataStore.events.first?.medication?.id == medication.id)
    }

    // MARK: - Export/Import Tests

    @Test("Export data as JSON with correct structure")
    func exportDataAsJSON() async throws {
        // Given
        let med1 = createTestMedication(name: "Med 1")
        let med2 = createTestMedication(name: "Med 2")
        try await dataStore.addMedication(med1)
        try await dataStore.addMedication(med2)

        let event = createTestEvent(medication: med1)
        try await dataStore.addEvent(event)

        // When
        let exportData = try await dataStore.exportDataAsJSON()

        // Then
        #expect(exportData != nil)
        #expect(exportData.count > 0)

        // Verify JSON structure
        let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
        #expect(json != nil)
        #expect(json?["medications"] != nil)
        #expect(json?["events"] != nil)
        #expect(json?["exportDate"] != nil)
        #expect(json?["appVersion"] != nil)
    }

    @Test("Export data with name redaction enabled")
    func exportDataWithRedaction() async throws {
        // Given
        let medication = createTestMedication(name: "Sensitive Med", nickname: "Secret")
        try await dataStore.addMedication(medication)

        // When
        let exportData = try await dataStore.exportDataAsJSON(redactNames: true)

        // Then
        let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
        let medications = json?["medications"] as? [[String: Any]]
        #expect(medications != nil)
        #expect(medications?.first?["clinicalName"] as? String == "[REDACTED]")
        #expect(medications?.first?["nickname"] as? String == "[REDACTED]")
    }

    @Test("Import data from JSON restores medications and events")
    func importDataFromJSON() async throws {
        // Given - Create and export data
        let originalMed = createTestMedication(name: "Import Test")
        try await dataStore.addMedication(originalMed)
        let originalEvent = createTestEvent(medication: originalMed)
        try await dataStore.addEvent(originalEvent)

        let exportData = try await dataStore.exportDataAsJSON()

        // Clear data
        try await dataStore.clearAllData()
        #expect(dataStore.medications.count == 0)
        #expect(dataStore.events.count == 0)

        // When - Import the data back
        try await dataStore.importDataFromJSON(exportData)

        // Then
        #expect(dataStore.medications.count == 1)
        #expect(dataStore.events.count == 1)
        #expect(dataStore.medications.first?.clinicalName == "Import Test")
    }

	@Test("Import with merge combines existing and new data")
	func importWithMerge() async throws {
        // Given - Existing data
        let existingMed = createTestMedication(name: "Existing")
        try await dataStore.addMedication(existingMed)

        // Create export data with new medication
        let tempStore = DataStore(testIdentifier: "TempExport")
        let newMed = createTestMedication(name: "New Med")
        try await tempStore.addMedication(newMed)
        let exportData = try await tempStore.exportDataAsJSON()

        // When - Import with merge
        try await dataStore.importDataFromJSON(exportData, mergeExisting: true)

        // Then
        #expect(dataStore.medications.count == 2)
        #expect(dataStore.medications.contains { $0.clinicalName == "Existing" })
		#expect(dataStore.medications.contains { $0.clinicalName == "New Med" })
	}

	@Test("Replace import cleans only medications absent from committed inventory")
	func replaceImportCleansOnlyRemovedMedicationArtifacts() async throws {
		let removedMedication = createTestMedication(name: "Removed")
		let retainedMedication = createTestMedication(name: "Retained")
		let importedMedication = createTestMedication(name: "Imported")
		var cleanupCalls: [Set<UUID>] = []
		var committedMedicationIDsAtCleanup: Set<UUID>?
		var store: DataStore?
		let createdStore = DataStore(
			testIdentifier: "replace-import-notification-cleanup",
			settingsDefaults: .standard,
			refillProfileStore: MedicationRefillProfileStore(),
			notificationArtifactCleanup: { medicationIDs in
				cleanupCalls.append(medicationIDs)
				committedMedicationIDsAtCleanup = Set(store?.medications.map(\.id) ?? [])
			}
		)
		store = createdStore
		try await createdStore.addMedication(removedMedication)
		try await createdStore.addMedication(retainedMedication)
		let importData = try makeExportData(
			medications: [retainedMedication, importedMedication]
		)

		try await createdStore.importDataFromJSON(importData, mergeExisting: false)

		#expect(cleanupCalls == [[removedMedication.id]])
		#expect(committedMedicationIDsAtCleanup == [retainedMedication.id, importedMedication.id])
		#expect(Set(createdStore.medications.map(\.id)) == [retainedMedication.id, importedMedication.id])
	}

	@Test("Failed replace import rolls back without cleaning notification artifacts")
	func failedReplaceImportDoesNotCleanNotificationArtifacts() async throws {
		let existingMedication = createTestMedication(name: "Existing")
		let importedMedication = createTestMedication(name: "Imported")
		var cleanupCalls: [Set<UUID>] = []
		let store = DataStore(
			testIdentifier: "failed-replace-import-notification-cleanup",
			settingsDefaults: .standard,
			refillProfileStore: MedicationRefillProfileStore(),
			importFailureInjection: .init(
				beforeMedicationInsert: { medication in
					guard medication.id != importedMedication.id else {
						throw DataStoreTestError.importFailed
					}
				}
			),
			notificationArtifactCleanup: { cleanupCalls.append($0) }
		)
		try await store.addMedication(existingMedication)
		let importData = try makeExportData(medications: [importedMedication])

		await #expect(throws: DataStoreTestError.self) {
			try await store.importDataFromJSON(importData, mergeExisting: false)
		}

		#expect(cleanupCalls.isEmpty)
		#expect(store.medications.map(\.id) == [existingMedication.id])
	}

	@Test("Merge import never cleans existing notification artifacts")
	func mergeImportDoesNotCleanNotificationArtifacts() async throws {
		let existingMedication = createTestMedication(name: "Existing")
		let importedMedication = createTestMedication(name: "Imported")
		var cleanupCalls: [Set<UUID>] = []
		let store = DataStore(
			testIdentifier: "merge-import-notification-cleanup",
			settingsDefaults: .standard,
			refillProfileStore: MedicationRefillProfileStore(),
			notificationArtifactCleanup: { cleanupCalls.append($0) }
		)
		try await store.addMedication(existingMedication)
		let importData = try makeExportData(medications: [importedMedication])

		try await store.importDataFromJSON(importData, mergeExisting: true)

		#expect(cleanupCalls.isEmpty)
		#expect(Set(store.medications.map(\.id)) == [existingMedication.id, importedMedication.id])
	}

    // MARK: - Clear Data Tests

    @Test("Clear all data removes medications and events")
    func clearAllData() async throws {
        // Given
        let medication = createTestMedication(name: "To Clear")
        try await dataStore.addMedication(medication)
        let event = createTestEvent(medication: medication)
        try await dataStore.addEvent(event)

        #expect(dataStore.medications.count == 1)
        #expect(dataStore.events.count == 1)

        // When
        try await dataStore.clearAllData()

        // Then
        #expect(dataStore.medications.count == 0)
        #expect(dataStore.events.count == 0)
    }

    @Test("UserDefaults keys are comprehensive and up-to-date")
    func userDefaultsKeysComprehensive() {
        // This test ensures our constants file stays up-to-date
        // If you add a new @AppStorage property, this test reminds you to update UserDefaultsKeys

        let allKeys = UserDefaultsKeys.allKeys
        let defaultValues = UserDefaultsKeys.defaultValues
        let keysToRemove = UserDefaultsKeys.keysToRemove
        let keysToSkip = UserDefaultsKeys.keysToSkip

        // Verify all keys are accounted for
        for key in allKeys {
            let hasDefault = defaultValues.keys.contains(key)
            let shouldRemove = keysToRemove.contains(key)
            let shouldSkip = keysToSkip.contains(key)

            #expect(hasDefault || shouldRemove || shouldSkip,
                    "Key '\(key)' must either have a default value, be in keysToRemove, or be in keysToSkip")

            // Verify no key is in multiple categories
            let categories = [hasDefault, shouldRemove, shouldSkip].filter { $0 }.count
            #expect(categories == 1,
                    "Key '\(key)' must be in exactly one category, but is in \(categories)")
        }

        // Verify no keys are duplicated
        let uniqueKeys = Set(allKeys)
        #expect(uniqueKeys.count == allKeys.count, "allKeys contains duplicate entries")

        // Verify expected keys are present (spot check important ones)
        #expect(allKeys.contains(UserDefaultsKeys.hasSeenWelcome))
        #expect(allKeys.contains(UserDefaultsKeys.hapticsEnabled))
        #expect(allKeys.contains(UserDefaultsKeys.medicationOrder))
        #expect(allKeys.contains(UserDefaultsKeys.selectedTab))
		#expect(allKeys.contains(UserDefaultsKeys.medicationRefillProfiles))
		#expect(allKeys.contains(UserDefaultsKeys.legacyMedicationProfiles))
		#expect(allKeys.contains(UserDefaultsKeys.archivedMedicationProfiles))
		#expect(allKeys.contains(UserDefaultsKeys.medicationProfilesMigrationCompleted))
		#expect(allKeys.contains(UserDefaultsKeys.medicationNotificationUrgency))
		#expect(allKeys.contains(UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted))

		#expect(UserDefaultsKeys.safeToExportKeys.contains(UserDefaultsKeys.medicationRefillProfiles))
		#expect(UserDefaultsKeys.safeToExportKeys.contains(UserDefaultsKeys.medicationNotificationUrgency))
		#expect(!UserDefaultsKeys.safeToExportKeys.contains(UserDefaultsKeys.legacyMedicationProfiles))
		#expect(!UserDefaultsKeys.safeToExportKeys.contains(UserDefaultsKeys.archivedMedicationProfiles))
		#expect(!UserDefaultsKeys.safeToExportKeys.contains(UserDefaultsKeys.medicationProfilesMigrationCompleted))
		#expect(!UserDefaultsKeys.safeToExportKeys.contains(UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted))
		#expect(!UserDefaultsKeys.safeToExportKeys.contains(UserDefaultsKeys.importSettingsDefaultBehavior))
		#expect(UserDefaultsKeys.keysToRemove.contains(UserDefaultsKeys.medicationNotificationUrgency))
		#expect(UserDefaultsKeys.keysToSkip.contains(UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted))
		#expect(UserDefaultsKeys.keysToNeverExport.contains(UserDefaultsKeys.legacyMedicationProfiles))
		#expect(UserDefaultsKeys.keysToNeverExport.contains(UserDefaultsKeys.archivedMedicationProfiles))
		#expect(UserDefaultsKeys.keysToNeverExport.contains(UserDefaultsKeys.medicationProfilesMigrationCompleted))
		#expect(UserDefaultsKeys.keysToNeverExport.contains(UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted))
		#expect(UserDefaultsKeys.keysToNeverExport.contains(UserDefaultsKeys.importSettingsDefaultBehavior))
		#expect(UserDefaultsKeys.safeToExportKeys.isDisjoint(with: UserDefaultsKeys.keysToNeverExport))
		#expect(
			UserDefaultsKeys.safeToExportKeys.union(UserDefaultsKeys.keysToNeverExport) == Set(allKeys),
			"Every registered key must be classified as safe or forbidden for export"
		)
    }

    // MARK: - Performance Tests

    @Test("Bulk operations complete within performance threshold")
    func bulkOperationsPerformance() async throws {
        // Measure bulk insert performance
        let medications = (0 ..< 100).map { i in
            createTestMedication(name: "Med \(i)")
        }

        let startTime = Date()

        for medication in medications {
            try await dataStore.addMedication(medication)
        }

        let elapsed = Date().timeIntervalSince(startTime)

        #expect(dataStore.medications.count == 100)
        #expect(elapsed < 5.0, "Bulk insert should complete within 5 seconds")
    }

    // MARK: - Helper Methods

    private func createTestMedication(name: String, nickname: String? = nil) -> ANMedicationConcept {
        return ANMedicationConcept(
            clinicalName: name,
            nickname: nickname,
            quantity: nil,
            initialQuantity: 30.0,
            prescribedUnit: .milligram,
            prescribedDoseAmount: 10.0
        )
    }

	private func makeExportData(
		medications: [ANMedicationConcept],
		events: [ANEventConcept] = []
	) throws -> Data {
		let export = DataExport(
			medications: medications,
			events: events,
			exportDate: Date(timeIntervalSince1970: 1_700_000_000),
			appVersion: "1.0",
			dataVersion: "1.0",
			settings: nil
		)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return try encoder.encode(export)
	}

    private func createTestEvent(medication: ANMedicationConcept) -> ANEventConcept {
        return ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: ANDoseConcept(amount: 10.0, unit: .milligram),
            date: Date()
        )
    }
}

@MainActor
private final class DataStoreTestAsyncGate {
	private let arrived = DataStoreTestAsyncSignal()
	private let released = DataStoreTestAsyncSignal()

	func suspend() async {
		arrived.signal()
		await released.wait()
	}

	func waitUntilSuspended() async {
		await arrived.wait()
	}

	func resume() {
		released.signal()
	}
}

@MainActor
private final class DataStoreTestAsyncSignal {
	private let stream: AsyncStream<Void>
	private let continuation: AsyncStream<Void>.Continuation

	init() {
		(stream, continuation) = AsyncStream.makeStream()
	}

	func signal() {
		continuation.yield()
		continuation.finish()
	}

	func wait() async {
		for await _ in stream {
			return
		}
	}
}

private enum DataStoreTestError: Error, Equatable {
	case clearFailed
	case importFailed
	case medicationInventoryUnavailable
}

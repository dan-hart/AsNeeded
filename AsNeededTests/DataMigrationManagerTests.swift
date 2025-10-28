// DataMigrationManagerTests.swift
// Comprehensive tests for DataMigrationManager operations

import ANModelKit
@testable import AsNeeded
import Boutique
import Foundation
import Testing

@Suite("DataMigrationManager Tests", .tags(.migration, .persistence, .unit))
@MainActor
struct DataMigrationManagerTests {
	private var migrationManager: DataMigrationManager

	init() async throws {
		// Create migration manager instance
		migrationManager = DataMigrationManager()

		// Reset migration flag for testing
		migrationManager.resetMigrationFlagForTesting()
	}

	// MARK: - Migration Flag Tests

	@Test("Migration flag starts as false")
	func migrationFlagInitialState() async throws {
		// Given - fresh migration manager
		migrationManager.resetMigrationFlagForTesting()

		// Then
		let isCompleted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.dataMigrationCompleted)
		#expect(isCompleted == false)
	}

	@Test("Migration flag is set after migration")
	func migrationFlagSetAfterMigration() async throws {
		// Given - no legacy data exists
		migrationManager.resetMigrationFlagForTesting()

		// When
		await migrationManager.migrateIfNeeded()

		// Then
		let isCompleted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.dataMigrationCompleted)
		#expect(isCompleted == true)
	}

	@Test("Migration skipped when flag is already set")
	func migrationSkippedWhenAlreadyCompleted() async throws {
		// Given - migration already completed
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.dataMigrationCompleted)

		// When
		await migrationManager.migrateIfNeeded()

		// Then - should complete without error
		let isCompleted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.dataMigrationCompleted)
		#expect(isCompleted == true)
	}

	// MARK: - Fresh Install Tests

	@Test("Fresh install with no legacy data")
	func freshInstallNoLegacyData() async throws {
		// Given - no legacy data, no current data
		migrationManager.resetMigrationFlagForTesting()
		cleanupTestDatabases()

		// When
		await migrationManager.migrateIfNeeded()

		// Then - migration should complete and mark as done
		let isCompleted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.dataMigrationCompleted)
		#expect(isCompleted == true)
	}

	// MARK: - Data Merge Tests

	@Test("Merge data from legacy and current locations")
	func mergeDataFromBothLocations() async throws {
		// Given
		migrationManager.resetMigrationFlagForTesting()

		// Create legacy data
		let legacyStore = createLegacyStore()
		let legacyMedication = createTestMedication(name: "Legacy Med")
		try await legacyStore.insert(legacyMedication)

		// Create current data in App Group
		let currentStore = createAppGroupStore()
		let currentMedication = createTestMedication(name: "Current Med")
		try await currentStore.insert(currentMedication)

		// When
		await migrationManager.migrateIfNeeded()

		// Then - both medications should exist in App Group
		let appGroupStore = createAppGroupStore()
		#expect(appGroupStore.items.count == 2)

		let medicationNames = Set(appGroupStore.items.map { $0.clinicalName })
		#expect(medicationNames.contains("Legacy Med"))
		#expect(medicationNames.contains("Current Med"))

		// Cleanup
		try await appGroupStore.removeAll()
		try await legacyStore.removeAll()
	}

	@Test("Duplicate medications are handled by merge logic")
	func duplicateIDsHandledCorrectly() async throws {
		// Given
		migrationManager.resetMigrationFlagForTesting()

		// Create same medication in both locations
		let medication = createTestMedication(name: "Test Medication")

		let legacyStore = createLegacyStore()
		try await legacyStore.insert(medication)

		let currentStore = createAppGroupStore()
		try await currentStore.insert(medication)

		// When
		await migrationManager.migrateIfNeeded()

		// Then - only one instance should exist (deduplicated by ID)
		let appGroupStore = createAppGroupStore()
		#expect(appGroupStore.items.count == 1)
		#expect(appGroupStore.items.first?.clinicalName == "Test Medication")

		// Cleanup
		try await appGroupStore.removeAll()
		try await legacyStore.removeAll()
	}

	// MARK: - Idempotency Tests

	@Test("Running migration multiple times produces same result")
	func migrationIdempotency() async throws {
		// Given
		migrationManager.resetMigrationFlagForTesting()

		let legacyStore = createLegacyStore()
		let medication = createTestMedication(name: "Test Med")
		try await legacyStore.insert(medication)

		// When - run migration twice
		await migrationManager.migrateIfNeeded()

		// Reset flag to force re-run
		migrationManager.resetMigrationFlagForTesting()
		await migrationManager.migrateIfNeeded()

		// Then - should have exactly one medication (no duplicates)
		let appGroupStore = createAppGroupStore()
		#expect(appGroupStore.items.count == 1)
		#expect(appGroupStore.items.first?.clinicalName == "Test Med")

		// Cleanup
		try await appGroupStore.removeAll()
		try await legacyStore.removeAll()
	}

	// MARK: - Large Dataset Tests

	@Test("Migration handles large datasets")
	func migrationHandlesLargeDatasets() async throws {
		// Given
		migrationManager.resetMigrationFlagForTesting()

		let legacyStore = createLegacyStore()

		// Create 100 medications
		for i in 1...100 {
			let medication = createTestMedication(name: "Medication \(i)")
			try await legacyStore.insert(medication)
		}

		// When
		await migrationManager.migrateIfNeeded()

		// Then
		let appGroupStore = createAppGroupStore()
		#expect(appGroupStore.items.count == 100)

		// Cleanup
		try await appGroupStore.removeAll()
		try await legacyStore.removeAll()
	}

	// MARK: - UserDefaults Key Configuration Tests

	@Test("Migration key is in allKeys array")
	func migrationKeyInAllKeys() {
		#expect(UserDefaultsKeys.allKeys.contains(UserDefaultsKeys.dataMigrationCompleted))
	}

	@Test("Migration key is in keysToSkip set")
	func migrationKeyInKeysToSkip() {
		#expect(UserDefaultsKeys.keysToSkip.contains(UserDefaultsKeys.dataMigrationCompleted))
	}

	@Test("Migration key is in keysToNeverExport set")
	func migrationKeyInKeysToNeverExport() {
		#expect(UserDefaultsKeys.keysToNeverExport.contains(UserDefaultsKeys.dataMigrationCompleted))
	}

	@Test("Migration key is NOT in safeToExport set")
	func migrationKeyNotInSafeToExport() {
		#expect(!UserDefaultsKeys.safeToExportKeys.contains(UserDefaultsKeys.dataMigrationCompleted))
	}

	// MARK: - Helper Methods

	/// Creates a test medication with given name
	private func createTestMedication(name: String, nickname: String? = nil) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: name,
			nickname: nickname,
			quantity: nil,
			initialQuantity: 30.0,
			prescribedUnit: .milligram,
			prescribedDoseAmount: 10.0
		)
	}

	/// Creates a legacy store (default app container)
	private func createLegacyStore() -> Store<ANMedicationConcept> {
		Store<ANMedicationConcept>(
			storage: SQLiteStorageEngine.default(appendingPath: "test_legacy_medications"),
			cacheIdentifier: \ANMedicationConcept.id.uuidString
		)
	}

	/// Creates an App Group store
	private func createAppGroupStore() -> Store<ANMedicationConcept> {
		guard let sharedContainerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: "group.com.codedbydan.AsNeeded"
		) else {
			fatalError("Unable to access App Group container for testing")
		}

		return Store<ANMedicationConcept>(
			storage: SQLiteStorageEngine(
				directory: FileManager.Directory(url: sharedContainerURL),
				databaseFilename: "test_migration_medications"
			)!,
			cacheIdentifier: \ANMedicationConcept.id.uuidString
		)
	}

	/// Cleans up all test databases
	private func cleanupTestDatabases() {
		let fileManager = FileManager.default

		// Clean legacy location
		if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
			let legacyFiles = [
				"test_legacy_medications.sqlite",
				"test_legacy_medications.sqlite-wal",
				"test_legacy_medications.sqlite-shm",
			]

			for filename in legacyFiles {
				let fileURL = appSupportURL.appendingPathComponent(filename)
				try? fileManager.removeItem(at: fileURL)
			}
		}

		// Clean App Group location
		if let sharedContainerURL = fileManager.containerURL(
			forSecurityApplicationGroupIdentifier: "group.com.codedbydan.AsNeeded"
		) {
			let appGroupFiles = [
				"test_migration_medications.sqlite",
				"test_migration_medications.sqlite-wal",
				"test_migration_medications.sqlite-shm",
			]

			for filename in appGroupFiles {
				let fileURL = sharedContainerURL.appendingPathComponent(filename)
				try? fileManager.removeItem(at: fileURL)
			}
		}
	}
}

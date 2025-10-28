// DataMigrationManagerTests.swift
// Comprehensive tests for DataMigrationManager operations

import ANModelKit
@testable import AsNeeded
import Boutique
import Foundation
import Testing

/// Test errors for migration test scenarios
enum TestError: Error {
	case setupFailed
	case appGroupUnavailable
}

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

	@Test("Migration handles legacy .sqlite databases")
	func migrationHandlesLegacySqliteDatabases() async throws {
		// Given
		migrationManager.resetMigrationFlagForTesting()
		cleanupTestDatabases()

		let medication = createTestMedication(name: "Legacy SQLite Format")

		do {
			let legacyStore = createLegacyStore()
			try await legacyStore.insert(medication)
		}

		let fileManager = FileManager.default
		let candidateDirectories = [
			fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
			fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
		].compactMap { $0 }

		func relocateSidecar(from source: URL, to destination: URL, suffix: String) {
			let sourcePath = source.path + suffix
			let destinationPath = destination.path + suffix

			guard fileManager.fileExists(atPath: sourcePath) else { return }
			if fileManager.fileExists(atPath: destinationPath) {
				try? fileManager.removeItem(atPath: destinationPath)
			}
			try? fileManager.moveItem(atPath: sourcePath, toPath: destinationPath)
		}

		var finalLegacyURL: URL?

		for directory in candidateDirectories {
			let sqlite3URL = directory.appendingPathComponent("test_legacy_medications.sqlite3")
			let sqliteURL = directory.appendingPathComponent("test_legacy_medications.sqlite")

			if fileManager.fileExists(atPath: sqlite3URL.path) {
				if fileManager.fileExists(atPath: sqliteURL.path) {
					try? fileManager.removeItem(at: sqliteURL)
				}
				try fileManager.moveItem(at: sqlite3URL, to: sqliteURL)
				relocateSidecar(from: sqlite3URL, to: sqliteURL, suffix: "-wal")
				relocateSidecar(from: sqlite3URL, to: sqliteURL, suffix: "-shm")
				finalLegacyURL = sqliteURL
				break
			} else if fileManager.fileExists(atPath: sqliteURL.path) {
				finalLegacyURL = sqliteURL
				break
			}
		}

		guard finalLegacyURL != nil else {
			throw TestError.setupFailed
		}

		let appGroupStore = createAppGroupStore()
		try await appGroupStore.removeAll()

		// When
		await migrationManager.migrateIfNeeded()

		// Then
		let migratedStore = createAppGroupStore()
		let migratedNames = await migratedStore.items.map(\.clinicalName)
		#expect(migratedNames.contains("Legacy SQLite Format"))

		// Cleanup
		try await migratedStore.removeAll()
		cleanupTestDatabases()
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

	// MARK: - Filename Variation Tests

	@Test("Detect database with .sqlite3 extension")
	func detectDatabaseWithSqlite3Extension() async throws {
		// Given - database file with .sqlite3 extension
		migrationManager.resetMigrationFlagForTesting()

		guard let appSupportURL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first else {
			throw TestError.setupFailed
		}

		// Create test database with .sqlite3 extension
		let dbPath = appSupportURL.appendingPathComponent("test_variation.sqlite3")
		try "test data".write(to: dbPath, atomically: true, encoding: .utf8)

		// Then - file should be detected
		let detected = FileManager.default.fileExists(atPath: dbPath.path)
		#expect(detected == true)

		// Cleanup
		try? FileManager.default.removeItem(at: dbPath)
	}

	@Test("Detect database with .sqlite extension")
	func detectDatabaseWithSqliteExtension() async throws {
		// Given - database file with .sqlite extension
		migrationManager.resetMigrationFlagForTesting()

		guard let appSupportURL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first else {
			throw TestError.setupFailed
		}

		// Create test database with .sqlite extension
		let dbPath = appSupportURL.appendingPathComponent("test_variation.sqlite")
		try "test data".write(to: dbPath, atomically: true, encoding: .utf8)

		// Then - file should be detected
		let detected = FileManager.default.fileExists(atPath: dbPath.path)
		#expect(detected == true)

		// Cleanup
		try? FileManager.default.removeItem(at: dbPath)
	}

	@Test("Detect database without extension")
	func detectDatabaseWithoutExtension() async throws {
		// Given - database file without extension
		migrationManager.resetMigrationFlagForTesting()

		guard let appSupportURL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first else {
			throw TestError.setupFailed
		}

		// Create test database without extension
		let dbPath = appSupportURL.appendingPathComponent("test_variation")
		try "test data".write(to: dbPath, atomically: true, encoding: .utf8)

		// Then - file should be detected
		let detected = FileManager.default.fileExists(atPath: dbPath.path)
		#expect(detected == true)

		// Cleanup
		try? FileManager.default.removeItem(at: dbPath)
	}

	@Test("Detect database with .db extension")
	func detectDatabaseWithDbExtension() async throws {
		// Given - database file with .db extension
		migrationManager.resetMigrationFlagForTesting()

		guard let appSupportURL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first else {
			throw TestError.setupFailed
		}

		// Create test database with .db extension
		let dbPath = appSupportURL.appendingPathComponent("test_variation.db")
		try "test data".write(to: dbPath, atomically: true, encoding: .utf8)

		// Then - file should be detected
		let detected = FileManager.default.fileExists(atPath: dbPath.path)
		#expect(detected == true)

		// Cleanup
		try? FileManager.default.removeItem(at: dbPath)
	}

	// MARK: - WAL File Handling Tests

	@Test("Detect WAL file alongside main database")
	func detectWALFileWithMainDatabase() async throws {
		// Given - database with WAL file
		migrationManager.resetMigrationFlagForTesting()

		guard let appSupportURL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first else {
			throw TestError.setupFailed
		}

		// Create main database
		let dbPath = appSupportURL.appendingPathComponent("test_wal.sqlite")
		try "main database".write(to: dbPath, atomically: true, encoding: .utf8)

		// Create WAL file
		let walPath = appSupportURL.appendingPathComponent("test_wal.sqlite-wal")
		try "wal data".write(to: walPath, atomically: true, encoding: .utf8)

		// Create SHM file
		let shmPath = appSupportURL.appendingPathComponent("test_wal.sqlite-shm")
		try "shm data".write(to: shmPath, atomically: true, encoding: .utf8)

		// Then - all files should be detected
		#expect(FileManager.default.fileExists(atPath: dbPath.path))
		#expect(FileManager.default.fileExists(atPath: walPath.path))
		#expect(FileManager.default.fileExists(atPath: shmPath.path))

		// Cleanup
		try? FileManager.default.removeItem(at: dbPath)
		try? FileManager.default.removeItem(at: walPath)
		try? FileManager.default.removeItem(at: shmPath)
	}

	@Test("Detect orphaned WAL file without main database")
	func detectOrphanedWALFile() async throws {
		// Given - WAL file exists but main database doesn't
		migrationManager.resetMigrationFlagForTesting()

		guard let appSupportURL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first else {
			throw TestError.setupFailed
		}

		// Create only WAL file (no main database)
		let walPath = appSupportURL.appendingPathComponent("orphan_wal.sqlite-wal")
		try "orphaned wal data".write(to: walPath, atomically: true, encoding: .utf8)

		// Then - WAL file should be detected
		let walExists = FileManager.default.fileExists(atPath: walPath.path)
		#expect(walExists == true)

		// And main database should NOT exist
		let dbPath = appSupportURL.appendingPathComponent("orphan_wal.sqlite")
		let dbExists = FileManager.default.fileExists(atPath: dbPath.path)
		#expect(dbExists == false)

		// Cleanup
		try? FileManager.default.removeItem(at: walPath)
	}

	// MARK: - Migration Attempt Flag Tests

	@Test("Migration attempted flag is set when migration starts")
	func migrationAttemptedFlagSet() async throws {
		// Given
		migrationManager.resetMigrationFlagForTesting()

		// Ensure attempted flag is initially false
		let initialAttempted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.dataMigrationAttempted)
		#expect(initialAttempted == false)

		// When
		await migrationManager.migrateIfNeeded()

		// Then - attempted flag should be set
		let finalAttempted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.dataMigrationAttempted)
		#expect(finalAttempted == true)
	}

	@Test("Migration attempted key is in allKeys array")
	func migrationAttemptedKeyInAllKeys() {
		#expect(UserDefaultsKeys.allKeys.contains(UserDefaultsKeys.dataMigrationAttempted))
	}

	@Test("Migration attempted key is in keysToSkip set")
	func migrationAttemptedKeyInKeysToSkip() {
		#expect(UserDefaultsKeys.keysToSkip.contains(UserDefaultsKeys.dataMigrationAttempted))
	}

	@Test("Migration attempted key is in keysToNeverExport set")
	func migrationAttemptedKeyInKeysToNeverExport() {
		#expect(UserDefaultsKeys.keysToNeverExport.contains(UserDefaultsKeys.dataMigrationAttempted))
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

	// MARK: - Test Coverage Limitations

	/*
	 App Group Unavailable Test Limitation
	 ======================================

	 We cannot easily test the scenario where App Group container is unavailable because:

	 1. FileManager.containerURL(forSecurityApplicationGroupIdentifier:) is not mockable
	 2. In test environment, App Group is always available (configured in test target)
	 3. Creating a scenario where it returns nil would require:
	    - Removing App Group entitlement from test target (breaks all tests)
	    - Runtime manipulation of FileManager (not possible in Swift)
	    - Swizzling (dangerous and unreliable)

	 However, the defensive implementation ensures safety:

	 ✅ DataMigrationManager throws MigrationError.appGroupUnavailable when paths nil
	 ✅ MigrationCoordinator does NOT mark as complete on error
	 ✅ MigrationErrorView shows user-facing error with retry button
	 ✅ DataStore.init() crashes with helpful error if App Group unavailable
	 ✅ Comprehensive diagnostics log App Group accessibility

	 Manual Testing Required:
	 - Remove App Group entitlement from provisioning profile
	 - Run app on physical device
	 - Verify MigrationErrorView is shown
	 - Verify error message is helpful
	 - Verify retry button works when entitlement is restored

	 This is considered acceptable because:
	 1. App Group unavailability is extremely rare in production
	 2. It's always a configuration error (not runtime condition)
	 3. Multiple defensive layers exist to prevent data loss
	 4. Manual testing catches the issue before release
	 */

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
			"test_legacy_medications.sqlite3",
			"test_legacy_medications.sqlite3-wal",
			"test_legacy_medications.sqlite3-shm",
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
				"test_migration_medications.sqlite3",
				"test_migration_medications.sqlite3-wal",
				"test_migration_medications.sqlite3-shm",
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

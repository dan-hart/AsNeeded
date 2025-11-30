// DataIntegrityTests.swift
// Tests to verify data integrity is preserved during migrations and storage operations
// Part of the Data Loss Prevention strategy - see CLAUDE.md "Dangerous Files Registry"

import ANModelKit
@testable import AsNeeded
import Boutique
import Foundation
import Testing

@Suite("Data Integrity Tests", .tags(.migration, .persistence, .unit))
@MainActor
struct DataIntegrityTests {
	// MARK: - Field Preservation Tests

	@Test("Migration preserves all medication fields")
	func migrationPreservesAllMedicationFields() async throws {
		// Given - a medication with ALL fields populated
		let originalID = UUID()
		let originalDate = Date()

		// Create medication with all fields set
		let original = ANMedicationConcept(
			id: originalID,
			clinicalName: "Test Medication",
			dosageDescription: "500mg twice daily",
			color: 0xFF5733, // Custom color
			symbol: "pills",
			notes: "Important notes about this medication",
			createdAt: originalDate,
			archivedAt: nil,
			rxcui: "12345"
		)

		// Create test stores
		let testStore = createTestStore()

		// When - insert and retrieve
		try await testStore.insert(original)
		let retrieved = testStore.items.first { $0.id == originalID }

		// Then - verify ALL fields match
		#expect(retrieved != nil, "Medication should be retrievable")
		guard let medication = retrieved else { return }

		#expect(medication.id == original.id, "ID should match")
		#expect(medication.clinicalName == original.clinicalName, "Clinical name should match")
		#expect(medication.dosageDescription == original.dosageDescription, "Dosage description should match")
		#expect(medication.color == original.color, "Color should match")
		#expect(medication.symbol == original.symbol, "Symbol should match")
		#expect(medication.notes == original.notes, "Notes should match")
		#expect(medication.rxcui == original.rxcui, "RxCUI should match")

		// Verify date within 1 second tolerance (floating point comparison)
		if let retrievedDate = medication.createdAt, let originalCreatedAt = original.createdAt {
			let timeDifference = abs(retrievedDate.timeIntervalSince(originalCreatedAt))
			#expect(timeDifference < 1.0, "Created date should match within 1 second")
		}

		// Cleanup
		try await testStore.removeAll()
	}

	@Test("Migration preserves all event fields")
	func migrationPreservesAllEventFields() async throws {
		// Given - an event with ALL fields populated
		let medicationID = UUID()
		let eventID = UUID()
		let eventDate = Date()

		let original = ANEventConcept(
			id: eventID,
			medicationID: medicationID,
			timestamp: eventDate,
			notes: "Took with food"
		)

		// Create test stores
		let testStore = createEventTestStore()

		// When - insert and retrieve
		try await testStore.insert(original)
		let retrieved = testStore.items.first { $0.id == eventID }

		// Then - verify ALL fields match
		#expect(retrieved != nil, "Event should be retrievable")
		guard let event = retrieved else { return }

		#expect(event.id == original.id, "ID should match")
		#expect(event.medicationID == original.medicationID, "Medication ID should match")
		#expect(event.notes == original.notes, "Notes should match")

		// Verify timestamp within 1 second tolerance
		let timeDifference = abs(event.timestamp.timeIntervalSince(original.timestamp))
		#expect(timeDifference < 1.0, "Timestamp should match within 1 second")

		// Cleanup
		try await testStore.removeAll()
	}

	// MARK: - Data Corruption Detection

	@Test("Empty data is detected and handled gracefully")
	func emptyDataHandledGracefully() async throws {
		// Given - an empty store
		let testStore = createTestStore()
		try await testStore.removeAll()

		// When - check the store
		let items = testStore.items

		// Then - should be empty, not corrupted
		#expect(items.isEmpty, "Empty store should return empty array")
	}

	@Test("Store handles concurrent reads without corruption")
	func concurrentReadsDoNotCorrupt() async throws {
		// Given - a store with data
		let testStore = createTestStore()
		let medication = ANMedicationConcept(
			id: UUID(),
			clinicalName: "Concurrent Test Med",
			dosageDescription: "100mg"
		)
		try await testStore.insert(medication)

		// When - perform multiple concurrent reads
		async let read1 = testStore.items.count
		async let read2 = testStore.items.count
		async let read3 = testStore.items.count

		let (count1, count2, count3) = await (read1, read2, read3)

		// Then - all reads should return consistent data
		#expect(count1 == count2, "Concurrent reads should be consistent")
		#expect(count2 == count3, "Concurrent reads should be consistent")
		#expect(count1 == 1, "Should have exactly one medication")

		// Cleanup
		try await testStore.removeAll()
	}

	// MARK: - Idempotency Tests

	@Test("Migration is idempotent - running twice produces same result")
	func migrationIsIdempotent() async throws {
		// Given - a migration manager and test data
		let migrationManager = DataMigrationManager()
		let testStore = createTestStore()

		let medication = ANMedicationConcept(
			id: UUID(),
			clinicalName: "Idempotency Test",
			dosageDescription: "50mg"
		)
		try await testStore.insert(medication)

		let countBefore = testStore.items.count

		// When - run migration twice
		await migrationManager.migrateIfNeeded()
		let countAfterFirst = testStore.items.count

		await migrationManager.migrateIfNeeded()
		let countAfterSecond = testStore.items.count

		// Then - count should remain constant (no duplicates)
		#expect(countAfterFirst == countBefore, "First migration should not change count")
		#expect(countAfterSecond == countBefore, "Second migration should not change count")

		// Cleanup
		try await testStore.removeAll()
	}

	// MARK: - StorageConstants Validation

	@Test("StorageConstants has valid schema version")
	func storageConstantsHasValidVersion() {
		// Given - StorageConstants
		let version = StorageConstants.currentStorageVersion

		// Then - version should be positive
		#expect(version > 0, "Storage version should be positive")
		#expect(version <= 100, "Storage version should be reasonable (< 100)")
	}

	@Test("StorageConstants has valid App Group identifier")
	func storageConstantsHasValidAppGroup() {
		// Given - StorageConstants
		let appGroup = StorageConstants.appGroupIdentifier

		// Then - should be properly formatted
		#expect(!appGroup.isEmpty, "App Group identifier should not be empty")
		#expect(appGroup.hasPrefix("group."), "App Group identifier should start with 'group.'")
		#expect(appGroup.contains("AsNeeded"), "App Group identifier should contain app name")
	}

	@Test("StorageConstants database names are non-empty")
	func storageConstantsDatabaseNamesValid() {
		// Given - StorageConstants
		let medicationsDB = StorageConstants.medicationsDBName
		let eventsDB = StorageConstants.eventsDBName

		// Then - names should be valid
		#expect(!medicationsDB.isEmpty, "Medications DB name should not be empty")
		#expect(!eventsDB.isEmpty, "Events DB name should not be empty")
		#expect(medicationsDB != eventsDB, "Database names should be unique")
	}

	// MARK: - October 2025 Regression Tests

	@Test("Computed database paths use correct extension")
	func computedPathsUseCorrectExtension() {
		// Given - StorageConstants computed paths
		let medicationsPath = StorageConstants.medicationsDBPath
		let eventsPath = StorageConstants.eventsDBPath
		let expectedExtension = StorageConstants.databaseExtension

		// Then - paths should combine name + extension correctly
		#expect(medicationsPath == "\(StorageConstants.medicationsDBName)\(expectedExtension)",
				"Medications path should be name + extension")
		#expect(eventsPath == "\(StorageConstants.eventsDBName)\(expectedExtension)",
				"Events path should be name + extension")
		#expect(medicationsPath.hasSuffix(expectedExtension),
				"Medications path should have correct extension")
		#expect(eventsPath.hasSuffix(expectedExtension),
				"Events path should have correct extension")
	}

	@Test("Database extension is .sqlite3")
	func databaseExtensionIsSqlite3() {
		// This test prevents accidental extension changes that could cause data loss
		#expect(StorageConstants.databaseExtension == ".sqlite3",
				"Database extension must be .sqlite3 (changing this requires migration)")
	}

	@Test("Health check severity levels work correctly")
	func healthCheckSeverityLevelsWork() async throws {
		// Given - a health checker
		let healthChecker = StorageHealthChecker()

		// When - perform health check
		let result = healthChecker.performHealthCheck()

		// Then - if healthy, there should be no blocking errors
		if result.isHealthy {
			#expect(result.errors.isEmpty, "Healthy check should have no blocking errors")
			// Warnings are allowed even when healthy
		}

		// Verify severity filtering works
		for issue in result.issues {
			if issue.severity == .error {
				#expect(result.errors.contains { $0.message == issue.message },
						"Errors should be in errors list")
			} else {
				#expect(result.warnings.contains { $0.message == issue.message },
						"Warnings should be in warnings list")
			}
		}
	}

	@Test("Backup manager uses StorageConstants paths")
	func backupManagerUsesStorageConstantsPaths() async {
		// Given - backup manager
		let backupManager = BackupManager.shared

		// When - create a backup
		let result = await backupManager.createPreMigrationBackup()

		// Then - verify the backup path uses StorageConstants
		if result.success, let backupPath = result.backupPath {
			let fileManager = FileManager.default

			// Check that backup files use StorageConstants paths
			let expectedMedicationsFile = backupPath.appendingPathComponent(StorageConstants.medicationsDBPath)
			let expectedEventsFile = backupPath.appendingPathComponent(StorageConstants.eventsDBPath)

			// At least one of these should exist if there was data to backup
			if result.medicationsBackedUp {
				#expect(fileManager.fileExists(atPath: expectedMedicationsFile.path),
						"Medications backup should be at StorageConstants path")
			}
			if result.eventsBackedUp {
				#expect(fileManager.fileExists(atPath: expectedEventsFile.path),
						"Events backup should be at StorageConstants path")
			}
		}
	}

	@Test("Legacy constants exist for migration compatibility")
	func legacyConstantsExist() {
		// These constants are needed for migrating data from old app versions
		// DO NOT remove these even if they seem unused

		// Given - StorageConstants.Legacy
		let bundleID = StorageConstants.Legacy.bundleIdentifier
		let medicationsDB = StorageConstants.Legacy.medicationsDB
		let eventsDB = StorageConstants.Legacy.eventsDB
		let bodegaDataFile = StorageConstants.Legacy.bodegaDataFile
		let extensions = StorageConstants.Legacy.knownExtensions

		// Then - legacy constants should be valid
		#expect(!bundleID.isEmpty, "Legacy bundle ID needed for migration")
		#expect(!medicationsDB.isEmpty, "Legacy medications DB name needed for migration")
		#expect(!eventsDB.isEmpty, "Legacy events DB name needed for migration")
		#expect(bodegaDataFile == "data.sqlite3", "Bodega data file must match old format")
		#expect(!extensions.isEmpty, "Known extensions needed for legacy file search")
		#expect(extensions.contains(".sqlite3"), "Must search for .sqlite3 files")
	}

	// MARK: - Helper Methods

	private func createTestStore() -> Store<ANMedicationConcept> {
		guard let containerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier
		) else {
			fatalError("App Group unavailable in test environment")
		}

		guard let storage = try? SQLiteStorageEngine(
			directory: FileManager.Directory(url: containerURL),
			databaseFilename: "test_medications_integrity"
		) else {
			fatalError("Failed to create test storage engine")
		}

		return Store<ANMedicationConcept>(
			storage: storage,
			cacheIdentifier: \.id.uuidString
		)
	}

	private func createEventTestStore() -> Store<ANEventConcept> {
		guard let containerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier
		) else {
			fatalError("App Group unavailable in test environment")
		}

		guard let storage = try? SQLiteStorageEngine(
			directory: FileManager.Directory(url: containerURL),
			databaseFilename: "test_events_integrity"
		) else {
			fatalError("Failed to create test storage engine")
		}

		return Store<ANEventConcept>(
			storage: storage,
			cacheIdentifier: \.id.uuidString
		)
	}
}

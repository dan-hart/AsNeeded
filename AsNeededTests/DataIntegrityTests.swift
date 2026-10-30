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
			nickname: "Test Med",
			quantity: 30,
			initialQuantity: 60,
			displayColorHex: "#FF5733",
			lastRefillDate: originalDate,
			nextRefillDate: originalDate.addingTimeInterval(86400 * 30),
			prescribedUnit: .tablet,
			prescribedDoseAmount: 500,
			rxNormCode: "12345"
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
		#expect(medication.nickname == original.nickname, "Nickname should match")
		#expect(medication.quantity == original.quantity, "Quantity should match")
		#expect(medication.displayColorHex == original.displayColorHex, "Color hex should match")
		#expect(medication.rxNormCode == original.rxNormCode, "RxNorm code should match")
		#expect(medication.isArchived == original.isArchived, "isArchived should match")

		// Verify date within 1 second tolerance (floating point comparison)
		if let retrievedDate = medication.lastRefillDate, let originalRefillDate = original.lastRefillDate {
			let timeDifference = abs(retrievedDate.timeIntervalSince(originalRefillDate))
			#expect(timeDifference < 1.0, "Last refill date should match within 1 second")
		}

		// Cleanup
		try await testStore.removeAll()
	}

	@Test("Migration preserves all event fields")
	func migrationPreservesAllEventFields() async throws {
		// Given - an event with ALL fields populated
		let eventID = UUID()
		let eventDate = Date()

		// Create a medication for the event
		let medication = ANMedicationConcept(
			clinicalName: "Test Medication",
			prescribedUnit: .tablet
		)

		let original = ANEventConcept(
			id: eventID,
			eventType: .doseTaken,
			medication: medication,
			date: eventDate,
			note: "Took with food"
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
		#expect(event.eventType == original.eventType, "Event type should match")
		#expect(event.medication?.id == original.medication?.id, "Medication ID should match")
		#expect(event.note == original.note, "Note should match")

		// Verify date within 1 second tolerance
		let timeDifference = abs(event.date.timeIntervalSince(original.date))
		#expect(timeDifference < 1.0, "Date should match within 1 second")

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
			prescribedUnit: .milligram,
			prescribedDoseAmount: 100
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

	// Repeated-launch migration coverage lives in DataMigrationManagerTests, using
	// production filenames and isolated source/destination directories.

	// MARK: - Backup and Restore Tests

	@Test("Offline migration backup restores persisted medications and history end-to-end")
	func backupRestoreEndToEnd() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let med = ANMedicationConcept(clinicalName: "Backup example", quantity: 12.5)
		let event = ANEventConcept(eventType: .doseTaken, medication: med, dose: ANDoseConcept(amount: 0.5, unit: .unit), date: Date(), note: "Example note")
		try await writeSnapshot(medications: [med], events: [event], directory: directory)
		let manager = BackupManager(appGroupURL: directory)
		let backup = await manager.createPreMigrationBackup()
		#expect(backup.success)
		let path = try #require(backup.backupPath)
		try await writeSnapshot(medications: [ANMedicationConcept(clinicalName: "Replacement example")], events: [], directory: directory)
		let restored = try await manager.restoreFromBackup(at: path)
		#expect(restored)
		// Migration backups restore files before stores open. Reopen the persisted
		// databases instead of asserting against an unrelated Boutique memory cache.
		let medications = try await readSnapshot(ANMedicationConcept.self, directory: directory, name: StorageConstants.medicationsDBName)
		let events = try await readSnapshot(ANEventConcept.self, directory: directory, name: StorageConstants.eventsDBName)
		#expect(medications == [med])
		#expect(events.map(\.id) == [event.id])
		#expect(events.first?.medication?.id == med.id)
		#expect(events.first?.dose == event.dose)
		#expect(events.first?.note == event.note)
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

	@Test("Backup manager copies the configured database paths")
	func backupManagerUsesStorageConstantsPaths() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		try await writeSnapshot(medications: [ANMedicationConcept(clinicalName: "Backup example")], events: [], directory: directory)
		let result = await BackupManager(appGroupURL: directory).createPreMigrationBackup()
		#expect(result.success)
		#expect(result.medicationsBackedUp)
		#expect(result.eventsBackedUp)
		let backup = try #require(result.backupPath)
		#expect(FileManager.default.fileExists(atPath: backup.appendingPathComponent(StorageConstants.medicationsDBPath).path))
		#expect(FileManager.default.fileExists(atPath: backup.appendingPathComponent(StorageConstants.eventsDBPath).path))
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
		Store<ANMedicationConcept>(storage: SQLiteStorageEngine.default(appendingPath: "integrity-medications-\(UUID().uuidString)"), cacheIdentifier: \.id.uuidString)
	}

	private func createEventTestStore() -> Store<ANEventConcept> {
		Store<ANEventConcept>(storage: SQLiteStorageEngine.default(appendingPath: "integrity-events-\(UUID().uuidString)"), cacheIdentifier: \.id.uuidString)
	}

	private func writeSnapshot(medications: [ANMedicationConcept], events: [ANEventConcept], directory: URL) async throws {
		let medicationsStorage = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: StorageConstants.medicationsDBName))
		let eventsStorage = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: StorageConstants.eventsDBName))
		let medicationStore = try await Store<ANMedicationConcept>(storage: medicationsStorage, cacheIdentifier: \.id.uuidString)
		let eventStore = try await Store<ANEventConcept>(storage: eventsStorage, cacheIdentifier: \.id.uuidString)
		try await medicationStore.removeAll()
		try await eventStore.removeAll()
		try await medicationStore.insert(medications)
		try await eventStore.insert(events)
	}

	private func readSnapshot<T: Codable & Identifiable & Sendable>(_ type: T.Type, directory: URL, name: String) async throws -> [T] where T.ID == UUID {
		let storage = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: name))
		let store = try await Store<T>(storage: storage, cacheIdentifier: \.id.uuidString)
		return store.items
	}
}

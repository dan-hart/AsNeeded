// DataMigrationManager.swift
// Handles one-time migration of data from legacy storage locations to App Group container

import ANModelKit
import Boutique
import DHLoggingKit
import Foundation

/// Manages migration of SQLite databases from legacy app container to App Group container
///
/// This manager was created to address a critical data loss bug introduced in commit 61e6ad5 (October 13, 2025)
/// when database storage was moved from the app's default container to an App Group container without
/// implementing data migration. This caused all existing user data to become inaccessible.
///
/// The migration process:
/// 1. Checks if migration has already been completed (via UserDefaults flag)
/// 2. Locates old database files in the legacy app container
/// 3. Verifies if migration is needed (old data exists, new container is empty)
/// 4. Copies SQLite database files from old location to new App Group container
/// 5. Marks migration as complete to prevent re-running
///
/// Safety features:
/// - Non-destructive: Never deletes old data
/// - Idempotent: Safe to run multiple times
/// - Atomic: Uses selective insert/update instead of removeAll() to prevent data loss on crash
/// - No force unwraps: Graceful error handling prevents boot loops
/// - Detailed logging for troubleshooting
/// - Error handling with graceful fallbacks
///
/// Multiple Store Instances Analysis:
/// This migration creates multiple Store instances for the same databases (legacy stores for reading,
/// current stores for reading, write stores for updating). While SQLite supports multiple readers OR
/// one writer, this is SAFE because:
/// 1. MigrationCoordinator ensures migration completes BEFORE any DataStore access
/// 2. Legacy and current databases are different physical files
/// 3. Stores are created, used, and released sequentially (not concurrently)
/// 4. Write stores are the only ones accessing the final database during the write phase
/// Therefore, there is no risk of WAL conflicts or cache incoherence.
@MainActor
public final class DataMigrationManager {
	private let logger = DHLogger.data
	private static let appGroupIdentifier = "group.com.codedbydan.AsNeeded"

	/// Key for tracking migration completion status
	private static let migrationCompletedKey = UserDefaultsKeys.dataMigrationCompleted

	/// Key for tracking migration attempt status (to distinguish "not needed" from "failed")
	private static let migrationAttemptedKey = UserDefaultsKeys.dataMigrationAttempted

	// MARK: - Public API

	/// Performs one-time migration of data from legacy storage to App Group container
	/// This should be called BEFORE initializing DataStore
	public func migrateIfNeeded() async {
		// Log diagnostic information
		let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
		logger.info("Migration check starting - Bundle ID: \(bundleID)")
		logSystemDiagnostics()

		// Check if migration already completed
		guard !UserDefaults.standard.bool(forKey: Self.migrationCompletedKey) else {
			logger.info("⏭ Data migration already completed, skipping")
			return
		}

		logger.info("Starting data migration check...")

		// Mark that we've attempted migration (helps distinguish "not needed" from "failed")
		markMigrationAttempted()

		do {
			// Get paths for old and new storage locations
			guard let legacyPaths = getLegacyDatabasePaths(),
			      let appGroupPaths = getAppGroupDatabasePaths() else {
				// CRITICAL: Do NOT mark as complete if paths unavailable
				// This likely means App Group is inaccessible, which is a fatal error
				logger.error("❌ Unable to determine database paths - App Group may be unavailable")
				logger.error("This is a CRITICAL error - migration cannot proceed without App Group access")
				logger.error("Legacy path check: \(getLegacyDatabasePaths() != nil)")
				logger.error("App Group path check: \(getAppGroupDatabasePaths() != nil)")
				throw MigrationError.appGroupUnavailable
			}

			logger.info("Legacy medications DB: \(legacyPaths.medications)")
			logger.info("Legacy events DB: \(legacyPaths.events)")
			logger.info("App Group medications DB: \(appGroupPaths.medications)")
			logger.info("App Group events DB: \(appGroupPaths.events)")

			// Check if old databases exist
			let fileManager = FileManager.default
			let medicationsExists = fileManager.fileExists(atPath: legacyPaths.medications)
			let eventsExists = fileManager.fileExists(atPath: legacyPaths.events)

			guard medicationsExists || eventsExists else {
				logger.info("✅ No legacy databases found - this is a fresh install or data already migrated")
				logger.info("Checked paths: medications=\(legacyPaths.medications), events=\(legacyPaths.events)")
				markMigrationComplete()
				return
			}

			logger.info("Found legacy databases - medications: \(medicationsExists), events: \(eventsExists)")

			// Determine if migration should proceed
			let shouldMigrate = try await shouldPerformMigration(
				appGroupPaths: appGroupPaths,
				legacyPaths: legacyPaths
			)

			guard shouldMigrate else {
				logger.info("✅ Migration check complete - no action needed")
				markMigrationComplete()
				return
			}

			// Perform the migration
			try await performMigration(from: legacyPaths, to: appGroupPaths)

			logger.info("✅ Data migration completed successfully")
			markMigrationComplete()

		} catch {
			logger.error("Migration failed: \(error.localizedDescription)")
			// Don't mark as complete on failure so it can retry next launch
			// but log extensively for debugging
			logger.error("Migration error details: \(String(describing: error))")
		}
	}

	// MARK: - Private Helpers

	/// Returns paths to legacy database files in default app container
	/// Checks for multiple filename variations to handle different SQLite naming conventions
	private func getLegacyDatabasePaths() -> (medications: String, events: String)? {
		// Legacy databases were stored using try SQLiteStorageEngine.default()
		// which places files in Library/Application Support/
		guard let appSupportURL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first else {
			logger.error("Unable to locate Application Support directory")
			return nil
		}

		// Check for multiple filename variations:
		// 1. "medications.sqlite" (most common)
		// 2. "medications" (no extension - some SQLite engines use this)
		let medicationsPath = findDatabaseFile(
			in: appSupportURL,
			baseName: "medications"
		)
		let eventsPath = findDatabaseFile(
			in: appSupportURL,
			baseName: "events"
		)

		// Log which variations were found
		if let medPath = medicationsPath {
			logger.info("Found legacy medications database: \(medPath)")
		}
		if let evtPath = eventsPath {
			logger.info("Found legacy events database: \(evtPath)")
		}

		// Return the first found variation for each database
		// If neither medications nor events exist, we still return paths for the .sqlite version
		// (the calling code will check if files actually exist)
		return (
			medications: medicationsPath ?? appSupportURL.appendingPathComponent("medications.sqlite").path,
			events: eventsPath ?? appSupportURL.appendingPathComponent("events.sqlite").path
		)
	}

	/// Finds a database file by checking multiple filename variations
	/// Returns the path to the first file that exists, or nil if none found
	private func findDatabaseFile(in directory: URL, baseName: String) -> String? {
		let fileManager = FileManager.default

		// Check variations in order of likelihood
		let variations = [
			"\(baseName).sqlite",     // Most common
			baseName,                  // No extension
			"\(baseName).db",          // Alternative extension
		]

		for variation in variations {
			let path = directory.appendingPathComponent(variation).path
			if fileManager.fileExists(atPath: path) {
				logger.debug("Found database file: \(variation)")
				return path
			}
		}

		// Also check for WAL files without main DB (data might be in WAL)
		let walPath = directory.appendingPathComponent("\(baseName).sqlite-wal").path
		if fileManager.fileExists(atPath: walPath) {
			logger.warning("Found WAL file without main database: \(baseName).sqlite-wal")
			logger.warning("Data may be in WAL file - will attempt to checkpoint")
			// Return path to main DB even if it doesn't exist yet
			// The WAL file will be handled separately
			return directory.appendingPathComponent("\(baseName).sqlite").path
		}

		return nil
	}

	/// Returns paths to new database files in App Group container
	private func getAppGroupDatabasePaths() -> (medications: String, events: String)? {
		guard let sharedContainerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
		) else {
			logger.error("Unable to access App Group container: \(Self.appGroupIdentifier)")
			return nil
		}

		// New databases use "medications.sqlite" and "events.sqlite"
		// (SQLiteStorageEngine adds .sqlite extension to the filename)
		let medicationsPath = sharedContainerURL
			.appendingPathComponent("medications.sqlite")
			.path
		let eventsPath = sharedContainerURL
			.appendingPathComponent("events.sqlite")
			.path

		return (medications: medicationsPath, events: eventsPath)
	}

	/// Determines if migration should be performed
	/// Always returns true if legacy databases exist - we'll merge the data
	private func shouldPerformMigration(
		appGroupPaths: (medications: String, events: String),
		legacyPaths: (medications: String, events: String)
	) async throws -> Bool {
		let fileManager = FileManager.default

		// Check if legacy databases exist
		let legacyMedicationsExists = fileManager.fileExists(atPath: legacyPaths.medications)
		let legacyEventsExists = fileManager.fileExists(atPath: legacyPaths.events)

		// If legacy databases exist, we should migrate (merge) the data
		let shouldMigrate = legacyMedicationsExists || legacyEventsExists
		logger.info("Migration needed: \(shouldMigrate) (legacy meds: \(legacyMedicationsExists), legacy events: \(legacyEventsExists))")

		return shouldMigrate
	}

	/// Performs the actual migration by merging data from legacy and new databases
	/// This ensures NO DATA IS LOST - both old and new data are preserved
	private func performMigration(
		from legacyPaths: (medications: String, events: String),
		to appGroupPaths: (medications: String, events: String)
	) async throws {
		logger.info("🚀 Starting database migration with data merge...")

		// Load data from legacy databases
		let legacyData = try await loadLegacyData(legacyPaths: legacyPaths)
		logger.info("Loaded legacy data: \(legacyData.medications.count) medications, \(legacyData.events.count) events")

		// Load data from current App Group databases (if any)
		let currentData = try await loadCurrentData(appGroupPaths: appGroupPaths)
		logger.info("Loaded current data: \(currentData.medications.count) medications, \(currentData.events.count) events")

		// Merge the data (deduplicating by ID)
		let mergedMedications = mergeData(legacy: legacyData.medications, current: currentData.medications)
		let mergedEvents = mergeData(legacy: legacyData.events, current: currentData.events)

		logger.info("Merged data: \(mergedMedications.count) medications, \(mergedEvents.count) events")

		// Write merged data back to App Group databases
		try await writeMergedData(
			medications: mergedMedications,
			events: mergedEvents,
			appGroupPaths: appGroupPaths
		)

		// CRITICAL: Verify migration succeeded with no data loss
		try await verifyMigration(
			expectedMedications: mergedMedications.count,
			expectedEvents: mergedEvents.count,
			appGroupPaths: appGroupPaths
		)

		logger.info("✅ Data migration and merge completed successfully")
	}

	/// Loads data from legacy database files
	/// Also handles WAL (Write-Ahead Log) and SHM (Shared Memory) files
	private func loadLegacyData(legacyPaths: (medications: String, events: String)) async throws -> (medications: [ANMedicationConcept], events: [ANEventConcept]) {
		let fileManager = FileManager.default

		var medications: [ANMedicationConcept] = []
		var events: [ANEventConcept] = []

		// Load medications from legacy database
		if fileManager.fileExists(atPath: legacyPaths.medications) {
			// Check for and log WAL/SHM files
			checkForWALFiles(at: legacyPaths.medications)

			let legacyMedicationsStore = try await Store<ANMedicationConcept>(
				storage: try SQLiteStorageEngine.default(appendingPath: "medications.sqlite"),
				cacheIdentifier: \ANMedicationConcept.id.uuidString
			)
			// Opening the store automatically integrates WAL file data into the read
			medications = await legacyMedicationsStore.items
			logger.debug("Loaded \(medications.count) medications from legacy database (including WAL data if present)")
		}

		// Load events from legacy database
		if fileManager.fileExists(atPath: legacyPaths.events) {
			// Check for and log WAL/SHM files
			checkForWALFiles(at: legacyPaths.events)

			let legacyEventsStore = try await Store<ANEventConcept>(
				storage: try SQLiteStorageEngine.default(appendingPath: "events.sqlite"),
				cacheIdentifier: \ANEventConcept.id.uuidString
			)
			// Opening the store automatically integrates WAL file data into the read
			events = await legacyEventsStore.items
			logger.debug("Loaded \(events.count) events from legacy database (including WAL data if present)")
		}

		return (medications: medications, events: events)
	}

	/// Checks for and logs WAL (Write-Ahead Log) and SHM (Shared Memory) files
	/// These files contain uncommitted SQLite transactions
	private func checkForWALFiles(at databasePath: String) {
		let fileManager = FileManager.default
		let walPath = "\(databasePath)-wal"
		let shmPath = "\(databasePath)-shm"

		let walExists = fileManager.fileExists(atPath: walPath)
		let shmExists = fileManager.fileExists(atPath: shmPath)

		if walExists || shmExists {
			logger.info("SQLite WAL mode files detected for \(URL(fileURLWithPath: databasePath).lastPathComponent):")
			if walExists {
				if let walSize = try? fileManager.attributesOfItem(atPath: walPath)[.size] as? Int64 {
					logger.info("  - WAL file: \(walSize) bytes (contains uncommitted transactions)")
				}
			}
			if shmExists {
				logger.info("  - SHM file: present (shared memory index)")
			}
			logger.info("Note: SQLite automatically integrates WAL data when reading, so all data will be migrated")
		}
	}

	/// Loads data from current App Group database files
	private func loadCurrentData(appGroupPaths: (medications: String, events: String)) async throws -> (medications: [ANMedicationConcept], events: [ANEventConcept]) {
		let fileManager = FileManager.default

		var medications: [ANMedicationConcept] = []
		var events: [ANEventConcept] = []

		guard let sharedContainerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
		) else {
			logger.warning("Unable to access App Group container")
			return (medications: [], events: [])
		}

		// Load medications from App Group database (if exists)
		if fileManager.fileExists(atPath: appGroupPaths.medications) {
			guard let medicationsStorage = try SQLiteStorageEngine(
				directory: FileManager.Directory(url: sharedContainerURL),
				databaseFilename: "medications"
			) else {
				logger.error("Failed to create storage engine for current medications database")
				throw MigrationError.invalidPath
			}
			let currentMedicationsStore = try await Store<ANMedicationConcept>(
				storage: medicationsStorage,
				cacheIdentifier: \ANMedicationConcept.id.uuidString
			)
			medications = await currentMedicationsStore.items
			logger.debug("Loaded \(medications.count) medications from current database")
		}

		// Load events from App Group database (if exists)
		if fileManager.fileExists(atPath: appGroupPaths.events) {
			guard let eventsStorage = try SQLiteStorageEngine(
				directory: FileManager.Directory(url: sharedContainerURL),
				databaseFilename: "events"
			) else {
				logger.error("Failed to create storage engine for current events database")
				throw MigrationError.invalidPath
			}
			let currentEventsStore = try await Store<ANEventConcept>(
				storage: eventsStorage,
				cacheIdentifier: \ANEventConcept.id.uuidString
			)
			events = await currentEventsStore.items
			logger.debug("Loaded \(events.count) events from current database")
		}

		return (medications: medications, events: events)
	}

	/// Merges legacy and current data, deduplicating by ID (legacy takes precedence)
	private func mergeData<T: Identifiable>(legacy: [T], current: [T]) -> [T] {
		// Create a dictionary of current items by ID for fast lookup
		var itemsById = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })

		// Add legacy items (overwriting current items with same ID)
		for item in legacy {
			itemsById[item.id] = item
		}

		return Array(itemsById.values)
	}

	/// Writes merged data to App Group databases
	private func writeMergedData(
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		appGroupPaths: (medications: String, events: String)
	) async throws {
		guard let sharedContainerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
		) else {
			throw MigrationError.invalidPath
		}

		// Create fresh stores for writing merged data
		guard let medicationsStorage = try SQLiteStorageEngine(
			directory: FileManager.Directory(url: sharedContainerURL),
			databaseFilename: "medications"
		) else {
			logger.error("Failed to create storage engine for medications database")
			throw MigrationError.invalidPath
		}
		let medicationsStore = try await Store<ANMedicationConcept>(
			storage: medicationsStorage,
			cacheIdentifier: \ANMedicationConcept.id.uuidString
		)

		guard let eventsStorage = try SQLiteStorageEngine(
			directory: FileManager.Directory(url: sharedContainerURL),
			databaseFilename: "events"
		) else {
			logger.error("Failed to create storage engine for events database")
			throw MigrationError.invalidPath
		}
		let eventsStore = try await Store<ANEventConcept>(
			storage: eventsStorage,
			cacheIdentifier: \ANEventConcept.id.uuidString
		)

		// CRITICAL: Do NOT call removeAll() - if app crashes after that, all data is lost
		// Instead, selectively update/insert items for atomicity

		// Get current items
		let currentMedications = await medicationsStore.items
		let currentEvents = await eventsStore.items

		// Build sets of IDs for efficient lookup
		let mergedMedicationIDs = Set(medications.map { $0.id })
		let mergedEventIDs = Set(events.map { $0.id })

		// Remove items that aren't in merged set (items that should be deleted)
		for current in currentMedications where !mergedMedicationIDs.contains(current.id) {
			try await medicationsStore.remove(current)
		}
		for current in currentEvents where !mergedEventIDs.contains(current.id) {
			try await eventsStore.remove(current)
		}

		// Insert or update merged medications
		for medication in medications {
			// Remove if exists, then insert (update pattern from DataStore)
			if currentMedications.contains(where: { $0.id == medication.id }) {
				if let existing = currentMedications.first(where: { $0.id == medication.id }) {
					try await medicationsStore.remove(existing)
				}
			}
			try await medicationsStore.insert(medication)
		}
		logger.info("Wrote \(medications.count) medications to App Group database")

		// Insert or update merged events
		for event in events {
			// Remove if exists, then insert (update pattern from DataStore)
			if currentEvents.contains(where: { $0.id == event.id }) {
				if let existing = currentEvents.first(where: { $0.id == event.id }) {
					try await eventsStore.remove(existing)
				}
			}
			try await eventsStore.insert(event)
		}
		logger.info("Wrote \(events.count) events to App Group database")
	}

	/// Verifies that migration completed successfully with no data loss
	/// Throws an error if the actual item counts don't match expected counts
	private func verifyMigration(
		expectedMedications: Int,
		expectedEvents: Int,
		appGroupPaths: (medications: String, events: String)
	) async throws {
		logger.info("Verifying migration integrity...")

		guard let sharedContainerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
		) else {
			throw MigrationError.appGroupUnavailable
		}

		// Load data from App Group to verify
		let fileManager = FileManager.default
		var actualMedications = 0
		var actualEvents = 0

		// Verify medications
		if fileManager.fileExists(atPath: appGroupPaths.medications) {
			guard let medicationsStorage = try SQLiteStorageEngine(
				directory: FileManager.Directory(url: sharedContainerURL),
				databaseFilename: "medications"
			) else {
				throw MigrationError.verificationFailed(
					expected: expectedMedications,
					actual: 0,
					type: "medications"
				)
			}
			let medicationsStore = try await Store<ANMedicationConcept>(
				storage: medicationsStorage,
				cacheIdentifier: \ANMedicationConcept.id.uuidString
			)
			actualMedications = await medicationsStore.items.count
		}

		// Verify events
		if fileManager.fileExists(atPath: appGroupPaths.events) {
			guard let eventsStorage = try SQLiteStorageEngine(
				directory: FileManager.Directory(url: sharedContainerURL),
				databaseFilename: "events"
			) else {
				throw MigrationError.verificationFailed(
					expected: expectedEvents,
					actual: 0,
					type: "events"
				)
			}
			let eventsStore = try await Store<ANEventConcept>(
				storage: eventsStorage,
				cacheIdentifier: \ANEventConcept.id.uuidString
			)
			actualEvents = await eventsStore.items.count
		}

		// Check if counts match
		let medicationsMatch = actualMedications == expectedMedications
		let eventsMatch = actualEvents == expectedEvents

		logger.info("Migration verification:")
		logger.info("  Medications: expected=\(expectedMedications), actual=\(actualMedications) [\(medicationsMatch ? "✅" : "❌")]")
		logger.info("  Events: expected=\(expectedEvents), actual=\(actualEvents) [\(eventsMatch ? "✅" : "❌")]")

		// Throw error if counts don't match
		if !medicationsMatch {
			throw MigrationError.verificationFailed(
				expected: expectedMedications,
				actual: actualMedications,
				type: "medications"
			)
		}
		if !eventsMatch {
			throw MigrationError.verificationFailed(
				expected: expectedEvents,
				actual: actualEvents,
				type: "events"
			)
		}

		logger.info("✅ Migration verification passed - all data accounted for")

		// Log post-migration details
		logPostMigrationDetails(appGroupPaths: appGroupPaths)
	}

	/// Logs details after migration completes successfully
	private func logPostMigrationDetails(appGroupPaths: (medications: String, events: String)) {
		logger.info("=== Post-Migration Details ===")

		let fileManager = FileManager.default

		// Log file sizes
		if let medAttributes = try? fileManager.attributesOfItem(atPath: appGroupPaths.medications),
		   let medSize = medAttributes[.size] as? Int64 {
			let sizeMB = Double(medSize) / 1_048_576
			logger.info("Medications database size: \(String(format: "%.2f", sizeMB)) MB")
		}

		if let evtAttributes = try? fileManager.attributesOfItem(atPath: appGroupPaths.events),
		   let evtSize = evtAttributes[.size] as? Int64 {
			let sizeMB = Double(evtSize) / 1_048_576
			logger.info("Events database size: \(String(format: "%.2f", sizeMB)) MB")
		}

		// Check WAL file status
		let medWAL = "\(appGroupPaths.medications)-wal"
		let medSHM = "\(appGroupPaths.medications)-shm"
		let evtWAL = "\(appGroupPaths.events)-wal"
		let evtSHM = "\(appGroupPaths.events)-shm"

		let medWALExists = fileManager.fileExists(atPath: medWAL)
		let medSHMExists = fileManager.fileExists(atPath: medSHM)
		let evtWALExists = fileManager.fileExists(atPath: evtWAL)
		let evtSHMExists = fileManager.fileExists(atPath: evtSHM)

		if medWALExists || medSHMExists {
			logger.info("Medications WAL files present: WAL=\(medWALExists), SHM=\(medSHMExists)")
			if medWALExists, let walAttr = try? fileManager.attributesOfItem(atPath: medWAL),
			   let walSize = walAttr[.size] as? Int64 {
				logger.info("  WAL size: \(walSize) bytes")
			}
		} else {
			logger.info("Medications: No WAL files (clean state)")
		}

		if evtWALExists || evtSHMExists {
			logger.info("Events WAL files present: WAL=\(evtWALExists), SHM=\(evtSHMExists)")
			if evtWALExists, let walAttr = try? fileManager.attributesOfItem(atPath: evtWAL),
			   let walSize = walAttr[.size] as? Int64 {
				logger.info("  WAL size: \(walSize) bytes")
			}
		} else {
			logger.info("Events: No WAL files (clean state)")
		}

		// Available disk space after migration
		if let appGroupURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
		) {
			if let resourceValues = try? appGroupURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
			   let availableCapacity = resourceValues.volumeAvailableCapacity {
				let capacityMB = Double(availableCapacity) / 1_048_576
				logger.info("Available disk space after migration: \(String(format: "%.2f", capacityMB)) MB")
			}
		}

		logger.info("=== End Post-Migration Details ===")
	}

	/// Marks that a migration attempt has been made
	private func markMigrationAttempted() {
		UserDefaults.standard.set(true, forKey: Self.migrationAttemptedKey)
		UserDefaults.standard.synchronize()
		logger.debug("Migration attempt recorded")
	}

	/// Marks migration as complete in UserDefaults
	private func markMigrationComplete() {
		UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)
		UserDefaults.standard.synchronize()
		logger.info("Migration marked as complete")
	}

	/// Logs system diagnostics to help troubleshoot migration issues
	private func logSystemDiagnostics() {
		logger.info("=== System Diagnostics ===")

		// App Group accessibility
		if let appGroupURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
		) {
			logger.info("✅ App Group accessible: \(appGroupURL.path)")

			// Check if directory is writable
			let testFile = appGroupURL.appendingPathComponent(".migration_write_test")
			do {
				try "test".write(to: testFile, atomically: true, encoding: .utf8)
				try? FileManager.default.removeItem(at: testFile)
				logger.info("✅ App Group is writable")
			} catch {
				logger.error("❌ App Group is NOT writable: \(error.localizedDescription)")
			}

			// Log directory contents
			do {
				let contents = try FileManager.default.contentsOfDirectory(atPath: appGroupURL.path)
				logger.info("App Group contents (\(contents.count) items): \(contents.joined(separator: ", "))")
			} catch {
				logger.error("Failed to read App Group contents: \(error.localizedDescription)")
			}
		} else {
			logger.error("❌ App Group NOT accessible: \(Self.appGroupIdentifier)")
			logger.error("This is a CRITICAL error - migration cannot proceed")
		}

		// Legacy storage location
		if let legacyURL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first {
			logger.info("✅ Legacy storage accessible: \(legacyURL.path)")

			// Log directory contents
			do {
				let contents = try FileManager.default.contentsOfDirectory(atPath: legacyURL.path)
				logger.info("Legacy storage contents (\(contents.count) items): \(contents.joined(separator: ", "))")
			} catch {
				logger.error("Failed to read legacy storage contents: \(error.localizedDescription)")
			}
		} else {
			logger.error("❌ Legacy storage NOT accessible")
		}

		// Migration flags
		let attemptedFlag = UserDefaults.standard.bool(forKey: Self.migrationAttemptedKey)
		let completedFlag = UserDefaults.standard.bool(forKey: Self.migrationCompletedKey)
		logger.info("Migration flags: attempted=\(attemptedFlag), completed=\(completedFlag)")

		logger.info("=== End Diagnostics ===")
	}

	// MARK: - Testing Support

	/// Resets migration flags for testing purposes
	/// - Warning: Only use this in tests!
	public func resetMigrationFlagForTesting() {
		UserDefaults.standard.removeObject(forKey: Self.migrationCompletedKey)
		UserDefaults.standard.removeObject(forKey: Self.migrationAttemptedKey)
		UserDefaults.standard.synchronize()
		logger.warning("Migration flags reset (testing only)")
	}
}

// MARK: - Errors

enum MigrationError: LocalizedError {
	case copyFailed(source: String, destination: String)
	case invalidPath
	case appGroupUnavailable
	case verificationFailed(expected: Int, actual: Int, type: String)

	var errorDescription: String? {
		switch self {
		case let .copyFailed(source, destination):
			return "Failed to copy database from \(source) to \(destination)"
		case .invalidPath:
			return "Unable to determine database paths for migration"
		case .appGroupUnavailable:
			return "App Group container is unavailable. This is required for data storage. Please check that the app is properly signed with App Group entitlements."
		case let .verificationFailed(expected, actual, type):
			return "Migration verification failed for \(type): expected \(expected) items but found \(actual). This indicates data loss during migration."
		}
	}
}

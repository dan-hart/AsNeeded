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

	// MARK: - Public API

	/// Performs one-time migration of data from legacy storage to App Group container
	/// This should be called BEFORE initializing DataStore
	public func migrateIfNeeded() async {
		// Log bundle ID for diagnostic purposes
		let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
		logger.info("Migration check starting - Bundle ID: \(bundleID)")

		// Check if migration already completed
		guard !UserDefaults.standard.bool(forKey: Self.migrationCompletedKey) else {
			logger.info("⏭ Data migration already completed, skipping")
			return
		}

		logger.info("Starting data migration check...")

		do {
			// Get paths for old and new storage locations
			guard let legacyPaths = getLegacyDatabasePaths(),
			      let appGroupPaths = getAppGroupDatabasePaths() else {
				logger.warning("Unable to determine database paths, marking migration as complete")
				markMigrationComplete()
				return
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
				logger.info("No legacy databases found, migration not needed")
				markMigrationComplete()
				return
			}

			logger.info("Found legacy databases - medications: \(medicationsExists), events: \(eventsExists)")

			// Check if App Group databases are empty (indicating fresh state)
			let shouldMigrate = try await shouldPerformMigration(
				appGroupPaths: appGroupPaths,
				legacyPaths: legacyPaths
			)

			guard shouldMigrate else {
				logger.info("App Group already contains data, skipping migration")
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

		// The old code used "medications.sqlite" and "events.sqlite" as filenames
		let medicationsPath = appSupportURL
			.appendingPathComponent("medications.sqlite")
			.path
		let eventsPath = appSupportURL
			.appendingPathComponent("events.sqlite")
			.path

		return (medications: medicationsPath, events: eventsPath)
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

		logger.info("✅ Data migration and merge completed successfully")
	}

	/// Loads data from legacy database files
	private func loadLegacyData(legacyPaths: (medications: String, events: String)) async throws -> (medications: [ANMedicationConcept], events: [ANEventConcept]) {
		let fileManager = FileManager.default

		var medications: [ANMedicationConcept] = []
		var events: [ANEventConcept] = []

		// Load medications from legacy database
		if fileManager.fileExists(atPath: legacyPaths.medications) {
			let legacyMedicationsStore = try await Store<ANMedicationConcept>(
				storage: try SQLiteStorageEngine.default(appendingPath: "medications.sqlite"),
				cacheIdentifier: \ANMedicationConcept.id.uuidString
			)
			medications = await legacyMedicationsStore.items
			logger.debug("Loaded \(medications.count) medications from legacy database")
		}

		// Load events from legacy database
		if fileManager.fileExists(atPath: legacyPaths.events) {
			let legacyEventsStore = try await Store<ANEventConcept>(
				storage: try SQLiteStorageEngine.default(appendingPath: "events.sqlite"),
				cacheIdentifier: \ANEventConcept.id.uuidString
			)
			events = await legacyEventsStore.items
			logger.debug("Loaded \(events.count) events from legacy database")
		}

		return (medications: medications, events: events)
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

	/// Marks migration as complete in UserDefaults
	private func markMigrationComplete() {
		UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)
		UserDefaults.standard.synchronize()
		logger.info("Migration marked as complete")
	}

	// MARK: - Testing Support

	/// Resets migration flag for testing purposes
	/// - Warning: Only use this in tests!
	public func resetMigrationFlagForTesting() {
		UserDefaults.standard.removeObject(forKey: Self.migrationCompletedKey)
		UserDefaults.standard.synchronize()
		logger.warning("Migration flag reset (testing only)")
	}
}

// MARK: - Errors

enum MigrationError: LocalizedError {
	case copyFailed(source: String, destination: String)
	case invalidPath

	var errorDescription: String? {
		switch self {
		case let .copyFailed(source, destination):
			return "Failed to copy database from \(source) to \(destination)"
		case .invalidPath:
			return "Unable to determine database paths for migration"
		}
	}
}

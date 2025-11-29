// DataMigrationManager.swift
// Handles migration of data from legacy storage locations to App Group container

import ANModelKit
import Boutique
import DHLoggingKit
import Foundation

/// Manages migration of SQLite databases from legacy app container to App Group container
///
/// This manager uses a simplified, data-driven approach:
/// - If legacy data exists → merge it into App Group
/// - If no legacy data → nothing to do
/// - No flags needed - purely based on presence of data
///
/// Legacy data location (Bodega default on iOS):
///   Documents/medications.sqlite/data.sqlite3
///   Documents/events.sqlite/data.sqlite3
///
/// New data location (App Group):
///   App Group/medications.sqlite3
///   App Group/events.sqlite3
@MainActor
public final class DataMigrationManager {
	private let logger = DHLogger.data
	private static let appGroupIdentifier = "group.com.codedbydan.AsNeeded"

	// MARK: - Public API

	/// Performs data-driven migration from legacy storage to App Group container
	/// Safe to call on every app launch - only migrates if legacy data exists
	public func migrateIfNeeded() async {
		logger.info("=== Starting Migration Check ===")

		// Step 1: Find legacy data at correct iOS path
		guard let legacyPaths = findLegacyDatabases() else {
			logger.info("✅ No legacy data found - migration not needed")
			return
		}

		logger.info("Found legacy data:")
		logger.info("  Medications: \(legacyPaths.medications?.path ?? "none")")
		logger.info("  Events: \(legacyPaths.events?.path ?? "none")")

		// Step 2: Load legacy data
		do {
			let legacyData = try await loadLegacyData(from: legacyPaths)

			guard !legacyData.medications.isEmpty || !legacyData.events.isEmpty else {
				logger.info("✅ Legacy databases exist but are empty - migration not needed")
				return
			}

			logger.info("Loaded legacy data: \(legacyData.medications.count) medications, \(legacyData.events.count) events")

			// Step 3: Merge into App Group
			try await mergeIntoAppGroup(legacyData: legacyData)

			// Step 4: Verify merge
			let verified = try await verifyMerge(
				expectedMedicationsCount: legacyData.medications.count,
				expectedEventsCount: legacyData.events.count
			)

			if verified {
				logger.info("✅ Migration complete and verified")
			} else {
				logger.error("❌ Migration verification failed - keeping legacy data for retry")
			}

		} catch {
			logger.error("Migration failed: \(error.localizedDescription)")
			logger.error("Will retry on next app launch")
		}
	}

	// MARK: - Legacy Database Discovery

	/// Finds legacy databases at correct iOS paths
	/// Returns nil if no legacy data exists
	private func findLegacyDatabases() -> (medications: URL?, events: URL?)? {
		let fileManager = FileManager.default

		var medicationsURL: URL?
		var eventsURL: URL?

		// On iOS, Bodega's SQLiteStorageEngine.default() uses Documents directory
		// Structure: Documents/<name>.sqlite/data.sqlite3 (folder with default filename)
		if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
			logger.info("Searching Documents directory: \(documentsURL.path)")

			// Check Bodega folder structure
			let medicationsFolder = documentsURL.appendingPathComponent("medications.sqlite")
			let eventsFolder = documentsURL.appendingPathComponent("events.sqlite")

			let medicationsDB = medicationsFolder.appendingPathComponent("data.sqlite3")
			let eventsDB = eventsFolder.appendingPathComponent("data.sqlite3")

			if fileManager.fileExists(atPath: medicationsDB.path) {
				logger.info("✅ Found medications at: \(medicationsDB.path)")
				medicationsURL = medicationsDB
			}

			if fileManager.fileExists(atPath: eventsDB.path) {
				logger.info("✅ Found events at: \(eventsDB.path)")
				eventsURL = eventsDB
			}

			// Also check for WAL files (data may be uncommitted)
			checkForWALFiles(at: medicationsDB.path)
			checkForWALFiles(at: eventsDB.path)
		}

		// Also check Application Support (macOS compatibility / edge cases)
		if medicationsURL == nil || eventsURL == nil {
			if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
				logger.info("Searching Application Support: \(appSupportURL.path)")

				// Check direct paths
				if medicationsURL == nil {
					medicationsURL = findDatabaseInDirectory(appSupportURL, baseName: "medications")
				}
				if eventsURL == nil {
					eventsURL = findDatabaseInDirectory(appSupportURL, baseName: "events")
				}

				// Check bundle-ID subdirectory
				let bundleID = Bundle.main.bundleIdentifier ?? "com.codedbydan.AsNeeded"
				let bundleSubdir = appSupportURL.appendingPathComponent(bundleID)
				if fileManager.fileExists(atPath: bundleSubdir.path) {
					logger.info("Searching bundle subdirectory: \(bundleSubdir.path)")
					if medicationsURL == nil {
						medicationsURL = findDatabaseInDirectory(bundleSubdir, baseName: "medications")
					}
					if eventsURL == nil {
						eventsURL = findDatabaseInDirectory(bundleSubdir, baseName: "events")
					}
				}
			}
		}

		// Return nil if no legacy data found at all
		guard medicationsURL != nil || eventsURL != nil else {
			return nil
		}

		return (medications: medicationsURL, events: eventsURL)
	}

	/// Finds a database file in a directory, checking multiple path structures
	private func findDatabaseInDirectory(_ directory: URL, baseName: String) -> URL? {
		let fileManager = FileManager.default

		// Check Bodega folder structure first: <name>.sqlite/data.sqlite3
		let bodegaFolder = directory.appendingPathComponent("\(baseName).sqlite")
		let bodegaDataFile = bodegaFolder.appendingPathComponent("data.sqlite3")
		if fileManager.fileExists(atPath: bodegaDataFile.path) {
			logger.info("Found Bodega-style database: \(bodegaDataFile.path)")
			return bodegaDataFile
		}

		// Check flat file variations
		let flatVariations = [
			"\(baseName).sqlite3",
			"\(baseName).sqlite",
			baseName,
			"\(baseName).db",
		]

		for variation in flatVariations {
			let path = directory.appendingPathComponent(variation)
			if fileManager.fileExists(atPath: path.path) {
				logger.info("Found flat database file: \(path.path)")
				return path
			}
		}

		return nil
	}

	/// Checks for and logs WAL (Write-Ahead Log) files
	private func checkForWALFiles(at databasePath: String) {
		let fileManager = FileManager.default
		let walPath = "\(databasePath)-wal"
		let shmPath = "\(databasePath)-shm"

		let walExists = fileManager.fileExists(atPath: walPath)
		let shmExists = fileManager.fileExists(atPath: shmPath)

		if walExists || shmExists {
			logger.info("SQLite WAL files detected at \(URL(fileURLWithPath: databasePath).lastPathComponent):")
			if walExists {
				if let walSize = try? fileManager.attributesOfItem(atPath: walPath)[.size] as? Int64 {
					logger.info("  WAL: \(walSize) bytes")
				}
			}
			if shmExists {
				logger.info("  SHM: present")
			}
		}
	}

	// MARK: - Data Loading

	/// Loads data from legacy database files
	private func loadLegacyData(from paths: (medications: URL?, events: URL?)) async throws -> (medications: [ANMedicationConcept], events: [ANEventConcept]) {
		var medications: [ANMedicationConcept] = []
		var events: [ANEventConcept] = []

		// Load medications
		if let medicationsURL = paths.medications {
			let storage = try createStorageEngine(forDatabaseAt: medicationsURL)
			let store = try await Store<ANMedicationConcept>(
				storage: storage,
				cacheIdentifier: \ANMedicationConcept.id.uuidString
			)
			medications = await store.items
			logger.info("Loaded \(medications.count) medications from legacy database")
		}

		// Load events
		if let eventsURL = paths.events {
			let storage = try createStorageEngine(forDatabaseAt: eventsURL)
			let store = try await Store<ANEventConcept>(
				storage: storage,
				cacheIdentifier: \ANEventConcept.id.uuidString
			)
			events = await store.items
			logger.info("Loaded \(events.count) events from legacy database")
		}

		return (medications: medications, events: events)
	}

	/// Creates a storage engine for a database at the given URL
	private func createStorageEngine(forDatabaseAt databaseURL: URL) throws -> SQLiteStorageEngine {
		let directoryURL = databaseURL.deletingLastPathComponent()
		let baseName = databaseURL.deletingPathExtension().lastPathComponent

		guard !baseName.isEmpty else {
			logger.error("Invalid database filename: \(databaseURL.path)")
			throw MigrationError.invalidPath
		}

		guard let storage = try SQLiteStorageEngine(
			directory: FileManager.Directory(url: directoryURL),
			databaseFilename: baseName
		) else {
			logger.error("Failed to create storage engine for: \(databaseURL.path)")
			throw MigrationError.invalidPath
		}

		return storage
	}

	// MARK: - Data Merging

	/// Merges legacy data into App Group storage
	private func mergeIntoAppGroup(legacyData: (medications: [ANMedicationConcept], events: [ANEventConcept])) async throws {
		guard let appGroupURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
		) else {
			logger.error("App Group unavailable: \(Self.appGroupIdentifier)")
			throw MigrationError.appGroupUnavailable
		}

		logger.info("Merging data into App Group: \(appGroupURL.path)")

		// Load current App Group data
		let currentData = try await loadCurrentAppGroupData(containerURL: appGroupURL)
		logger.info("Current App Group data: \(currentData.medications.count) medications, \(currentData.events.count) events")

		// Merge data (legacy takes precedence for same IDs)
		let mergedMedications = mergeByID(legacy: legacyData.medications, current: currentData.medications)
		let mergedEvents = mergeByID(legacy: legacyData.events, current: currentData.events)

		logger.info("Merged data: \(mergedMedications.count) medications, \(mergedEvents.count) events")

		// Write merged data
		try await writeMergedData(
			medications: mergedMedications,
			events: mergedEvents,
			containerURL: appGroupURL
		)
	}

	/// Loads current data from App Group storage
	private func loadCurrentAppGroupData(containerURL: URL) async throws -> (medications: [ANMedicationConcept], events: [ANEventConcept]) {
		let fileManager = FileManager.default
		var medications: [ANMedicationConcept] = []
		var events: [ANEventConcept] = []

		let medicationsPath = containerURL.appendingPathComponent("medications.sqlite3").path
		let eventsPath = containerURL.appendingPathComponent("events.sqlite3").path

		if fileManager.fileExists(atPath: medicationsPath) {
			guard let storage = try SQLiteStorageEngine(
				directory: FileManager.Directory(url: containerURL),
				databaseFilename: "medications"
			) else {
				throw MigrationError.invalidPath
			}
			let store = try await Store<ANMedicationConcept>(
				storage: storage,
				cacheIdentifier: \ANMedicationConcept.id.uuidString
			)
			medications = await store.items
		}

		if fileManager.fileExists(atPath: eventsPath) {
			guard let storage = try SQLiteStorageEngine(
				directory: FileManager.Directory(url: containerURL),
				databaseFilename: "events"
			) else {
				throw MigrationError.invalidPath
			}
			let store = try await Store<ANEventConcept>(
				storage: storage,
				cacheIdentifier: \ANEventConcept.id.uuidString
			)
			events = await store.items
		}

		return (medications: medications, events: events)
	}

	/// Merges two arrays by ID, with legacy taking precedence
	private func mergeByID<T: Identifiable>(legacy: [T], current: [T]) -> [T] {
		var itemsById = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })

		// Legacy items overwrite current items with same ID
		for item in legacy {
			itemsById[item.id] = item
		}

		return Array(itemsById.values)
	}

	/// Writes merged data to App Group storage
	private func writeMergedData(
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		containerURL: URL
	) async throws {
		// Write medications
		guard let medicationsStorage = try SQLiteStorageEngine(
			directory: FileManager.Directory(url: containerURL),
			databaseFilename: "medications"
		) else {
			throw MigrationError.invalidPath
		}
		let medicationsStore = try await Store<ANMedicationConcept>(
			storage: medicationsStorage,
			cacheIdentifier: \ANMedicationConcept.id.uuidString
		)

		// Write events
		guard let eventsStorage = try SQLiteStorageEngine(
			directory: FileManager.Directory(url: containerURL),
			databaseFilename: "events"
		) else {
			throw MigrationError.invalidPath
		}
		let eventsStore = try await Store<ANEventConcept>(
			storage: eventsStorage,
			cacheIdentifier: \ANEventConcept.id.uuidString
		)

		// Get current items for update logic
		let currentMedications = await medicationsStore.items
		let currentEvents = await eventsStore.items

		// Insert/update medications
		for medication in medications {
			if let existing = currentMedications.first(where: { $0.id == medication.id }) {
				try await medicationsStore.remove(existing)
			}
			try await medicationsStore.insert(medication)
		}
		logger.info("Wrote \(medications.count) medications")

		// Insert/update events
		for event in events {
			if let existing = currentEvents.first(where: { $0.id == event.id }) {
				try await eventsStore.remove(existing)
			}
			try await eventsStore.insert(event)
		}
		logger.info("Wrote \(events.count) events")
	}

	// MARK: - Verification

	/// Verifies that merge completed successfully
	private func verifyMerge(expectedMedicationsCount: Int, expectedEventsCount: Int) async throws -> Bool {
		guard let appGroupURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
		) else {
			throw MigrationError.appGroupUnavailable
		}

		let currentData = try await loadCurrentAppGroupData(containerURL: appGroupURL)

		let medicationsOK = currentData.medications.count >= expectedMedicationsCount
		let eventsOK = currentData.events.count >= expectedEventsCount

		logger.info("Verification:")
		logger.info("  Medications: expected >= \(expectedMedicationsCount), actual = \(currentData.medications.count) [\(medicationsOK ? "✅" : "❌")]")
		logger.info("  Events: expected >= \(expectedEventsCount), actual = \(currentData.events.count) [\(eventsOK ? "✅" : "❌")]")

		return medicationsOK && eventsOK
	}

	// MARK: - Debug Support

	/// Returns information about legacy data status (for debug UI)
	public func getLegacyDataStatus() -> (found: Bool, medicationsPath: String?, eventsPath: String?, medicationsCount: Int, eventsCount: Int) {
		guard let paths = findLegacyDatabases() else {
			return (found: false, medicationsPath: nil, eventsPath: nil, medicationsCount: 0, eventsCount: 0)
		}

		// Count items synchronously for UI display
		var medicationsCount = 0
		var eventsCount = 0

		if let medPath = paths.medications, FileManager.default.fileExists(atPath: medPath.path) {
			// Just check if file exists - actual count requires async
			medicationsCount = -1 // Indicates "exists but count unknown"
		}

		if let evtPath = paths.events, FileManager.default.fileExists(atPath: evtPath.path) {
			eventsCount = -1
		}

		return (
			found: true,
			medicationsPath: paths.medications?.path,
			eventsPath: paths.events?.path,
			medicationsCount: medicationsCount,
			eventsCount: eventsCount
		)
	}
}

// MARK: - Errors

enum MigrationError: LocalizedError {
	case invalidPath
	case appGroupUnavailable
	case verificationFailed(expected: Int, actual: Int, type: String)

	var errorDescription: String? {
		switch self {
		case .invalidPath:
			return "Unable to determine database paths for migration"
		case .appGroupUnavailable:
			return "App Group container is unavailable. Please check app signing."
		case let .verificationFailed(expected, actual, type):
			return "Migration verification failed for \(type): expected \(expected) but found \(actual)"
		}
	}
}

// DataRecoveryManager.swift
// Data archaeology tools for finding and recovering orphaned data
// Part of the Data Loss Prevention strategy - see CLAUDE.md "Dangerous Files Registry"
//
// This manager scans ALL known historical storage locations to find data
// that may have been orphaned due to storage path changes.

import ANModelKit
import Boutique
import DHLoggingKit
import Foundation

/// Manages recovery of orphaned data from historical storage locations
///
/// This is the "last resort" recovery tool when data appears to be lost.
/// It scans all known locations where data may have been stored in previous
/// app versions and can recover/merge that data into the current storage.
@MainActor
public final class DataRecoveryManager {
	public static let shared = DataRecoveryManager()
	private let logger = DHLogger.data

	/// Report of recovery scan results
	public struct RecoveryReport {
		public var scannedLocations: [ScannedLocation] = []
		public var totalMedicationsFound: Int = 0
		public var totalEventsFound: Int = 0
		public var hasOrphanedData: Bool { totalMedicationsFound > 0 || totalEventsFound > 0 }

		public struct ScannedLocation {
			public let path: String
			public let type: LocationType
			public let medicationsFound: Int
			public let eventsFound: Int
			public let exists: Bool
		}

		public enum LocationType: String {
			case appGroup = "App Group (Current)"
			case documents = "Documents"
			case applicationSupport = "Application Support"
			case bundleSubdirectory = "Bundle Subdirectory"
			case backup = "Backup"
		}
	}

	private init() {}

	// MARK: - Public API

	/// Scans ALL known historical storage locations for orphaned data
	/// This is safe to call - it only reads, never writes
	/// - Returns: Report of what was found
	public func scanForOrphanedData() async -> RecoveryReport {
		logger.info("=== Starting Data Recovery Scan ===")
		var report = RecoveryReport()
		let fileManager = FileManager.default

		// 1. Current App Group location
		if let appGroupURL = fileManager.containerURL(
			forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier
		) {
			let result = await scanLocation(
				at: appGroupURL,
				type: .appGroup,
				checkBodegaStructure: false
			)
			report.scannedLocations.append(result)
			report.totalMedicationsFound += result.medicationsFound
			report.totalEventsFound += result.eventsFound
		}

		// 2. Documents directory (Bodega default on iOS)
		if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
			let result = await scanLocation(
				at: documentsURL,
				type: .documents,
				checkBodegaStructure: true
			)
			report.scannedLocations.append(result)
			// Don't add to total if same as App Group
			if result.medicationsFound > 0 || result.eventsFound > 0 {
				logger.info("Found orphaned data in Documents: \(result.medicationsFound) meds, \(result.eventsFound) events")
			}
		}

		// 3. Application Support directory
		if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
			let result = await scanLocation(
				at: appSupportURL,
				type: .applicationSupport,
				checkBodegaStructure: true
			)
			report.scannedLocations.append(result)

			// 4. Bundle ID subdirectory within Application Support
			let bundleID = Bundle.main.bundleIdentifier ?? StorageConstants.Legacy.bundleIdentifier
			let bundleSubdir = appSupportURL.appendingPathComponent(bundleID)
			if fileManager.fileExists(atPath: bundleSubdir.path) {
				let bundleResult = await scanLocation(
					at: bundleSubdir,
					type: .bundleSubdirectory,
					checkBodegaStructure: true
				)
				report.scannedLocations.append(bundleResult)
			}
		}

		// 5. Scan backup directories
		if let appGroupURL = fileManager.containerURL(
			forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier
		) {
			let backupDir = appGroupURL.appendingPathComponent(StorageConstants.backupDirectoryName)
			if fileManager.fileExists(atPath: backupDir.path) {
				do {
					let backups = try fileManager.contentsOfDirectory(
						at: backupDir,
						includingPropertiesForKeys: nil,
						options: [.skipsHiddenFiles]
					)
					for backup in backups {
						let backupResult = await scanLocation(
							at: backup,
							type: .backup,
							checkBodegaStructure: false
						)
						report.scannedLocations.append(backupResult)
					}
				} catch {
					logger.error("Failed to scan backup directory: \(error.localizedDescription)")
				}
			}
		}

		logger.info("=== Data Recovery Scan Complete ===")
		logger.info("Found \(report.totalMedicationsFound) medications, \(report.totalEventsFound) events across \(report.scannedLocations.count) locations")

		return report
	}

	/// Recovers data from a specific location and merges it into current storage
	/// - Parameter location: The location to recover from
	/// - Returns: Number of items recovered
	public func recoverFromLocation(_ locationPath: String) async throws -> (medications: Int, events: Int) {
		logger.info("Recovering data from: \(locationPath)")

		let locationURL = URL(fileURLWithPath: locationPath)

		// Load data from location
		let recoveredData = try await loadDataFromLocation(locationURL)

		guard !recoveredData.medications.isEmpty || !recoveredData.events.isEmpty else {
			logger.info("No data to recover from location")
			return (0, 0)
		}

		// Merge into current storage
		let dataStore = DataStore.shared

		var medicationsRecovered = 0
		var eventsRecovered = 0

		// Add medications that don't already exist
		for medication in recoveredData.medications {
			let existingIDs = Set(dataStore.medications.map { $0.id })
			if !existingIDs.contains(medication.id) {
				try await dataStore.medicationsStore.insert(medication)
				medicationsRecovered += 1
			}
		}

		// Add events that don't already exist
		for event in recoveredData.events {
			let existingIDs = Set(dataStore.events.map { $0.id })
			if !existingIDs.contains(event.id) {
				try await dataStore.eventsStore.insert(event)
				eventsRecovered += 1
			}
		}

		logger.info("✅ Recovered \(medicationsRecovered) medications, \(eventsRecovered) events")
		return (medicationsRecovered, eventsRecovered)
	}

	// MARK: - Private Helpers

	private func scanLocation(
		at url: URL,
		type: RecoveryReport.LocationType,
		checkBodegaStructure: Bool
	) async -> RecoveryReport.ScannedLocation {
		let fileManager = FileManager.default

		guard fileManager.fileExists(atPath: url.path) else {
			return RecoveryReport.ScannedLocation(
				path: url.path,
				type: type,
				medicationsFound: 0,
				eventsFound: 0,
				exists: false
			)
		}

		logger.info("Scanning: \(url.path) (type: \(type.rawValue))")

		var medicationsCount = 0
		var eventsCount = 0

		// Check direct SQLite files
		let directMedicationsPath = url.appendingPathComponent("\(StorageConstants.medicationsDBName).sqlite3")
		let directEventsPath = url.appendingPathComponent("\(StorageConstants.eventsDBName).sqlite3")

		if fileManager.fileExists(atPath: directMedicationsPath.path) {
			if let count = await countItemsInDatabase(at: directMedicationsPath, type: "medications") {
				medicationsCount = count
			}
		}

		if fileManager.fileExists(atPath: directEventsPath.path) {
			if let count = await countItemsInDatabase(at: directEventsPath, type: "events") {
				eventsCount = count
			}
		}

		// Check Bodega folder structure if requested
		if checkBodegaStructure {
			let bodegaMedicationsPath = url
				.appendingPathComponent("\(StorageConstants.Legacy.medicationsDB).sqlite")
				.appendingPathComponent(StorageConstants.Legacy.bodegaDataFile)
			let bodegaEventsPath = url
				.appendingPathComponent("\(StorageConstants.Legacy.eventsDB).sqlite")
				.appendingPathComponent(StorageConstants.Legacy.bodegaDataFile)

			if fileManager.fileExists(atPath: bodegaMedicationsPath.path) && medicationsCount == 0 {
				if let count = await countItemsInDatabase(at: bodegaMedicationsPath, type: "medications") {
					medicationsCount = count
				}
			}

			if fileManager.fileExists(atPath: bodegaEventsPath.path) && eventsCount == 0 {
				if let count = await countItemsInDatabase(at: bodegaEventsPath, type: "events") {
					eventsCount = count
				}
			}
		}

		return RecoveryReport.ScannedLocation(
			path: url.path,
			type: type,
			medicationsFound: medicationsCount,
			eventsFound: eventsCount,
			exists: true
		)
	}

	private func countItemsInDatabase(at url: URL, type: String) async -> Int? {
		let directory = url.deletingLastPathComponent()
		let filename = url.deletingPathExtension().lastPathComponent

		do {
			guard let storage = SQLiteStorageEngine(
				directory: FileManager.Directory(url: directory),
				databaseFilename: filename
			) else {
				return nil
			}

			if type == "medications" {
				let store = try await Store<ANMedicationConcept>(
					storage: storage,
					cacheIdentifier: \ANMedicationConcept.id.uuidString
				)
				return store.items.count
			} else {
				let store = try await Store<ANEventConcept>(
					storage: storage,
					cacheIdentifier: \ANEventConcept.id.uuidString
				)
				return store.items.count
			}
		} catch {
			logger.debug("Could not count items in \(url.path): \(error.localizedDescription)")
			return nil
		}
	}

	private func loadDataFromLocation(_ url: URL) async throws -> (medications: [ANMedicationConcept], events: [ANEventConcept]) {
		var medications: [ANMedicationConcept] = []
		var events: [ANEventConcept] = []

		let fileManager = FileManager.default

		// Try direct paths first
		let directMedicationsPath = url.appendingPathComponent("\(StorageConstants.medicationsDBName).sqlite3")
		if fileManager.fileExists(atPath: directMedicationsPath.path) {
			if let storage = SQLiteStorageEngine(
				directory: FileManager.Directory(url: url),
				databaseFilename: StorageConstants.medicationsDBName
			) {
				let store = try await Store<ANMedicationConcept>(
					storage: storage,
					cacheIdentifier: \ANMedicationConcept.id.uuidString
				)
				medications = store.items
			}
		}

		let directEventsPath = url.appendingPathComponent("\(StorageConstants.eventsDBName).sqlite3")
		if fileManager.fileExists(atPath: directEventsPath.path) {
			if let storage = SQLiteStorageEngine(
				directory: FileManager.Directory(url: url),
				databaseFilename: StorageConstants.eventsDBName
			) {
				let store = try await Store<ANEventConcept>(
					storage: storage,
					cacheIdentifier: \ANEventConcept.id.uuidString
				)
				events = store.items
			}
		}

		// Try Bodega structure if direct paths didn't work
		if medications.isEmpty {
			let bodegaMedicationsDir = url.appendingPathComponent("\(StorageConstants.Legacy.medicationsDB).sqlite")
			if fileManager.fileExists(atPath: bodegaMedicationsDir.path) {
				if let storage = SQLiteStorageEngine(
					directory: FileManager.Directory(url: bodegaMedicationsDir),
					databaseFilename: "data"
				) {
					let store = try await Store<ANMedicationConcept>(
						storage: storage,
						cacheIdentifier: \ANMedicationConcept.id.uuidString
					)
					medications = store.items
				}
			}
		}

		if events.isEmpty {
			let bodegaEventsDir = url.appendingPathComponent("\(StorageConstants.Legacy.eventsDB).sqlite")
			if fileManager.fileExists(atPath: bodegaEventsDir.path) {
				if let storage = SQLiteStorageEngine(
					directory: FileManager.Directory(url: bodegaEventsDir),
					databaseFilename: "data"
				) {
					let store = try await Store<ANEventConcept>(
						storage: storage,
						cacheIdentifier: \ANEventConcept.id.uuidString
					)
					events = store.items
				}
			}
		}

		return (medications, events)
	}
}

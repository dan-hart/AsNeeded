// BackupManager.swift
// Automated backup system for pre-migration data protection
// Part of the Data Loss Prevention strategy - see CLAUDE.md "Dangerous Files Registry"

import DHLoggingKit
import Foundation

/// Manages automated backups of database files before migrations
///
/// Creates timestamped backup copies of databases to allow recovery
/// if a migration fails or corrupts data.
@MainActor
public final class BackupManager {
	public static let shared = BackupManager()
	private let logger = DHLogger.data
	private let appGroupURL: URL?
	private let now: () -> Date

	/// Result of a backup operation
	public struct BackupResult {
		public let success: Bool
		public let backupPath: URL?
		public let medicationsBackedUp: Bool
		public let eventsBackedUp: Bool
		public let timestamp: Date
		public let error: Error?
	}

	init(
		appGroupURL: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier),
		now: @escaping () -> Date = { Date() }
	) {
		self.appGroupURL = appGroupURL
		self.now = now
	}

	// MARK: - Public API

	/// Creates a timestamped backup of all databases before migration
	/// - Returns: BackupResult with path to backup directory
	public func createPreMigrationBackup() async -> BackupResult {
		let timestamp = now()
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyyMMdd_HHmmss"
		let timestampString = formatter.string(from: timestamp)

		logger.info("Creating pre-migration backup at \(timestampString)")

		guard let appGroupURL else {
			logger.error("❌ Cannot create backup - App Group unavailable")
			return BackupResult(
				success: false,
				backupPath: nil,
				medicationsBackedUp: false,
				eventsBackedUp: false,
				timestamp: timestamp,
				error: MigrationBackupError.appGroupUnavailable
			)
		}

		let backupDir = appGroupURL
			.appendingPathComponent(StorageConstants.backupDirectoryName)
			.appendingPathComponent("pre_migration_\(timestampString)_\(UUID().uuidString)")

		do {
			// Create backup directory
			try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
			logger.info("Created backup directory")

			var medicationsBackedUp = false
			var eventsBackedUp = false

			// Backup medications database
			let medicationsSource = appGroupURL.appendingPathComponent(StorageConstants.medicationsDBPath)
			if FileManager.default.fileExists(atPath: medicationsSource.path) {
				let medicationsDest = backupDir.appendingPathComponent(StorageConstants.medicationsDBPath)
				try FileManager.default.copyItem(at: medicationsSource, to: medicationsDest)
				medicationsBackedUp = true
				logger.info("✅ Backed up medications database")

				// Also backup WAL files if they exist
				try backupWALFiles(for: medicationsSource, to: backupDir, baseName: StorageConstants.medicationsDBName)
			}

			// Backup events database
			let eventsSource = appGroupURL.appendingPathComponent(StorageConstants.eventsDBPath)
			if FileManager.default.fileExists(atPath: eventsSource.path) {
				let eventsDest = backupDir.appendingPathComponent(StorageConstants.eventsDBPath)
				try FileManager.default.copyItem(at: eventsSource, to: eventsDest)
				eventsBackedUp = true
				logger.info("✅ Backed up events database")

				// Also backup WAL files if they exist
				try backupWALFiles(for: eventsSource, to: backupDir, baseName: StorageConstants.eventsDBName)
			}

			// Clean up old backups
			await cleanupOldBackups(in: appGroupURL.appendingPathComponent(StorageConstants.backupDirectoryName))

			logger.info("Pre-migration backup complete")
			return BackupResult(
				success: true,
				backupPath: backupDir,
				medicationsBackedUp: medicationsBackedUp,
				eventsBackedUp: eventsBackedUp,
				timestamp: timestamp,
				error: nil
			)

		} catch {
			logger.logPrivacySafeError("❌ Backup failed", error: error)
			return BackupResult(
				success: false,
				backupPath: nil,
				medicationsBackedUp: false,
				eventsBackedUp: false,
				timestamp: timestamp,
				error: error
			)
		}
	}

	/// Lists all available backups
	/// - Returns: Array of backup URLs sorted by date (newest first)
	public func listBackups() -> [URL] {
		guard let appGroupURL else {
			return []
		}

		let backupDir = appGroupURL.appendingPathComponent(StorageConstants.backupDirectoryName)

		guard FileManager.default.fileExists(atPath: backupDir.path) else {
			return []
		}

		do {
			let contents = try FileManager.default.contentsOfDirectory(
				at: backupDir,
				includingPropertiesForKeys: [.creationDateKey],
				options: [.skipsHiddenFiles]
			)

			// Sort by creation date, newest first
			return contents.sorted { url1, url2 in
				let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
				let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
				return date1 > date2
			}
		} catch {
			logger.logPrivacySafeError("Failed to list backups", error: error)
			return []
		}
	}

	/// Restores data from a specific backup
	/// - Parameter backupURL: URL to the backup directory
	/// - Returns: True if restore succeeded
	/// - Important: Restore migration files before opening Boutique stores. Existing
	///   store connections and in-memory caches are not refreshed by file replacement.
	public func restoreFromBackup(at backupURL: URL) async throws -> Bool {
		logger.info("Restoring from backup")

		guard let appGroupURL else {
			throw MigrationBackupError.appGroupUnavailable
		}

		// Verify backup exists
		guard FileManager.default.fileExists(atPath: backupURL.path) else {
			throw MigrationBackupError.backupNotFound
		}
		let fileManager = FileManager.default
		guard fileManager.fileExists(atPath: backupURL.appendingPathComponent(StorageConstants.medicationsDBPath).path) ||
			fileManager.fileExists(atPath: backupURL.appendingPathComponent(StorageConstants.eventsDBPath).path) else {
			throw MigrationBackupError.backupNotFound
		}

		// Creating the safety backup runs retention cleanup. Pin the requested
		// snapshot first so restoring the oldest backup cannot delete its own source.
		let restoreSource = fileManager.temporaryDirectory.appendingPathComponent("AsNeededRestore-\(UUID().uuidString)")
		try fileManager.createDirectory(at: restoreSource, withIntermediateDirectories: true)
		defer { try? fileManager.removeItem(at: restoreSource) }
		for name in [StorageConstants.medicationsDBPath, StorageConstants.eventsDBPath] {
			for suffix in ["", "-wal", "-shm"] {
				let source = backupURL.appendingPathComponent(name + suffix)
				if fileManager.fileExists(atPath: source.path) {
					try fileManager.copyItem(at: source, to: restoreSource.appendingPathComponent(name + suffix))
				}
			}
		}
		let medicationsBackup = restoreSource.appendingPathComponent(StorageConstants.medicationsDBPath)
		let eventsBackup = restoreSource.appendingPathComponent(StorageConstants.eventsDBPath)

		// First, create a backup of current state before restoring
		let preRestoreBackup = await createPreMigrationBackup()
		guard preRestoreBackup.success else {
			logger.error("Could not create safety backup; restore stopped before replacement")
			throw preRestoreBackup.error ?? MigrationBackupError.restoreFailed("Could not back up current data")
		}

		// Restore medications (using atomic replace for safety)
		let medicationsDest = appGroupURL.appendingPathComponent(StorageConstants.medicationsDBPath)

		if FileManager.default.fileExists(atPath: medicationsBackup.path) {
			try atomicRestore(from: medicationsBackup, to: medicationsDest)
			logger.info("✅ Restored medications database")

			// Also restore WAL/SHM files if they exist in backup
			try restoreWALFiles(from: restoreSource, to: appGroupURL, baseName: StorageConstants.medicationsDBName)
		}

		// Restore events (using atomic replace for safety)
		let eventsDest = appGroupURL.appendingPathComponent(StorageConstants.eventsDBPath)

		if FileManager.default.fileExists(atPath: eventsBackup.path) {
			try atomicRestore(from: eventsBackup, to: eventsDest)
			logger.info("✅ Restored events database")

			// Also restore WAL/SHM files if they exist in backup
			try restoreWALFiles(from: restoreSource, to: appGroupURL, baseName: StorageConstants.eventsDBName)
		}

		logger.info("Restore complete")
		return true
	}

	/// Performs atomic file restore: copy to temp, then atomic replace
	/// This prevents data loss if the app crashes mid-restore
	private func atomicRestore(from source: URL, to destination: URL) throws {
		let fileManager = FileManager.default
		let tempDest = destination.appendingPathExtension("restoring")

		// Clean up any leftover temp file from previous failed restore
		if fileManager.fileExists(atPath: tempDest.path) {
			try? fileManager.removeItem(at: tempDest)
		}

		// Copy backup to temp location first
		try fileManager.copyItem(at: source, to: tempDest)

		// If destination exists, use atomic replace
		if fileManager.fileExists(atPath: destination.path) {
			// replaceItemAt atomically replaces the destination with the source
			_ = try fileManager.replaceItemAt(destination, withItemAt: tempDest)
		} else {
			// No existing file, just move the temp file
			try fileManager.moveItem(at: tempDest, to: destination)
		}
	}

	/// Restores WAL and SHM files from backup if they exist
	private func restoreWALFiles(from backupDir: URL, to destDir: URL, baseName: String) throws {
		let fileManager = FileManager.default
		let walBackup = backupDir.appendingPathComponent("\(baseName)\(StorageConstants.databaseExtension)-wal")
		let shmBackup = backupDir.appendingPathComponent("\(baseName)\(StorageConstants.databaseExtension)-shm")
		let walDest = destDir.appendingPathComponent("\(baseName)\(StorageConstants.databaseExtension)-wal")
		let shmDest = destDir.appendingPathComponent("\(baseName)\(StorageConstants.databaseExtension)-shm")

		// Restore WAL file
		if fileManager.fileExists(atPath: walBackup.path) {
			if fileManager.fileExists(atPath: walDest.path) {
				try fileManager.removeItem(at: walDest)
			}
			try fileManager.copyItem(at: walBackup, to: walDest)
			logger.info("Restored WAL file for \(baseName)")
		} else {
			// If no WAL in backup but there's one in dest, remove it to ensure consistency
			if fileManager.fileExists(atPath: walDest.path) {
				try? fileManager.removeItem(at: walDest)
				logger.info("Removed orphan WAL file for \(baseName)")
			}
		}

		// Restore SHM file
		if fileManager.fileExists(atPath: shmBackup.path) {
			if fileManager.fileExists(atPath: shmDest.path) {
				try fileManager.removeItem(at: shmDest)
			}
			try fileManager.copyItem(at: shmBackup, to: shmDest)
			logger.info("Restored SHM file for \(baseName)")
		} else {
			// If no SHM in backup but there's one in dest, remove it to ensure consistency
			if fileManager.fileExists(atPath: shmDest.path) {
				try? fileManager.removeItem(at: shmDest)
				logger.info("Removed orphan SHM file for \(baseName)")
			}
		}
	}

	// MARK: - Private Helpers

	private func backupWALFiles(for databaseURL: URL, to backupDir: URL, baseName: String) throws {
		let walPath = databaseURL.path + "-wal"
		let shmPath = databaseURL.path + "-shm"

		if FileManager.default.fileExists(atPath: walPath) {
			let walDest = backupDir.appendingPathComponent("\(baseName)\(StorageConstants.databaseExtension)-wal")
			try FileManager.default.copyItem(atPath: walPath, toPath: walDest.path)
			logger.info("Backed up WAL file for \(baseName)")
		}

		if FileManager.default.fileExists(atPath: shmPath) {
			let shmDest = backupDir.appendingPathComponent("\(baseName)\(StorageConstants.databaseExtension)-shm")
			try FileManager.default.copyItem(atPath: shmPath, toPath: shmDest.path)
			logger.info("Backed up SHM file for \(baseName)")
		}
	}

	private func cleanupOldBackups(in backupDir: URL) async {
		let backups = listBackups()
		let maxBackups = StorageConstants.maxBackupRetention

		guard backups.count > maxBackups else { return }

		logger.info("Cleaning up old backups (keeping \(maxBackups), have \(backups.count))")

		// Remove oldest backups beyond retention limit
		for backup in backups.dropFirst(maxBackups) {
			do {
				try FileManager.default.removeItem(at: backup)
				logger.info("Removed old backup")
			} catch {
				logger.logPrivacySafeError("Failed to remove old backup", error: error)
			}
		}
	}
}

// MARK: - Errors

enum MigrationBackupError: LocalizedError {
	case appGroupUnavailable
	case backupNotFound
	case restoreFailed(String)

	var errorDescription: String? {
		switch self {
		case .appGroupUnavailable:
			return "App Group container is unavailable"
		case .backupNotFound:
			return "Backup not found at specified location"
		case let .restoreFailed(reason):
			return "Restore failed: \(reason)"
		}
	}
}

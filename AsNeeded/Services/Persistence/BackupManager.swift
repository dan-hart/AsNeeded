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

	/// Result of a backup operation
	public struct BackupResult {
		public let success: Bool
		public let backupPath: URL?
		public let medicationsBackedUp: Bool
		public let eventsBackedUp: Bool
		public let timestamp: Date
		public let error: Error?
	}

	private init() {}

	// MARK: - Public API

	/// Creates a timestamped backup of all databases before migration
	/// - Returns: BackupResult with path to backup directory
	public func createPreMigrationBackup() async -> BackupResult {
		let timestamp = Date()
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyyMMdd_HHmmss"
		let timestampString = formatter.string(from: timestamp)

		logger.info("Creating pre-migration backup at \(timestampString)")

		guard let appGroupURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier
		) else {
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
			.appendingPathComponent("pre_migration_\(timestampString)")

		do {
			// Create backup directory
			try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
			logger.info("Created backup directory: \(backupDir.path)")

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

			logger.info("Pre-migration backup complete at: \(backupDir.path)")
			return BackupResult(
				success: true,
				backupPath: backupDir,
				medicationsBackedUp: medicationsBackedUp,
				eventsBackedUp: eventsBackedUp,
				timestamp: timestamp,
				error: nil
			)

		} catch {
			logger.error("❌ Backup failed: \(error.localizedDescription)")
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
		guard let appGroupURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier
		) else {
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
			logger.error("Failed to list backups: \(error.localizedDescription)")
			return []
		}
	}

	/// Restores data from a specific backup
	/// - Parameter backupURL: URL to the backup directory
	/// - Returns: True if restore succeeded
	public func restoreFromBackup(at backupURL: URL) async throws -> Bool {
		logger.info("Restoring from backup: \(backupURL.path)")

		guard let appGroupURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier
		) else {
			throw MigrationBackupError.appGroupUnavailable
		}

		// Verify backup exists
		guard FileManager.default.fileExists(atPath: backupURL.path) else {
			throw MigrationBackupError.backupNotFound
		}

		// First, create a backup of current state before restoring
		let preRestoreBackup = await createPreMigrationBackup()
		if !preRestoreBackup.success {
			logger.warning("Could not create pre-restore backup, proceeding anyway")
		}

		// Restore medications (using atomic replace for safety)
		let medicationsBackup = backupURL.appendingPathComponent(StorageConstants.medicationsDBPath)
		let medicationsDest = appGroupURL.appendingPathComponent(StorageConstants.medicationsDBPath)

		if FileManager.default.fileExists(atPath: medicationsBackup.path) {
			try atomicRestore(from: medicationsBackup, to: medicationsDest)
			logger.info("✅ Restored medications database")

			// Also restore WAL/SHM files if they exist in backup
			try restoreWALFiles(from: backupURL, to: appGroupURL, baseName: StorageConstants.medicationsDBName)
		}

		// Restore events (using atomic replace for safety)
		let eventsBackup = backupURL.appendingPathComponent(StorageConstants.eventsDBPath)
		let eventsDest = appGroupURL.appendingPathComponent(StorageConstants.eventsDBPath)

		if FileManager.default.fileExists(atPath: eventsBackup.path) {
			try atomicRestore(from: eventsBackup, to: eventsDest)
			logger.info("✅ Restored events database")

			// Also restore WAL/SHM files if they exist in backup
			try restoreWALFiles(from: backupURL, to: appGroupURL, baseName: StorageConstants.eventsDBName)
		}

		logger.info("Restore complete from: \(backupURL.path)")
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
				logger.info("Removed old backup: \(backup.lastPathComponent)")
			} catch {
				logger.error("Failed to remove old backup: \(error.localizedDescription)")
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

// MigrationCoordinator.swift
// Coordinates data migration on app launch to prevent race conditions

import DHLoggingKit
import Foundation
import SwiftUI

/// Coordinates data migration to ensure it completes before app UI loads
/// This prevents the race condition where users see empty state while migration runs
@MainActor
@Observable
public final class MigrationCoordinator {
	public static let shared = MigrationCoordinator()

	private let logger = DHLogger.data

	/// Whether migration has completed (successfully or with error)
	public private(set) var isComplete = false

	/// Whether migration is currently running
	public private(set) var isRunning = false

	/// Error that occurred during migration, if any
	public private(set) var error: Error?

	/// Whether migration has failed (has error and not running)
	public var hasFailed: Bool {
		error != nil && !isRunning
	}

	/// When migration started (for timeout detection)
	private var migrationStartTime: Date?

	private init() {}

	/// Logs current migration state (for diagnostics)
	public func logCurrentState() {
		logger.info("Migration State - isComplete: \(isComplete), isRunning: \(isRunning), errorType: \(DHLogger.privacySafeErrorType(error))")
		if let startTime = migrationStartTime {
			let elapsed = Date().timeIntervalSince(startTime)
			logger.info("Migration elapsed time: \(String(format: "%.1f", elapsed))s")
		}
	}

	/// Runs migration if needed
	/// Should be called on app launch before showing main UI
	public func runMigrationIfNeeded() async {
		// Already completed or running
		guard !isComplete && !isRunning else {
			logger.info("Migration already completed or running, skipping")
			return
		}

		isRunning = true
		migrationStartTime = Date()
		logger.info("Starting migration coordinator")

		// Check schema version
		let currentVersion = UserDefaults.standard.integer(forKey: UserDefaultsKeys.storageSchemaVersion)
		let targetVersion = StorageConstants.currentStorageVersion
		logger.info("Storage schema version: current=\(currentVersion), target=\(targetVersion)")

		// Pre-flight health check
		logger.info("Running pre-flight storage health check...")
		let healthChecker = StorageHealthChecker()
		let healthResult = healthChecker.performHealthCheck()

		if !healthResult.isHealthy {
			logger.error("❌ Storage health check failed - see issues above")
			let healthError = StorageHealthError.unhealthyStorage(issues: healthResult.issueMessages)
			self.error = healthError
			isComplete = false
			isRunning = false
			return
		}

		logger.info("✅ Storage health check passed - proceeding with migration")


		// Start timeout watchdog
		let watchdogTask = Task {
			try? await Task.sleep(for: .seconds(30))
			if isRunning && !isComplete {
				logger.warning("⚠️ Migration still running after 30 seconds - possible hang")
				logCurrentState()
			}
		}

		// Run the migration
		do {
			try await DataStore.shared.recoverAndMigrateLegacy {
				// Recover first and hold ownership across backup and migration so another
				// candidate process cannot change one database between the two copies.
				if currentVersion < targetVersion || currentVersion == 0 {
					let backup = await BackupManager.shared.createPreMigrationBackup()
					guard backup.success else { throw MigrationBackupFailure(underlyingError: backup.error) }
				}
				try await DataMigrationManager().migrateIfNeeded()
			}
			// Finish model-field migration before any editing or dose logging UI appears.
			try await MedicationDoseLimitMigration().migrate(dataStore: .shared)

			// Update schema version after successful migration
			if currentVersion < targetVersion {
				UserDefaults.standard.set(targetVersion, forKey: UserDefaultsKeys.storageSchemaVersion)
				logger.info("Updated storage schema version: \(currentVersion) → \(targetVersion)")
			}

			let duration = Date().timeIntervalSince(migrationStartTime ?? Date())
			logger.info("Migration completed successfully in \(String(format: "%.1f", duration))s")
			isComplete = true
			isRunning = false
		} catch {
			logger.logPrivacySafeError("Migration failed", error: error)
			self.error = error
			isComplete = false
			isRunning = false
		}

		// Cancel watchdog
		watchdogTask.cancel()
	}

	/// Retries migration after a failure
	/// Clears error state and runs migration again
	public func retry() async {
		logger.info("Retrying migration after previous failure")
		error = nil
		isComplete = false
		await runMigrationIfNeeded()
	}

	/// Resets migration state (for testing only)
	public func reset() {
		isComplete = false
		isRunning = false
		error = nil
	}
}

// MARK: - Errors

/// Errors that can occur during storage health checks
enum StorageHealthError: LocalizedError {
	case unhealthyStorage(issues: [String])

	var errorDescription: String? {
		switch self {
		case let .unhealthyStorage(issues):
			if issues.isEmpty {
				return String(localized: "Storage system is unhealthy")
			}
			return String(localized: "Storage system issues detected:\n") + issues.map { String(localized: "• \($0)") }.joined(separator: "\n")
		}
	}
}

/// Error when pre-migration backup fails
struct MigrationBackupFailure: LocalizedError {
	let underlyingError: Error?

	var errorDescription: String? {
		if let underlying = underlyingError {
			return String(localized: "Pre-migration backup failed: \(underlying.localizedDescription). Migration cannot proceed without backup protection.")
		}
		return String(localized: "Pre-migration backup failed. Migration cannot proceed without backup protection.")
	}
}

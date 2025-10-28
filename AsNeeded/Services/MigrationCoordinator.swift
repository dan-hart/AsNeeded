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

	private init() {}

	/// Runs migration if needed
	/// Should be called on app launch before showing main UI
	public func runMigrationIfNeeded() async {
		// Already completed or running
		guard !isComplete && !isRunning else {
			logger.info("Migration already completed or running, skipping")
			return
		}

		isRunning = true
		logger.info("Starting migration coordinator")

		do {
			// Run the migration
			await DataMigrationManager().migrateIfNeeded()

			logger.info("Migration completed successfully")
			isComplete = true
			isRunning = false

		} catch {
			logger.error("Migration failed: \(error.localizedDescription)")
			self.error = error
			isComplete = true // Mark complete even on error to unblock UI
			isRunning = false
		}
	}

	/// Resets migration state (for testing only)
	public func reset() {
		isComplete = false
		isRunning = false
		error = nil
	}
}

// StorageConstants.swift
// Centralized storage-related constants to prevent data loss from scattered hardcoded values
//
// WARNING: This is a DANGEROUS FILE - see CLAUDE.md "Dangerous Files Registry"
// ANY changes to these values can cause DATA LOSS for users.
// Before modifying:
// 1. Read docs/DATA_STORAGE_GUIDELINES.md
// 2. Verify migration exists for the change
// 3. Test on physical device with real data

import Foundation

/// Centralized storage constants for the app
///
/// All storage-related paths, identifiers, and configuration values should be defined here
/// to ensure changes are atomic and dependencies are explicit.
///
/// ## Version History
/// - v1: Default app container (pre-October 2025)
/// - v2: App Group container (October 2025 - current)
///
/// ## Critical: Changing any value here requires:
/// 1. New migration in DataMigrationManager
/// 2. Update to DATA_STORAGE_GUIDELINES.md
/// 3. Physical device testing with real user data
enum StorageConstants {
	// MARK: - App Group Configuration
	/// App Group identifier for shared storage with widgets and extensions
	///
	/// - Warning: Changing this value WILL cause data loss without proper migration
	static let appGroupIdentifier = "group.com.codedbydan.AsNeeded"

	// MARK: - Database Names
	/// Medications database filename (without extension)
	///
	/// SQLiteStorageEngine.default() adds `.sqlite3` extension automatically
	static let medicationsDBName = "medications"

	/// Events database filename (without extension)
	///
	/// SQLiteStorageEngine.default() adds `.sqlite3` extension automatically
	static let eventsDBName = "events"

	/// Database file extension used by SQLiteStorageEngine
	static let databaseExtension = ".sqlite3"

	// MARK: - Computed Database Paths
	/// Full filename for medications database (name + extension)
	/// Use this instead of manually appending ".sqlite3" to prevent path drift
	static var medicationsDBPath: String { "\(medicationsDBName)\(databaseExtension)" }

	/// Full filename for events database (name + extension)
	/// Use this instead of manually appending ".sqlite3" to prevent path drift
	static var eventsDBPath: String { "\(eventsDBName)\(databaseExtension)" }

	// MARK: - Schema Versioning
	/// Current storage schema version
	///
	/// Increment this value when making ANY change to:
	/// - Storage paths
	/// - Database structure
	/// - File formats
	///
	/// Each increment requires a corresponding migration in MigrationRegistry
	static let currentStorageVersion = 2

	/// UserDefaults key for tracking storage schema version
	static let storageVersionKey = "asneeded_storage_schema_version"

	// MARK: - Health Check Configuration
	/// Minimum required disk space in MB for safe operation
	static let minimumDiskSpaceMB: Double = 50.0

	// MARK: - Legacy Paths (for migration reference)
	/// Legacy storage locations from previous app versions
	///
	/// These paths are used by DataMigrationManager to find and migrate orphaned data.
	/// DO NOT REMOVE these constants - they are needed for data recovery.
	enum Legacy {
		/// Bundle identifier used in legacy Application Support path
		static let bundleIdentifier = "com.codedbydan.AsNeeded"

		/// Legacy medications database name (Bodega format)
		static let medicationsDB = "medications"

		/// Legacy events database name (Bodega format)
		static let eventsDB = "events"

		/// Bodega SQLite filename within the folder structure
		/// Legacy path pattern: Documents/{name}.sqlite/data.sqlite3
		static let bodegaDataFile = "data.sqlite3"

		/// Known legacy file extensions to search
		static let knownExtensions = [".sqlite3", ".sqlite", ".db", ""]
	}

	// MARK: - Backup Configuration
	/// Directory name for pre-migration backups
	static let backupDirectoryName = "data_backups"

	/// Maximum number of backups to retain
	static let maxBackupRetention = 5
}

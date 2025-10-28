// StorageDiagnosticViewModel.swift
// View model for diagnosing storage location and data migration issues.

import DHLoggingKit
import Foundation
import SwiftUI

/// Diagnostic information about a storage location
struct StorageLocationInfo {
	let name: String
	let path: String
	let exists: Bool
	let medicationsDBSize: Int64?
	let eventsDBSize: Int64?
	let medicationsCount: Int?
	let eventsCount: Int?
	let isCurrentLocation: Bool
	let filesInDirectory: [String]  // NEW: List all files in directory
}

@MainActor
final class StorageDiagnosticViewModel: ObservableObject {
	private let logger = DHLogger(category: "StorageDiagnostic")

	@Published var isLoading = false
	@Published var legacyLocation: StorageLocationInfo?
	@Published var appGroupLocation: StorageLocationInfo?
	@Published var migrationCompleted: Bool = false
	@Published var bundleIdentifier: String = ""
	@Published var currentContainerType: String = "Unknown"
	@Published var alertMessage: String?
	@Published var showingAlert = false

	// Migration state
	@Published var isMigrating = false
	@Published var showingMigrationConfirmation = false
	@Published var migrationError: String?
	@Published var showingMigrationSuccess = false

	init() {
		refreshDiagnostics()
	}

	// MARK: - Public Methods

	/// Refreshes all diagnostic information
	func refreshDiagnostics() {
		isLoading = true
		logger.info("Starting storage diagnostics...")

		Task {
			defer { isLoading = false }

			// Get bundle identifier
			bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"

			// Check migration status
			migrationCompleted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.dataMigrationCompleted)

			// Analyze legacy location
			legacyLocation = await analyzeLegacyLocation()

			// Analyze App Group location
			appGroupLocation = await analyzeAppGroupLocation()

			// Determine current container type
			if let appGroupPath = appGroupLocation?.path,
			   FileManager.default.fileExists(atPath: appGroupPath) {
				currentContainerType = "App Group"
			} else if let legacyPath = legacyLocation?.path,
					  FileManager.default.fileExists(atPath: legacyPath) {
				currentContainerType = "Legacy (Default Container)"
			} else {
				currentContainerType = "Unknown"
			}

			logger.info("Storage diagnostics completed - Legacy exists: \(legacyLocation?.exists ?? false), App Group exists: \(appGroupLocation?.exists ?? false)")
		}
	}

	/// Exports diagnostic report as text
	func exportReport() -> String {
		var report = """
		Storage Diagnostic Report
		========================
		Generated: \(Date().formatted())
		Bundle ID: \(bundleIdentifier)
		Migration Completed: \(migrationCompleted ? "Yes" : "No")
		Current Container: \(currentContainerType)

		"""

		if let legacy = legacyLocation {
			report += """

			Legacy Storage Location (Default App Container)
			-----------------------------------------------
			Path: \(legacy.path)
			Exists: \(legacy.exists ? "Yes" : "No")
			Medications DB Size: \(formatFileSize(legacy.medicationsDBSize))
			Events DB Size: \(formatFileSize(legacy.eventsDBSize))
			Medications Count: \(legacy.medicationsCount.map(String.init) ?? "N/A")
			Events Count: \(legacy.eventsCount.map(String.init) ?? "N/A")
			Is Current Location: \(legacy.isCurrentLocation ? "Yes" : "No")

			Files in Directory (\(legacy.filesInDirectory.count)):
			\(legacy.filesInDirectory.isEmpty ? "  (empty)" : legacy.filesInDirectory.map { "  • \($0)" }.joined(separator: "\n"))

			"""
		}

		if let appGroup = appGroupLocation {
			report += """

			App Group Storage Location
			--------------------------
			Path: \(appGroup.path)
			Exists: \(appGroup.exists ? "Yes" : "No")
			Medications DB Size: \(formatFileSize(appGroup.medicationsDBSize))
			Events DB Size: \(formatFileSize(appGroup.eventsDBSize))
			Medications Count: \(appGroup.medicationsCount.map(String.init) ?? "N/A")
			Events Count: \(appGroup.eventsCount.map(String.init) ?? "N/A")
			Is Current Location: \(appGroup.isCurrentLocation ? "Yes" : "No")

			Files in Directory (\(appGroup.filesInDirectory.count)):
			\(appGroup.filesInDirectory.isEmpty ? "  (empty)" : appGroup.filesInDirectory.map { "  • \($0)" }.joined(separator: "\n"))

			"""
		}

		return report
	}

	/// Manually triggers data migration from legacy to App Group storage
	func runManualMigration() {
		logger.info("User initiated manual migration")
		isMigrating = true
		migrationError = nil

		Task {
			defer { isMigrating = false }

			do {
				// Reset migration flag to allow re-run
				UserDefaults.standard.set(false, forKey: UserDefaultsKeys.dataMigrationCompleted)
				logger.info("Reset migration flag - ready to migrate")

				// Run migration
				await DataMigrationManager().migrateIfNeeded()

				logger.info("Manual migration completed successfully")
				showingMigrationSuccess = true

				// Refresh diagnostics to show new state
				refreshDiagnostics()

			} catch {
				logger.error("Manual migration failed: \(error.localizedDescription)")
				migrationError = error.localizedDescription
				showingAlert = true
			}
		}
	}

	// MARK: - Private Helpers

	private func analyzeLegacyLocation() async -> StorageLocationInfo {
		guard let appSupportURL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first else {
			logger.warning("Unable to determine legacy storage path")
			return StorageLocationInfo(
				name: "Legacy Storage",
				path: "Unknown",
				exists: false,
				medicationsDBSize: nil,
				eventsDBSize: nil,
				medicationsCount: nil,
				eventsCount: nil,
				isCurrentLocation: false,
				filesInDirectory: []
			)
		}

		// List all files in directory
		let filesInDir = (try? FileManager.default.contentsOfDirectory(atPath: appSupportURL.path)) ?? []

		// Check for database files (with and without .sqlite extension)
		let medicationsPath = appSupportURL.appendingPathComponent("medications.sqlite").path
		let eventsPath = appSupportURL.appendingPathComponent("events.sqlite").path
		let medicationsPathNoExt = appSupportURL.appendingPathComponent("medications").path
		let eventsPathNoExt = appSupportURL.appendingPathComponent("events").path

		let medExists = FileManager.default.fileExists(atPath: medicationsPath) ||
						FileManager.default.fileExists(atPath: medicationsPathNoExt)
		let eventsExists = FileManager.default.fileExists(atPath: eventsPath) ||
						   FileManager.default.fileExists(atPath: eventsPathNoExt)

		// Get sizes (try both with and without extension)
		var medSize = getFileSize(atPath: medicationsPath)
		if medSize == nil {
			medSize = getFileSize(atPath: medicationsPathNoExt)
		}
		var eventsSize = getFileSize(atPath: eventsPath)
		if eventsSize == nil {
			eventsSize = getFileSize(atPath: eventsPathNoExt)
		}

		return StorageLocationInfo(
			name: "Legacy Storage",
			path: appSupportURL.path,
			exists: medExists || eventsExists,
			medicationsDBSize: medSize,
			eventsDBSize: eventsSize,
			medicationsCount: nil, // Would require loading database
			eventsCount: nil,
			isCurrentLocation: false, // Legacy is never current after migration
			filesInDirectory: filesInDir
		)
	}

	private func analyzeAppGroupLocation() async -> StorageLocationInfo {
		guard let sharedContainerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: "group.com.codedbydan.AsNeeded"
		) else {
			logger.warning("Unable to access App Group container")
			return StorageLocationInfo(
				name: "App Group Storage",
				path: "Unavailable",
				exists: false,
				medicationsDBSize: nil,
				eventsDBSize: nil,
				medicationsCount: nil,
				eventsCount: nil,
				isCurrentLocation: false,
				filesInDirectory: []
			)
		}

		// List all files in directory
		let filesInDir = (try? FileManager.default.contentsOfDirectory(atPath: sharedContainerURL.path)) ?? []
		logger.info("App Group directory contains \(filesInDir.count) files: \(filesInDir.joined(separator: ", "))")

		// Check for database files (with and without .sqlite extension)
		let medicationsPath = sharedContainerURL.appendingPathComponent("medications.sqlite").path
		let eventsPath = sharedContainerURL.appendingPathComponent("events.sqlite").path
		let medicationsPathNoExt = sharedContainerURL.appendingPathComponent("medications").path
		let eventsPathNoExt = sharedContainerURL.appendingPathComponent("events").path

		let medExists = FileManager.default.fileExists(atPath: medicationsPath) ||
						FileManager.default.fileExists(atPath: medicationsPathNoExt)
		let eventsExists = FileManager.default.fileExists(atPath: eventsPath) ||
						   FileManager.default.fileExists(atPath: eventsPathNoExt)

		logger.info("Database file check - medications: \(medExists), events: \(eventsExists)")

		// Get sizes (try both with and without extension)
		var medSize = getFileSize(atPath: medicationsPath)
		if medSize == nil {
			medSize = getFileSize(atPath: medicationsPathNoExt)
		}
		var eventsSize = getFileSize(atPath: eventsPath)
		if eventsSize == nil {
			eventsSize = getFileSize(atPath: eventsPathNoExt)
		}

		// Get actual counts from DataStore (which should be using App Group)
		let dataStore = DataStore.shared
		let medCount = dataStore.medications.count
		let eventsCount = dataStore.events.count

		logger.info("DataStore reports: \(medCount) medications, \(eventsCount) events")

		return StorageLocationInfo(
			name: "App Group Storage",
			path: sharedContainerURL.path,
			exists: medExists || eventsExists,
			medicationsDBSize: medSize,
			eventsDBSize: eventsSize,
			medicationsCount: medCount, // Always show count from DataStore
			eventsCount: eventsCount, // Always show count from DataStore
			isCurrentLocation: true, // App Group should be current location
			filesInDirectory: filesInDir
		)
	}

	private func getFileSize(atPath path: String) -> Int64? {
		guard FileManager.default.fileExists(atPath: path),
		      let attributes = try? FileManager.default.attributesOfItem(atPath: path),
		      let fileSize = attributes[.size] as? Int64 else {
			return nil
		}
		return fileSize
	}

	private func formatFileSize(_ bytes: Int64?) -> String {
		guard let bytes = bytes else { return "N/A" }

		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
}

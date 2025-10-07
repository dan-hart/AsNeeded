// HealthKitMigrationManager.swift
// Manages one-time data migration between AsNeeded and HealthKit.

import Foundation
import ANModelKit
#if canImport(ANModelKitHealthKit)
import ANModelKitHealthKit
#endif
import DHLoggingKit

/// Manages data migration operations between AsNeeded and HealthKit
@MainActor
final class HealthKitMigrationManager: ObservableObject {
	static let shared = HealthKitMigrationManager()

	private let logger = DHLogger(category: "HealthKitMigration")
	private let dataStore: DataStore
	private let syncManager: HealthKitSyncManager

	init(dataStore: DataStore = .shared, syncManager: HealthKitSyncManager = .shared) {
		self.dataStore = dataStore
		self.syncManager = syncManager
	}

	// MARK: - Migration Status

	/// Check if there's data to migrate in either direction
	func getMigrationSuggestion() async -> HealthKitMigrationDirection? {
		let hasLocalData = !dataStore.medications.isEmpty || !dataStore.events.isEmpty

		#if canImport(ANModelKitHealthKit)
		// Check if there's data in HealthKit
		let queryHelper = ANHealthKitQuery()
		do {
			let hkMedications = try await queryHelper.fetchActiveMedications()
			let hasHealthKitData = !hkMedications.isEmpty

			// Suggest migration based on where data exists
			if hasLocalData && !hasHealthKitData {
				return .toHealthKit
			} else if !hasLocalData && hasHealthKitData {
				return .toAsNeeded
			} else if hasLocalData && hasHealthKitData {
				// Both have data - let user choose
				return nil
			} else {
				// Neither has data - skip
				return .skip
			}
		} catch {
			logger.error("Failed to check HealthKit data", error: error)
			return hasLocalData ? .toHealthKit : .skip
		}
		#else
		return hasLocalData ? .toHealthKit : .skip
		#endif
	}

	// MARK: - Migration Operations

	/// Perform data migration in the specified direction
	func performMigration(
		direction: HealthKitMigrationDirection,
		progressHandler: ((Double, String) -> Void)? = nil
	) async throws -> HealthKitMigrationResult {
		logger.info("Starting migration: \(direction.displayName)")

		let startTime = Date()

		switch direction {
		case .toHealthKit:
			return try await migrateToHealthKit(progressHandler: progressHandler)
		case .toAsNeeded:
			return try await migrateToAsNeeded(progressHandler: progressHandler)
		case .skip:
			// No migration needed
			let duration = Date().timeIntervalSince(startTime)
			return HealthKitMigrationResult(
				medicationsMigrated: 0,
				eventsMigrated: 0,
				success: true,
				errors: [],
				duration: duration
			)
		}
	}

	// MARK: - Migration to HealthKit

	/// Migrate all local data to HealthKit
	private func migrateToHealthKit(
		progressHandler: ((Double, String) -> Void)?
	) async throws -> HealthKitMigrationResult {
		#if canImport(ANModelKitHealthKit)
		guard syncManager.isHealthKitAvailable else {
			throw HealthKitSyncError.healthKitNotAvailable
		}

		let startTime = Date()
		var errors: [Error] = []

		// Get local data
		let localMedications = dataStore.medications
		let localEvents = dataStore.events

		progressHandler?(0.1, "Preparing migration...")
		logger.info("Migrating \(localMedications.count) medications and \(localEvents.count) events to HealthKit")

		// Note: HealthKit medications are typically managed in the Health app
		// We'll focus on migrating dose events

		var eventsMigrated = 0
		let totalEvents = localEvents.count

		progressHandler?(0.2, "Migrating dose events...")

		// Push events to HealthKit in batches
		let batchSize = 50
		for (index, batch) in localEvents.chunked(into: batchSize).enumerated() {
			do {
				let syncHelper = ANHealthKitSync()
				_ = try await syncHelper.pushToHealthKit(events: Array(batch))
				eventsMigrated += batch.count

				let progress = 0.2 + (Double(eventsMigrated) / Double(totalEvents)) * 0.7
				progressHandler?(progress, "Migrated \(eventsMigrated) of \(totalEvents) dose events...")

			} catch {
				logger.error("Failed to migrate batch \(index)", error: error)
				errors.append(error)
			}
		}

		progressHandler?(0.95, "Finalizing migration...")

		let duration = Date().timeIntervalSince(startTime)
		progressHandler?(1.0, "Migration complete")

		logger.info("Migration to HealthKit completed: \(eventsMigrated) events")

		return HealthKitMigrationResult(
			medicationsMigrated: localMedications.count,
			eventsMigrated: eventsMigrated,
			success: errors.isEmpty,
			errors: errors,
			duration: duration
		)
		#else
		throw HealthKitSyncError.healthKitNotAvailable
		#endif
	}

	// MARK: - Migration to AsNeeded

	/// Migrate all HealthKit data to local storage
	private func migrateToAsNeeded(
		progressHandler: ((Double, String) -> Void)?
	) async throws -> HealthKitMigrationResult {
		#if canImport(ANModelKitHealthKit)
		guard syncManager.isHealthKitAvailable else {
			throw HealthKitSyncError.healthKitNotAvailable
		}

		let startTime = Date()
		var errors: [Error] = []

		progressHandler?(0.1, "Fetching HealthKit data...")

		// Fetch medications from HealthKit
		let queryHelper = ANHealthKitQuery()
		let hkMedications = try await queryHelper.fetchAllMedications()

		progressHandler?(0.3, "Fetching dose history...")

		// Fetch historical dose events (last 365 days)
		let oneYearAgo = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
		let hkEvents = try await queryHelper.fetchDoseEvents(from: oneYearAgo, to: Date())

		logger.info("Fetched \(hkMedications.count) medications and \(hkEvents.count) events from HealthKit")

		var medicationsMigrated = 0
		var eventsMigrated = 0

		progressHandler?(0.5, "Importing medications...")

		// Import medications
		for (index, medication) in hkMedications.enumerated() {
			do {
				// Check if medication already exists
				if !dataStore.medications.contains(where: { $0.id == medication.id }) {
					try await dataStore.addMedication(medication)
					medicationsMigrated += 1
				}

				let progress = 0.5 + (Double(index + 1) / Double(hkMedications.count)) * 0.2
				progressHandler?(progress, "Imported \(index + 1) of \(hkMedications.count) medications...")

			} catch {
				logger.error("Failed to import medication", error: error)
				errors.append(error)
			}
		}

		progressHandler?(0.7, "Importing dose events...")

		// Import events
		for (index, event) in hkEvents.enumerated() {
			do {
				// Check if event already exists
				if !dataStore.events.contains(where: { $0.id == event.id }) {
					try await dataStore.addEvent(event, shouldRecordForReview: false)
					eventsMigrated += 1
				}

				if index % 50 == 0 {
					let progress = 0.7 + (Double(index + 1) / Double(hkEvents.count)) * 0.25
					progressHandler?(progress, "Imported \(index + 1) of \(hkEvents.count) dose events...")
				}

			} catch {
				logger.error("Failed to import event", error: error)
				errors.append(error)
			}
		}

		let duration = Date().timeIntervalSince(startTime)
		progressHandler?(1.0, "Migration complete")

		logger.info("Migration to AsNeeded completed: \(medicationsMigrated) meds, \(eventsMigrated) events")

		return HealthKitMigrationResult(
			medicationsMigrated: medicationsMigrated,
			eventsMigrated: eventsMigrated,
			success: errors.isEmpty,
			errors: errors,
			duration: duration
		)
		#else
		throw HealthKitSyncError.healthKitNotAvailable
		#endif
	}

	// MARK: - Backup Support

	/// Check if a backup is recommended before migration
	func shouldOfferBackup(for direction: HealthKitMigrationDirection) -> Bool {
		return direction.shouldOfferBackup
	}

	/// Create a backup before migration
	func createBackup() async throws -> URL {
		logger.info("Creating backup before migration")
		let data = try await dataStore.exportDataAsJSON(redactNames: false, redactNotes: false)

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
		let filename = "AsNeeded-Backup-\(dateFormatter.string(from: Date())).json"

		guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
			throw NSError(domain: "HealthKitMigration", code: -1, userInfo: [
				NSLocalizedDescriptionKey: "Could not access documents directory"
			])
		}

		let backupURL = documentsPath.appendingPathComponent(filename)
		try data.write(to: backupURL, options: [.atomic])

		logger.info("Backup created at: \(backupURL.lastPathComponent)")
		return backupURL
	}
}

// MARK: - Array Extension for Batching

private extension Array {
	func chunked(into size: Int) -> [[Element]] {
		return stride(from: 0, to: count, by: size).map {
			Array(self[$0 ..< Swift.min($0 + size, count)])
		}
	}
}

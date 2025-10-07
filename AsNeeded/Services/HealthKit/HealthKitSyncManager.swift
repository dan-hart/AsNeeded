// HealthKitSyncManager.swift
// Central service for managing HealthKit synchronization with AsNeeded.

import Foundation
import HealthKit
import ANModelKit
#if canImport(ANModelKitHealthKit)
import ANModelKitHealthKit
#endif
import DHLoggingKit

/// Errors specific to HealthKit sync operations
enum HealthKitSyncError: LocalizedError {
	case healthKitNotAvailable
	case authorizationDenied
	case syncDisabled
	case invalidSyncMode
	case migrationRequired
	case syncFailed(String)

	var errorDescription: String? {
		switch self {
		case .healthKitNotAvailable:
			return "HealthKit is not available on this device"
		case .authorizationDenied:
			return "HealthKit authorization was denied"
		case .syncDisabled:
			return "HealthKit sync is not enabled"
		case .invalidSyncMode:
			return "Invalid HealthKit sync mode"
		case .migrationRequired:
			return "Data migration is required before syncing"
		case .syncFailed(let reason):
			return "HealthKit sync failed: \(reason)"
		}
	}
}

/// Result of a sync operation
struct HealthKitSyncResult {
	let medicationsSynced: Int
	let eventsSynced: Int
	let errors: [Error]
	let duration: TimeInterval

	var success: Bool { errors.isEmpty }
}

/// Manages HealthKit authorization, synchronization, and data operations
@MainActor
final class HealthKitSyncManager: ObservableObject {
	static let shared = HealthKitSyncManager()

	// Published properties for UI binding
	@Published private(set) var authorizationStatus: HealthKitAuthorizationStatus = .unknown
	@Published private(set) var isSyncing: Bool = false
	@Published private(set) var lastSyncDate: Date?
	@Published private(set) var lastSyncError: Error?

	private let logger = DHLogger(category: "HealthKitSync")
	private let dataStore: DataStore
	private var backgroundSyncTimer: Timer?

	#if canImport(ANModelKitHealthKit)
	private let healthStore = HKHealthStore()
	private var syncHelper: ANHealthKitSync?
	private var queryHelper: ANHealthKitQuery?
	private var authHelper: ANHealthKitAuthorization?
	#endif

	// MARK: - Initialization

	init(dataStore: DataStore = .shared) {
		self.dataStore = dataStore
		#if canImport(ANModelKitHealthKit)
		if ANModelKitHealthKit.isHealthKitAvailable {
			self.syncHelper = ANHealthKitSync()
			self.queryHelper = ANHealthKitQuery()
			self.authHelper = ANHealthKitAuthorization.shared
		}
		#endif
		Task {
			await updateAuthorizationStatus()
			await loadLastSyncDate()
		}
	}

	// MARK: - HealthKit Availability

	var isHealthKitAvailable: Bool {
		#if canImport(ANModelKitHealthKit)
		return ANModelKitHealthKit.isHealthKitAvailable
		#else
		return false
		#endif
	}

	// MARK: - Authorization

	/// Request HealthKit authorization for medication tracking
	func requestAuthorization() async throws {
		logger.info("Requesting HealthKit authorization")

		guard isHealthKitAvailable else {
			logger.error("HealthKit not available on this device")
			authorizationStatus = .notAvailable
			throw HealthKitSyncError.healthKitNotAvailable
		}

		#if canImport(ANModelKitHealthKit)
		guard let authHelper = authHelper else {
			throw HealthKitSyncError.healthKitNotAvailable
		}

		do {
			try await authHelper.requestMedicationAuthorization()
			await updateAuthorizationStatus()
			logger.info("HealthKit authorization granted")
		} catch {
			logger.error("HealthKit authorization failed", error: error)
			authorizationStatus = .denied
			throw HealthKitSyncError.authorizationDenied
		}
		#else
		throw HealthKitSyncError.healthKitNotAvailable
		#endif
	}

	/// Update the current authorization status
	func updateAuthorizationStatus() async {
		guard isHealthKitAvailable else {
			authorizationStatus = .notAvailable
			return
		}

		#if canImport(ANModelKitHealthKit)
		// Check authorization status from HealthKit
		let medicationType = HKObjectType.clinicalType(forIdentifier: .medicationRecord)!
		let status = healthStore.authorizationStatus(for: medicationType)

		switch status {
		case .notDetermined:
			authorizationStatus = .notDetermined
		case .sharingDenied:
			authorizationStatus = .denied
		case .sharingAuthorized:
			authorizationStatus = .authorized
		@unknown default:
			authorizationStatus = .unknown
		}
		#else
		authorizationStatus = .notAvailable
		#endif

		logger.debug("Authorization status updated: \(authorizationStatus.displayText)")
	}

	// MARK: - Sync Operations

	/// Current sync mode from user defaults
	var currentSyncMode: HealthKitSyncMode? {
		guard let modeString = UserDefaults.standard.string(forKey: UserDefaultsKeys.healthKitSyncMode) else {
			return nil
		}
		return HealthKitSyncMode(rawValue: modeString)
	}

	/// Whether HealthKit sync is enabled
	var isSyncEnabled: Bool {
		UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitSyncEnabled)
	}

	/// Perform a sync operation based on current sync mode
	func performSync() async throws -> HealthKitSyncResult {
		guard isHealthKitAvailable else {
			throw HealthKitSyncError.healthKitNotAvailable
		}

		guard authorizationStatus == .authorized else {
			throw HealthKitSyncError.authorizationDenied
		}

		guard isSyncEnabled else {
			throw HealthKitSyncError.syncDisabled
		}

		guard let syncMode = currentSyncMode else {
			throw HealthKitSyncError.invalidSyncMode
		}

		logger.info("Starting sync with mode: \(syncMode.displayName)")
		isSyncing = true
		lastSyncError = nil

		defer {
			isSyncing = false
		}

		let startTime = Date()

		do {
			let result: HealthKitSyncResult

			switch syncMode {
			case .bidirectional:
				result = try await performBidirectionalSync()
			case .healthKitSOT:
				result = try await performHealthKitSOTSync()
			case .asNeededSOT:
				result = try await performAsNeededSOTSync()
			}

			let duration = Date().timeIntervalSince(startTime)
			lastSyncDate = Date()
			await saveLastSyncDate(Date())

			logger.info("Sync completed: \(result.medicationsSynced) meds, \(result.eventsSynced) events in \(duration)s")
			return result

		} catch {
			logger.error("Sync failed", error: error)
			lastSyncError = error
			throw error
		}
	}

	// MARK: - Sync Mode Implementations

	/// Bidirectional sync - keep both databases in sync
	private func performBidirectionalSync() async throws -> HealthKitSyncResult {
		#if canImport(ANModelKitHealthKit)
		guard let syncHelper = syncHelper else {
			throw HealthKitSyncError.healthKitNotAvailable
		}

		let startTime = Date()
		var errors: [Error] = []

		// Get local data
		let localMedications = dataStore.medications
		let localEvents = dataStore.events

		// Perform full bidirectional sync with newerWins strategy
		do {
			let result = try await syncHelper.performFullSync(
				localMedications: localMedications,
				localEvents: localEvents,
				syncStrategy: .newerWins
			)

			// Update local storage with synced data
			// Add new medications from HealthKit
			for medication in result.medicationsAdded {
				try? await dataStore.addMedication(medication)
			}

			// Update modified medications
			for medication in result.medicationsUpdated {
				try? await dataStore.updateMedication(medication)
			}

			// Add new events from HealthKit
			for event in result.eventsAdded {
				try? await dataStore.addEvent(event, shouldRecordForReview: false)
			}

			let duration = Date().timeIntervalSince(startTime)
			return HealthKitSyncResult(
				medicationsSynced: result.medicationsAdded.count + result.medicationsUpdated.count,
				eventsSynced: result.eventsAdded.count,
				errors: errors,
				duration: duration
			)

		} catch {
			errors.append(error)
			throw HealthKitSyncError.syncFailed("Bidirectional sync failed: \(error.localizedDescription)")
		}
		#else
		throw HealthKitSyncError.healthKitNotAvailable
		#endif
	}

	/// HealthKit as source of truth - read only from HealthKit
	private func performHealthKitSOTSync() async throws -> HealthKitSyncResult {
		#if canImport(ANModelKitHealthKit)
		guard let queryHelper = queryHelper else {
			throw HealthKitSyncError.healthKitNotAvailable
		}

		let startTime = Date()
		var errors: [Error] = []

		// Fetch all medications from HealthKit
		let hkMedications = try await queryHelper.fetchActiveMedications()

		// Fetch recent events (last 30 days)
		let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
		let hkEvents = try await queryHelper.fetchDoseEvents(from: thirtyDaysAgo, to: Date())

		// Note: In HealthKit SOT mode, we don't write to local Boutique storage
		// The UI will read directly from HealthKit via this manager

		let duration = Date().timeIntervalSince(startTime)
		return HealthKitSyncResult(
			medicationsSynced: hkMedications.count,
			eventsSynced: hkEvents.count,
			errors: errors,
			duration: duration
		)
		#else
		throw HealthKitSyncError.healthKitNotAvailable
		#endif
	}

	/// AsNeeded as source of truth - write to both, read from local
	private func performAsNeededSOTSync() async throws -> HealthKitSyncResult {
		#if canImport(ANModelKitHealthKit)
		guard let syncHelper = syncHelper else {
			throw HealthKitSyncError.healthKitNotAvailable
		}

		let startTime = Date()
		var errors: [Error] = []

		// Get local events
		let localEvents = dataStore.events

		// Push local events to HealthKit
		let pushResult = try await syncHelper.pushToHealthKit(events: localEvents)
		errors.append(contentsOf: pushResult.errors)

		// Pull medications from HealthKit (to stay aware of HealthKit changes)
		let pullResult = try await syncHelper.pullFromHealthKit(daysOfEvents: 7)

		// Update local with any new medications from HealthKit
		for medication in pullResult.medicationsAdded {
			if !dataStore.medications.contains(where: { $0.id == medication.id }) {
				try? await dataStore.addMedication(medication)
			}
		}

		let duration = Date().timeIntervalSince(startTime)
		return HealthKitSyncResult(
			medicationsSynced: pullResult.medicationsAdded.count,
			eventsSynced: pushResult.totalChanges,
			errors: errors,
			duration: duration
		)
		#else
		throw HealthKitSyncError.healthKitNotAvailable
		#endif
	}

	// MARK: - Background Sync

	/// Start automatic background sync
	func startBackgroundSync(interval: TimeInterval = 300) {
		stopBackgroundSync() // Stop any existing timer

		logger.info("Starting background sync with interval: \(interval)s")

		backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
			Task { @MainActor in
				guard let self = self else { return }
				if self.isSyncEnabled && self.authorizationStatus == .authorized {
					do {
						_ = try await self.performSync()
					} catch {
						self.logger.error("Background sync failed", error: error)
					}
				}
			}
		}

		// Mark as enabled
		UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitBackgroundSyncEnabled)
	}

	/// Stop automatic background sync
	func stopBackgroundSync() {
		backgroundSyncTimer?.invalidate()
		backgroundSyncTimer = nil
		UserDefaults.standard.set(false, forKey: UserDefaultsKeys.healthKitBackgroundSyncEnabled)
		logger.info("Background sync stopped")
	}

	// MARK: - Manual Sync Operations

	/// One-time pull from HealthKit to local
	func pullFromHealthKit(daysOfHistory: Int = 30) async throws -> (medications: Int, events: Int) {
		#if canImport(ANModelKitHealthKit)
		guard let syncHelper = syncHelper else {
			throw HealthKitSyncError.healthKitNotAvailable
		}

		logger.info("Pulling \(daysOfHistory) days from HealthKit")

		let result = try await syncHelper.pullFromHealthKit(daysOfEvents: daysOfHistory)

		// Add to local storage
		for medication in result.medicationsAdded {
			try? await dataStore.addMedication(medication)
		}

		for event in result.eventsAdded {
			try? await dataStore.addEvent(event, shouldRecordForReview: false)
		}

		return (medications: result.medicationsAdded.count, events: result.eventsAdded.count)
		#else
		throw HealthKitSyncError.healthKitNotAvailable
		#endif
	}

	/// One-time push from local to HealthKit
	func pushToHealthKit() async throws -> Int {
		#if canImport(ANModelKitHealthKit)
		guard let syncHelper = syncHelper else {
			throw HealthKitSyncError.healthKitNotAvailable
		}

		logger.info("Pushing local events to HealthKit")

		let localEvents = dataStore.events
		let result = try await syncHelper.pushToHealthKit(events: localEvents)

		if !result.errors.isEmpty {
			logger.warning("Push completed with \(result.errors.count) errors")
		}

		return result.totalChanges
		#else
		throw HealthKitSyncError.healthKitNotAvailable
		#endif
	}

	// MARK: - Persistence

	private func loadLastSyncDate() async {
		if let date = UserDefaults.standard.object(forKey: UserDefaultsKeys.healthKitLastSyncDate) as? Date {
			lastSyncDate = date
		}
	}

	private func saveLastSyncDate(_ date: Date) async {
		UserDefaults.standard.set(date, forKey: UserDefaultsKeys.healthKitLastSyncDate)
	}
}

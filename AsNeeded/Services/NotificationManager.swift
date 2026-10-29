// NotificationManager.swift
// Centralized notification handling for medication reminders

import ANModelKit
import DHLoggingKit
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
	static let shared: NotificationManager = {
		let center = UNUserNotificationCenter.current()
		return NotificationManager(notificationClient: .live(center), medicationExists: { id in
			try await DataStore.shared.prepareForAccess().medications.contains { $0.id == id }
		}, notificationCenter: center)
	}()
	private let logger = DHLogger(category: "NotificationManager")

	enum AuthorizationStatus: Equatable {
		case notDetermined
		case denied
		case authorized
		case provisional
		case ephemeral
		case unknown
	}

	@Published private(set) var timeSensitiveSetting: UNNotificationSetting = .notSupported
	@Published private(set) var urgencyRevision = 0
	@Published var authorizationStatus: AuthorizationStatus = .notDetermined
	@Published var showMedicationNames: Bool = false {
		didSet {
			defaults.set(showMedicationNames, forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
			if notificationCenter != nil {
				Task {
					await reconcileScheduledReminders()
					await refreshAvailabilityNotifications()
				}
			}
		}
	}

	enum OperationError: Error { case medicationNotFound, preferencePersistenceFailed, urgencyRequestCreationFailed }
	private let notificationCenter: UNUserNotificationCenter?
	private let notificationClient: MedicationNotificationClient
	private let urgencyStore: MedicationNotificationUrgencyStore
	private let defaults: UserDefaults
	private let medicationExists: @MainActor (UUID) async throws -> Bool
	private var reminderMutationTail: Task<Void, Never>?
	private var removalGenerations: [UUID: UInt] = [:]
	// A detail row may still hold a legacy ID while its replacement is being added.
	private var canonicalReminderIdentifiers: [String: String] = [:]
	private var availabilityObservationTasks: [Task<Void, Never>] = []
	private var availabilityRefreshTask: Task<Void, Never>?
	private var availabilityNeedsRefresh = false
	private var availabilityObservationStarted = false
	private var availabilityDataStore: DataStore?


	init(
		notificationClient: MedicationNotificationClient,
		defaults: UserDefaults = .standard,
		medicationExists: @escaping @MainActor (UUID) async throws -> Bool,
		notificationCenter: UNUserNotificationCenter? = nil,
		urgencyStore: MedicationNotificationUrgencyStore? = nil
	) {
		self.notificationClient = notificationClient
		self.defaults = defaults
		self.urgencyStore = urgencyStore ?? MedicationNotificationUrgencyStore(defaults: defaults)
		self.medicationExists = medicationExists
		self.notificationCenter = notificationCenter
		showMedicationNames = defaults.object(forKey: UserDefaultsKeys.showMedicationNamesInNotifications) as? Bool ?? false
	}

	private func enqueueReminderMutation<Output>(
		_ operation: @escaping @MainActor () async throws -> Output
	) async -> Result<Output, Error> {
		let previous = reminderMutationTail
		return await withCheckedContinuation { continuation in
			reminderMutationTail = Task {
				await previous?.value
				do { continuation.resume(returning: .success(try await operation())) }
				catch { continuation.resume(returning: .failure(error)) }
			}
		}
	}

	func removalGeneration(for medicationID: UUID) -> UInt { removalGenerations[medicationID, default: 0] }

	private func setupNotificationCategories() async {
		let takenAction = UNNotificationAction(
			identifier: "TAKEN_ACTION",
			title: "Mark as Taken",
			options: [.foreground]
		)

		let skipAction = UNNotificationAction(
			identifier: "SKIP_ACTION",
			title: "Skip",
			options: []
		)

		let medicationCategory = UNNotificationCategory(
			identifier: "MEDICATION_REMINDER",
			actions: [takenAction, skipAction],
			intentIdentifiers: [],
			hiddenPreviewsBodyPlaceholder: "Medication reminder",
			options: []
		)

		let availabilityCategory = UNNotificationCategory(
			identifier: MedicationAvailabilityNotificationPlanner.categoryIdentifier,
			actions: [],
			intentIdentifiers: [],
			hiddenPreviewsBodyPlaceholder: "Next dose availability",
			options: []
		)
		notificationCenter?.setNotificationCategories([medicationCategory, availabilityCategory])
		logger.debug("Notification categories configured")
	}

	private func updateAuthorizationStatus() async {
		let status = await notificationClient.notificationSettings()
		timeSensitiveSetting = await notificationClient.timeSensitiveSetting()
		await MainActor.run {
			switch status {
			case .notDetermined:
				self.authorizationStatus = .notDetermined
			case .denied:
				self.authorizationStatus = .denied
			case .authorized:
				self.authorizationStatus = .authorized
			case .provisional:
				self.authorizationStatus = .provisional
			case .ephemeral:
				self.authorizationStatus = .ephemeral
			@unknown default:
				self.authorizationStatus = .unknown
			}
		}
		logger.debug("Notification authorization status: \(String(describing: authorizationStatus))")
	}

	func checkAuthorizationStatus() async {
		await updateAuthorizationStatus()
		if notificationCenter == nil { return }
		if availabilityObservationStarted {
			await reconcileScheduledReminders()
			await refreshAvailabilityNotifications()
		} else {
			await bootstrapAvailabilityObservation()
		}
	}

	func requestAuthorization() async -> Bool {
		do {
			guard let notificationCenter else { return false }
			let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
			await checkAuthorizationStatus()
			logger.info("Notification authorization requested - granted: \(granted)")
			return granted
		} catch {
			logger.logPrivacySafeError("Failed to request notification authorization", error: error)
			return false
		}
	}

	func scheduleReminder(
		for medication: ANMedicationConcept,
		date: Date,
		isRecurring: Bool,
		repeatInterval: DateComponents? = nil
	) async throws {
		let generation = removalGeneration(for: medication.id)
		let result = await enqueueReminderMutation {
			guard try await self.medicationExists(medication.id), self.removalGeneration(for: medication.id) == generation else {
				throw OperationError.medicationNotFound
			}
			let request = MedicationReminderRequest.make(medication: medication, date: date, isRecurring: isRecurring, repeatInterval: repeatInterval, isUrgent: self.isUrgent(for: medication.id), showMedicationNames: self.showMedicationNames)
			let pending = await self.notificationClient.pendingRequests()
			guard try await self.medicationExists(medication.id), self.removalGeneration(for: medication.id) == generation else {
				throw OperationError.medicationNotFound
			}
			try await self.notificationClient.add(request)
			do {
				guard try await self.medicationExists(medication.id), self.removalGeneration(for: medication.id) == generation else { throw OperationError.medicationNotFound }
			} catch {
				self.notificationClient.removePending([request.identifier])
				throw error
			}
			self.removeReplacedLegacyReminders(MedicationReminderRequest.legacyIdentifiers(matching: request, in: pending), canonicalIdentifier: request.identifier)
		}
		try result.get()
	}

	/// Pending requests are the existing schedule source; the pinned model has no schedule fields.
	/// Keep legacy requests until their canonical replacement has been accepted by the system.
	func reconcileScheduledReminders() async {
		_ = await enqueueReminderMutation {
			let pending = await self.notificationClient.pendingRequests()
			let delivered = await self.notificationClient.deliveredRequests()
			var missingIDs: Set<UUID> = []
			let ids = Set((pending + delivered).filter { $0.content.categoryIdentifier == MedicationReminderRequest.categoryIdentifier }.compactMap { Self.medicationID(for: $0) })
			do {
				for id in ids {
					if try await self.medicationExists(id) == false { missingIDs.insert(id) }
				}
			} catch {
				self.logger.logPrivacySafeError("Unable to read medication inventory for reminders", error: error)
				return
			}
			if !missingIDs.isEmpty {
				self.notificationClient.removePending(pending.filter { Self.belongsToMedication($0, ids: missingIDs) }.map(\.identifier))
				self.notificationClient.removeDelivered(delivered.filter { Self.belongsToMedication($0, ids: missingIDs) }.map(\.identifier))
			}
			let current = pending.filter { !Self.belongsToMedication($0, ids: missingIDs) }
			guard var preferences = self.urgencyStore.allPreferences() else {
				self.logger.error("Unable to read reminder priority preferences")
				return
			}
			let scheduled = current.filter { MedicationReminderRequest.identity(for: $0) != nil }
			for id in Set(scheduled.compactMap { Self.medicationID(for: $0) }) where preferences[id.uuidString] == nil {
				// Preserve the actual pre-upgrade delivery level; never promote ordinary reminders.
				preferences[id.uuidString] = scheduled.contains { Self.medicationID(for: $0) == id && $0.content.interruptionLevel == .timeSensitive }
			}
			for id in missingIDs { preferences.removeValue(forKey: id.uuidString) }
			guard self.urgencyStore.replaceAll(with: preferences) else { return }
			self.urgencyRevision &+= 1
			let urgencyByID = Dictionary(uniqueKeysWithValues: preferences.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } })
			for plan in MedicationReminderRequest.reconciliationPlans(in: current, showMedicationNames: self.showMedicationNames, urgencyByMedicationID: urgencyByID) {
				guard let id = MedicationReminderRequest.identity(for: plan.requestToAdd)?.medicationID else { continue }
				let generation = self.removalGeneration(for: id)
				do {
					guard try await self.medicationExists(id) else {
						self.notificationClient.removePending(plan.identifiersToRemove + [plan.requestToAdd.identifier])
						continue
					}
					guard self.removalGeneration(for: id) == generation else { continue }
					try await self.notificationClient.add(plan.requestToAdd)
					do {
						guard try await self.medicationExists(id), self.removalGeneration(for: id) == generation else { throw OperationError.medicationNotFound }
					} catch {
						self.notificationClient.removePending([plan.requestToAdd.identifier])
						throw error
					}
					self.removeReplacedLegacyReminders(plan.identifiersToRemove, canonicalIdentifier: plan.requestToAdd.identifier)
				} catch {
					self.logger.logPrivacySafeError("Unable to reconcile scheduled reminder", error: error)
				}
			}
		}
	}

	func isUrgent(for medicationID: UUID) -> Bool { urgencyStore.isUrgent(for: medicationID) }

	/// Serialize with scheduling/removal; publish the preference only after all replacements succeed.
	func setUrgent(_ isUrgent: Bool, for medicationID: UUID) async throws {
		let generation = removalGeneration(for: medicationID)
		let result = await enqueueReminderMutation {
			@MainActor func validate() async throws {
				guard try await self.medicationExists(medicationID), self.removalGeneration(for: medicationID) == generation else {
					throw OperationError.medicationNotFound
				}
			}
			try await validate()
			guard self.urgencyStore.allPreferences() != nil else { throw OperationError.preferencePersistenceFailed }
			let originals = await self.notificationClient.pendingRequests().filter {
				$0.content.categoryIdentifier == MedicationReminderRequest.categoryIdentifier && Self.medicationID(for: $0) == medicationID
			}
			var replaced: [UNNotificationRequest] = []
			do {
				try await validate()
				for original in originals {
					guard let replacement = MedicationReminderRequest.updatingUrgency(of: original, isUrgent: isUrgent) else {
						throw OperationError.urgencyRequestCreationFailed
					}
					try await self.notificationClient.add(replacement)
					replaced.append(original)
					try await validate()
				}
				guard self.urgencyStore.save(isUrgent, for: medicationID) else { throw OperationError.preferencePersistenceFailed }
				self.urgencyRevision &+= 1
			} catch {
				// A concurrent deletion must never be undone by restoring its requests.
				let stillExists = (try? await self.medicationExists(medicationID)) == true
				if stillExists && self.removalGeneration(for: medicationID) == generation {
					for original in replaced {
						do { try await self.notificationClient.add(original) }
						catch { self.logger.logPrivacySafeError("Unable to restore reminder priority", error: error) }
						if self.removalGeneration(for: medicationID) != generation {
							self.notificationClient.removePending(replaced.map(\.identifier))
							break
						}
					}
				} else { self.notificationClient.removePending(replaced.map(\.identifier)) }
				throw error
			}
		}
		try result.get()
	}

	func acknowledgeDeliveredReminders(for medicationID: UUID) async {
		_ = await enqueueReminderMutation {
			let requests = await self.notificationClient.deliveredRequests()
			self.notificationClient.removeDelivered(MedicationReminderRequest.deliveredIdentifiers(for: medicationID, in: requests))
		}
	}

	func removeMedicationNotificationArtifacts(for medicationIDs: Set<UUID>) async {
		guard !medicationIDs.isEmpty else { return }
		// Invalidate suspended adds immediately, before waiting for the serialized cleanup.
		for id in medicationIDs { removalGenerations[id, default: 0] &+= 1 }
		_ = await enqueueReminderMutation {
			let pending = await self.notificationClient.pendingRequests()
			let delivered = await self.notificationClient.deliveredRequests()
			self.notificationClient.removePending(pending.filter { Self.belongsToMedication($0, ids: medicationIDs) }.map(\.identifier))
			self.notificationClient.removeDelivered(delivered.filter { Self.belongsToMedication($0, ids: medicationIDs) }.map(\.identifier))
			for id in medicationIDs { _ = self.urgencyStore.removePreference(for: id) }
			self.urgencyRevision &+= 1
		}
	}

	private static func medicationID(for request: UNNotificationRequest) -> UUID? {
		guard [MedicationReminderRequest.categoryIdentifier, MedicationAvailabilityNotificationPlanner.categoryIdentifier].contains(request.content.categoryIdentifier) else { return nil }
		let raw = request.content.userInfo[MedicationReminderRequest.medicationIDKey]
		return (raw as? UUID) ?? (raw as? String).flatMap(UUID.init(uuidString:))
	}

	private static func belongsToMedication(_ request: UNNotificationRequest, ids: Set<UUID>) -> Bool {
		medicationID(for: request).map { ids.contains($0) } ?? false
	}

	func cancelReminder(for medication: ANMedicationConcept) async {
		_ = await enqueueReminderMutation {
			let requests = await self.notificationClient.pendingRequests()
			self.notificationClient.removePending(requests.filter { Self.isScheduledReminder($0, for: medication) }.map(\.identifier))
		}
	}

	func getPendingReminders(for medication: ANMedicationConcept) async -> [UNNotificationRequest] {
		await notificationClient.pendingRequests().filter { Self.isScheduledReminder($0, for: medication) }
	}

	func getReminderDetails(for medication: ANMedicationConcept) async -> [ReminderDetail] {
		await getPendingReminders(for: medication).compactMap { ReminderDetail(from: $0) }.sorted { $0.nextFireDate < $1.nextFireDate }
	}

	private func removeReplacedLegacyReminders(_ identifiers: [String], canonicalIdentifier: String) {
		// Publish aliases only after add and removal validation succeeded. Resolve them
		// within the mutation queue so a queued cancellation sees the completed replacement.
		for identifier in identifiers { canonicalReminderIdentifiers[identifier] = canonicalIdentifier }
		notificationClient.removePending(identifiers)
	}

	func cancelSpecificReminder(withIdentifier identifier: String) async {
		guard !identifier.hasPrefix(MedicationAvailabilityNotificationPlanner.identifierPrefix) else { return }
		_ = await enqueueReminderMutation {
			let canonicalIdentifier = self.canonicalReminderIdentifiers[identifier] ?? identifier
			self.notificationClient.removePending(canonicalIdentifier == identifier ? [identifier] : [identifier, canonicalIdentifier])
		}
	}

	func cancelAllReminders() async {
		_ = await enqueueReminderMutation {
			let requests = await self.notificationClient.pendingRequests()
			self.notificationClient.removePending(requests.filter { $0.content.categoryIdentifier == MedicationReminderRequest.categoryIdentifier }.map(\.identifier))
		}
	}

	private static func isScheduledReminder(_ request: UNNotificationRequest, for medication: ANMedicationConcept) -> Bool {
		request.content.categoryIdentifier == MedicationReminderRequest.categoryIdentifier && belongsToMedication(request, ids: [medication.id])
	}

	/// Retry on foreground/permission checks after a transient migration or storage failure.
	func bootstrapAvailabilityObservation(dataStore: DataStore = .shared) async {
		do {
			try await MedicationDoseLimitMigration().migrate(dataStore: dataStore)
			await updateAuthorizationStatus()
			await setupNotificationCategories()
			await reconcileScheduledReminders()
			try await startAvailabilityObservation(dataStore: dataStore)
		} catch {
			logger.logPrivacySafeError("Unable to prepare next-dose notifications", error: error)
			await cancelAvailabilityNotifications()
		}
	}

	private func cancelAvailabilityNotifications() async {
		let prefix = MedicationAvailabilityNotificationPlanner.identifierPrefix
		let pending = await notificationClient.pendingRequests()
		notificationClient.removePending(pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
		let delivered = await notificationClient.deliveredRequests()
		notificationClient.removeDelivered(delivered.map(\.identifier).filter { $0.hasPrefix(prefix) })
	}

	/// Start only after the dose-limit migration has completed successfully.
	func startAvailabilityObservation(dataStore: DataStore = .shared) async throws {
		guard !availabilityObservationStarted else { return }
		try await dataStore.medicationsStore.itemsHaveLoaded()
		try await dataStore.eventsStore.itemsHaveLoaded()
		guard !availabilityObservationStarted else { return }
		availabilityObservationStarted = true
		availabilityDataStore = dataStore
		availabilityObservationTasks = [
			Task { [weak self] in
				for await _ in dataStore.medicationsStore.events {
					guard !Task.isCancelled else { return }
					await self?.refreshAvailabilityNotifications()
				}
			},
			Task { [weak self] in
				for await _ in dataStore.eventsStore.events {
					guard !Task.isCancelled else { return }
					await self?.refreshAvailabilityNotifications()
				}
			},
			Task { [weak self] in
				for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
					guard !Task.isCancelled, let self else { return }
					let names = self.defaults.bool(forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
					if self.showMedicationNames != names { self.showMedicationNames = names }
					await self.refreshAvailabilityNotifications()
				}
			}
		]
		await refreshAvailabilityNotifications()
	}

	/// Coalesce changes into one serialized worker. Every pass reads the latest stores,
	/// so an older async add cannot finish after a newer reconciliation.
	func refreshAvailabilityNotifications() async {
		guard availabilityObservationStarted else { return }
		availabilityNeedsRefresh = true
		if let task = availabilityRefreshTask {
			await task.value
			return
		}
		let task = Task { [weak self] in
			guard let self else { return }
			defer { self.availabilityRefreshTask = nil }
			while self.availabilityNeedsRefresh {
				self.availabilityNeedsRefresh = false
				await self.reconcileAvailabilityNotifications()
			}
		}
		availabilityRefreshTask = task
		await task.value
	}

	private func reconcileAvailabilityNotifications() async {
		_ = await enqueueReminderMutation { await self.performAvailabilityReconciliation() }
	}

	private func performAvailabilityReconciliation() async {
		guard let dataStore = availabilityDataStore else { return }
		let snapshot: MedicationPersistenceSnapshot
		do {
			try await dataStore.prepareForAccess()
			try await MedicationDoseLimitMigration().migrate(dataStore: dataStore)
			snapshot = try await dataStore.prepareForAccess()
		} catch {
			logger.logPrivacySafeError("Unable to migrate restored dose limits for notifications", error: error)
			await cancelAvailabilityNotifications()
			return
		}
		let pending = await notificationClient.pendingRequests()
		let status = await notificationClient.notificationSettings()
		let authorized = [UNAuthorizationStatus.authorized, .provisional, .ephemeral].contains(status)
		let now = Date()
		let service = MedicationDoseGuidanceService()
		let profiles = MedicationSafetyProfileStore.shared.allProfiles()
		let planner = MedicationAvailabilityNotificationPlanner()
		let candidates = snapshot.medications.map { medication in
			MedicationAvailabilityNotificationPlanner.Candidate(
				medicationID: medication.id,
				medicationName: medication.displayName,
				enabled: authorized && medication.nextDoseNotificationEnabled == true,
				archived: medication.isArchived,
				eligibleDate: service.availability(
					for: medication,
					at: now,
					events: snapshot.events,
					profile: profiles[medication.id.uuidString] ?? .empty
				).eligibleDate
			)
		}
		let desired = planner.notifications(for: candidates, at: now, showMedicationNames: showMedicationNames)
		let staleIDs = planner.identifiersToRemove(pending: pending.map(\.identifier), desired: desired)
		notificationClient.removePending(staleIDs)
		let delivered = await notificationClient.deliveredRequests()
		let deliveredIDs = delivered.map(\.identifier).filter {
			$0.hasPrefix(MedicationAvailabilityNotificationPlanner.identifierPrefix)
		}
		notificationClient.removeDelivered(deliveredIDs)
		for notification in desired {
			let content = UNMutableNotificationContent()
			content.title = notification.title
			content.body = notification.body
			content.sound = .default
			content.categoryIdentifier = MedicationAvailabilityNotificationPlanner.categoryIdentifier
			content.userInfo = ["medicationId": notification.medicationID.uuidString]
			let interval = notification.date.timeIntervalSinceNow
			guard interval > 0 else {
				notificationClient.removePending([notification.identifier])
				continue
			}
			let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
			do {
				try await notificationClient.add(UNNotificationRequest(identifier: notification.identifier, content: content, trigger: trigger))
			} catch {
				notificationClient.removePending([notification.identifier])
				logger.logPrivacySafeError("Failed to schedule next-dose availability", error: error)
			}
		}
	}

}

struct ReminderDetail: Identifiable {
	let id: String
	let nextFireDate: Date
	let title: String
	let body: String
	let isRepeating: Bool
	let repeatInfo: String?

	init?(from request: UNNotificationRequest) {
		guard let trigger = request.trigger else { return nil }

		id = request.identifier
		title = request.content.title
		body = request.content.body

		if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
			isRepeating = calendarTrigger.repeats

			// Calculate next fire date
			if let nextFireDate = calendarTrigger.nextTriggerDate() {
				self.nextFireDate = nextFireDate
			} else {
				nextFireDate = Date()
			}

			// Generate repeat info
			if calendarTrigger.repeats {
				let components = calendarTrigger.dateComponents
				let time = nextFireDate.formatted(date: .omitted, time: .shortened)
				if let weekday = components.weekday, components.hour != nil, components.minute != nil {
					let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
					repeatInfo = "Weekly on \(weekdayName) at \(time)"
				} else if components.hour != nil, components.minute != nil {
					repeatInfo = "Daily at \(time)"
				} else {
					repeatInfo = "Recurring"
				}
			} else {
				repeatInfo = nil
			}
		} else {
			nextFireDate = Date()
			isRepeating = false
			repeatInfo = nil
		}
	}
}

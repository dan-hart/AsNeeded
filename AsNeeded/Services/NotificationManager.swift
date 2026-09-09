// NotificationManager.swift
// Centralized notification handling for medication reminders

import ANModelKit
import DHLoggingKit
import Foundation
import UserNotifications

@MainActor
struct MedicationNotificationClient {
	struct Settings {
		let authorizationStatus: UNAuthorizationStatus
		let timeSensitiveSetting: UNNotificationSetting
	}

	let notificationSettings: @MainActor () async -> Settings
	let pendingRequests: @MainActor () async -> [UNNotificationRequest]
	let deliveredRequests: @MainActor () async -> [UNNotificationRequest]
	let add: @MainActor (UNNotificationRequest) async throws -> Void
	let removePending: @MainActor ([String]) -> Void
	let removeDelivered: @MainActor ([String]) -> Void

	static func live(notificationCenter: UNUserNotificationCenter) -> Self {
		Self(
			notificationSettings: {
				let settings = await notificationCenter.notificationSettings()
				return Settings(
					authorizationStatus: settings.authorizationStatus,
					timeSensitiveSetting: settings.timeSensitiveSetting
				)
			},
			pendingRequests: {
				await notificationCenter.pendingNotificationRequests()
			},
			deliveredRequests: {
				await notificationCenter.deliveredNotifications().map(\.request)
			},
			add: { request in
				try await notificationCenter.add(request)
			},
			removePending: { identifiers in
				notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
			},
			removeDelivered: { identifiers in
				notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
			}
		)
	}
}

@MainActor
final class NotificationManager: ObservableObject {
	typealias MedicationExistenceProvider = @MainActor (UUID) async throws -> Bool

	static let shared: NotificationManager = {
		let notificationCenter = UNUserNotificationCenter.current()
		return NotificationManager(
			notificationCenter: notificationCenter,
			notificationClient: .live(notificationCenter: notificationCenter),
			urgencyStore: .shared,
			medicationExists: { medicationID in
				let currentMedicationIDs =
					try await DataStore.shared.currentMedicationIDsWhenReady()
				return currentMedicationIDs.contains(medicationID)
			},
			performsSystemSetup: true
		)
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

	enum TimeSensitiveStatus: Equatable {
		case enabled
		case disabled
		case notSupported
		case unknown
	}

	enum OperationError: Error, Equatable {
		case medicationNotFound
		case preferencePersistenceFailed
		case urgencyRequestCreationFailed
	}

	@Published var authorizationStatus: AuthorizationStatus = .notDetermined
	@Published private(set) var timeSensitiveStatus: TimeSensitiveStatus = .unknown
	@Published var showMedicationNames: Bool = false {
		didSet {
			UserDefaults.standard.set(showMedicationNames, forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
		}
	}

	private let notificationCenter: UNUserNotificationCenter
	private let notificationClient: MedicationNotificationClient
	private let urgencyStore: MedicationNotificationUrgencyStore
	private let medicationExists: MedicationExistenceProvider
	private let performsSystemSetup: Bool
	private var reminderMutationTail: Task<Void, Never>?
	private var startupTask: Task<Bool, Never>?
	private var startupCompleted = false

	init(
		notificationCenter: UNUserNotificationCenter = .current(),
		notificationClient: MedicationNotificationClient,
		urgencyStore: MedicationNotificationUrgencyStore = .shared,
		medicationExists: @escaping MedicationExistenceProvider = { _ in true },
		performsSystemSetup: Bool = false
	) {
		self.notificationCenter = notificationCenter
		self.notificationClient = notificationClient
		self.urgencyStore = urgencyStore
		self.medicationExists = medicationExists
		self.performsSystemSetup = performsSystemSetup
		showMedicationNames = UserDefaults.standard.object(forKey: UserDefaultsKeys.showMedicationNamesInNotifications) as? Bool ?? false
	}

	private func enqueueReminderMutation<Output>(
		_ operation: @escaping @MainActor () async throws -> Output
	) async -> Result<Output, Error> {
		let previous = reminderMutationTail
		return await withCheckedContinuation { continuation in
			reminderMutationTail = Task {
				await previous?.value
				do {
					continuation.resume(returning: .success(try await operation()))
				} catch {
					continuation.resume(returning: .failure(error))
				}
			}
		}
	}

	func start(
		currentMedicationIDs: @escaping @MainActor () async throws -> Set<UUID>
	) async {
		guard !startupCompleted else {
			return
		}
		if let startupTask {
			await startupTask.value
			return
		}

		let task = Task {
			await performStartup(currentMedicationIDs: currentMedicationIDs)
		}
		startupTask = task
		let completed = await task.value
		startupTask = nil
		startupCompleted = completed
	}

	private func performStartup(
		currentMedicationIDs: @escaping @MainActor () async throws -> Set<UUID>
	) async -> Bool {
		let medicationIDs: Set<UUID>
		do {
			medicationIDs = try await currentMedicationIDs()
		} catch {
			logger.logPrivacySafeError("Failed to load medication inventory for notification startup", error: error)
			return false
		}

		if performsSystemSetup {
			await checkAuthorizationStatus()
			await setupNotificationCategories()
		}
		return await migrateAndReconcilePendingReminders(currentMedicationIDs: medicationIDs)
	}

	private func migrateAndReconcilePendingReminders(
		currentMedicationIDs: Set<UUID>
	) async -> Bool {
		let result = await enqueueReminderMutation {
			let pendingRequests = await self.notificationClient.pendingRequests()
			guard var preferences = self.urgencyStore.allPreferences() else {
				self.logger.error("Notification urgency preferences are corrupt; startup reconciliation aborted")
				return false
			}

			var effectivePreferences = preferences
			var migrationCompleted = self.urgencyStore.migrationCompleted
			if !migrationCompleted {
				let pendingMedicationIDs = Set(
					pendingRequests.compactMap {
						MedicationReminderRequest.identity(for: $0)?.medicationID
					}
				).intersection(currentMedicationIDs)
				let legacyMedicationIDs = pendingMedicationIDs.filter {
					preferences[$0.uuidString] == nil
				}

				for medicationID in legacyMedicationIDs {
					preferences[medicationID.uuidString] = true
					effectivePreferences[medicationID.uuidString] = true
				}

				if self.urgencyStore.replaceAll(with: preferences) {
					if self.urgencyStore.markMigrationCompleted() {
						migrationCompleted = true
						effectivePreferences = preferences
					} else {
						self.logger.error("Failed to persist notification urgency migration marker")
					}
				} else {
					self.logger.error("Failed to persist migrated notification urgency preferences")
				}
			}

			let urgencyByMedicationID = currentMedicationIDs.reduce(into: [UUID: Bool]()) {
				$0[$1] = effectivePreferences[$1.uuidString] ?? false
			}
			for plan in MedicationReminderRequest.reconciliationPlans(
				in: pendingRequests,
				urgencyByMedicationID: urgencyByMedicationID
			) {
				do {
					try await self.notificationClient.add(plan.requestToAdd)
					if !plan.identifiersToRemove.isEmpty {
						self.notificationClient.removePending(plan.identifiersToRemove)
					}
				} catch {
					self.logger.logPrivacySafeError("Failed to reconcile medication reminder", error: error)
				}
			}
			return migrationCompleted
		}

		switch result {
		case let .success(migrationCompleted):
			return migrationCompleted
		case let .failure(error):
			logger.logPrivacySafeError("Notification startup reconciliation failed", error: error)
			return false
		}
	}

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
			identifier: MedicationReminderRequest.categoryIdentifier,
            actions: [takenAction, skipAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Medication reminder",
            options: []
        )

        notificationCenter.setNotificationCategories([medicationCategory])
        logger.debug("Notification categories configured")
    }

	func checkAuthorizationStatus() async {
		let settings = await notificationClient.notificationSettings()
		switch settings.authorizationStatus {
		case .notDetermined:
			authorizationStatus = .notDetermined
		case .denied:
			authorizationStatus = .denied
		case .authorized:
			authorizationStatus = .authorized
		case .provisional:
			authorizationStatus = .provisional
		case .ephemeral:
			authorizationStatus = .ephemeral
		@unknown default:
			authorizationStatus = .unknown
		}
		timeSensitiveStatus = Self.timeSensitiveStatus(for: settings.timeSensitiveSetting)
		logger.debug("Notification authorization status: \(String(describing: authorizationStatus))")
	}

	static func timeSensitiveStatus(
		for setting: UNNotificationSetting
	) -> TimeSensitiveStatus {
		switch setting {
		case .enabled:
			.enabled
		case .disabled:
			.disabled
		case .notSupported:
			.notSupported
		@unknown default:
			.unknown
		}
	}

    func requestAuthorization() async -> Bool {
        do {
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
        logger.info("Scheduling medication reminder")
		let result = await enqueueReminderMutation {
			guard try await self.medicationExists(medication.id) else {
				throw OperationError.medicationNotFound
			}
			let isUrgent: Bool
			if let preference = self.urgencyStore.preference(for: medication.id) {
				isUrgent = preference
			} else {
				guard self.urgencyStore.save(false, for: medication.id) else {
					throw OperationError.preferencePersistenceFailed
				}
				isUrgent = false
			}
			let request = MedicationReminderRequest.make(
				medication: medication,
				date: date,
				isRecurring: isRecurring,
				repeatInterval: repeatInterval,
				isUrgent: isUrgent,
				showMedicationNames: self.showMedicationNames
			)
			let pendingRequests = await self.notificationClient.pendingRequests()
			let legacyIdentifiers = MedicationReminderRequest.legacyIdentifiers(
				matching: request,
				in: pendingRequests
			)

			try await self.notificationClient.add(request)
			if !legacyIdentifiers.isEmpty {
				self.notificationClient.removePending(legacyIdentifiers)
			}
		}
		try result.get()
        logger.info("Reminder scheduled successfully")
    }

	func isUrgent(for medicationID: UUID) -> Bool {
		urgencyStore.isUrgent(for: medicationID)
	}

	func setUrgent(_ isUrgent: Bool, for medicationID: UUID) async throws {
		let result = await enqueueReminderMutation {
			guard try await self.medicationExists(medicationID) else {
				throw OperationError.medicationNotFound
			}
			let pendingRequests = await self.notificationClient.pendingRequests()
			let originalRequests = pendingRequests.filter {
				Self.medicationID(for: $0) == medicationID
			}
			let replacements = try originalRequests.map { request in
				guard let replacement = MedicationReminderRequest.updatingUrgency(
					of: request,
					isUrgent: isUrgent
				) else {
					throw OperationError.urgencyRequestCreationFailed
				}
				return replacement
			}
			var replacedOriginals: [UNNotificationRequest] = []

			do {
				for (original, replacement) in zip(originalRequests, replacements) {
					try await self.notificationClient.add(replacement)
					replacedOriginals.append(original)
				}

				guard self.urgencyStore.save(isUrgent, for: medicationID) else {
					throw OperationError.preferencePersistenceFailed
				}
			} catch {
				await self.restoreUrgencyRequests(replacedOriginals)
				throw error
			}
		}
		try result.get()
	}

	private func restoreUrgencyRequests(
		_ requests: [UNNotificationRequest]
	) async {
		for request in requests {
			do {
				try await notificationClient.add(request)
			} catch {
				logger.logPrivacySafeError("Failed to roll back medication reminder urgency", error: error)
			}
		}
	}

	private static func medicationID(
		for request: UNNotificationRequest
	) -> UUID? {
		guard request.content.categoryIdentifier == MedicationReminderRequest.categoryIdentifier else {
			return nil
		}
		if let medicationID = request.content.userInfo[MedicationReminderRequest.medicationIDKey] as? UUID {
			return medicationID
		}
		guard let value = request.content.userInfo[MedicationReminderRequest.medicationIDKey] as? String else {
			return nil
		}
		return UUID(uuidString: value)
	}

	func acknowledgeDeliveredReminders(for medicationID: UUID) async {
		_ = await enqueueReminderMutation {
			let deliveredRequests = await self.notificationClient.deliveredRequests()
			let identifiers = MedicationReminderRequest.deliveredIdentifiers(
				for: medicationID,
				in: deliveredRequests
			)
			if !identifiers.isEmpty {
				self.notificationClient.removeDelivered(identifiers)
			}
		}
	}

	func removeMedicationNotificationArtifacts(
		for medicationIDs: Set<UUID>
	) async {
		guard !medicationIDs.isEmpty else {
			return
		}

		_ = await enqueueReminderMutation {
			let pendingRequests = await self.notificationClient.pendingRequests()
			let deliveredRequests = await self.notificationClient.deliveredRequests()
			let pendingIdentifiers = pendingRequests.compactMap { request -> String? in
				guard let medicationID = Self.medicationID(for: request),
					medicationIDs.contains(medicationID)
				else {
					return nil
				}
				return request.identifier
			}
			let deliveredIdentifiers = deliveredRequests.compactMap { request -> String? in
				guard let medicationID = Self.medicationID(for: request),
					medicationIDs.contains(medicationID)
				else {
					return nil
				}
				return request.identifier
			}

			if !pendingIdentifiers.isEmpty {
				self.notificationClient.removePending(pendingIdentifiers)
			}
			if !deliveredIdentifiers.isEmpty {
				self.notificationClient.removeDelivered(deliveredIdentifiers)
			}

			guard var preferences = self.urgencyStore.allPreferences() else {
				self.logger.error(
					"Removed medication notification requests, but urgency preferences are corrupt"
				)
				return
			}
			for medicationID in medicationIDs {
				preferences.removeValue(forKey: medicationID.uuidString)
			}
			if !self.urgencyStore.replaceAll(with: preferences) {
				self.logger.error(
					"Removed medication notification requests, but urgency preferences could not be removed safely"
				)
			}
		}
	}

    func cancelReminder(for medication: ANMedicationConcept) async {
        logger.info("Cancelling medication reminders")

		_ = await enqueueReminderMutation {
			let pendingRequests = await self.notificationClient.pendingRequests()
			let requestsToCancel = pendingRequests
				.filter { $0.identifier.contains(medication.id.uuidString) }
				.map { $0.identifier }

			if !requestsToCancel.isEmpty {
				self.notificationClient.removePending(requestsToCancel)
				self.logger.info("Cancelled \(requestsToCancel.count) reminders")
			}
		}
    }

    func getPendingReminders(for medication: ANMedicationConcept) async -> [UNNotificationRequest] {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        return pendingRequests.filter { $0.identifier.contains(medication.id.uuidString) }
    }

    func getReminderDetails(for medication: ANMedicationConcept) async -> [ReminderDetail] {
        let pendingRequests = await getPendingReminders(for: medication)
        return pendingRequests.compactMap { request in
            ReminderDetail(from: request)
        }.sorted { $0.nextFireDate < $1.nextFireDate }
    }

    func cancelSpecificReminder(withIdentifier identifier: String) async {
		_ = await enqueueReminderMutation {
			self.notificationClient.removePending([identifier])
		}
        logger.info("Cancelled specific reminder")
    }

    func cancelAllReminders() async {
		_ = await enqueueReminderMutation {
			let identifiers = await self.notificationClient.pendingRequests().map(\.identifier)
			if !identifiers.isEmpty {
				self.notificationClient.removePending(identifiers)
			}
		}
        logger.info("All reminders cancelled")
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
                if let weekday = components.weekday, let hour = components.hour, let minute = components.minute {
                    let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
                    repeatInfo = "Weekly on \(weekdayName) at \(String(format: "%02d:%02d", hour, minute))"
                } else if let hour = components.hour, let minute = components.minute {
                    repeatInfo = "Daily at \(String(format: "%02d:%02d", hour, minute))"
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

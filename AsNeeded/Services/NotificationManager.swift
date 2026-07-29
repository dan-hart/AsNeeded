// NotificationManager.swift
// Centralized notification handling for medication reminders

import ANModelKit
import DHLoggingKit
import Foundation
import UserNotifications

@MainActor
struct MedicationNotificationClient {
	let pendingRequests: @MainActor () async -> [UNNotificationRequest]
	let deliveredRequests: @MainActor () async -> [UNNotificationRequest]
	let add: @MainActor (UNNotificationRequest) async throws -> Void
	let removePending: @MainActor ([String]) -> Void
	let removeDelivered: @MainActor ([String]) -> Void

	static func live(notificationCenter: UNUserNotificationCenter) -> Self {
		Self(
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
	static let shared: NotificationManager = {
		let notificationCenter = UNUserNotificationCenter.current()
		return NotificationManager(
			notificationCenter: notificationCenter,
			notificationClient: .live(notificationCenter: notificationCenter),
			startsAutomatically: true,
			performsSystemSetup: true
		)
	}()
    private let logger = DHLogger(category: "NotificationManager")

    enum AuthorizationStatus {
        case notDetermined
        case denied
        case authorized
        case provisional
        case ephemeral
        case unknown
    }

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var showMedicationNames: Bool = false {
        didSet {
            UserDefaults.standard.set(showMedicationNames, forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
        }
    }

	private let notificationCenter: UNUserNotificationCenter
	private let notificationClient: MedicationNotificationClient
	private var reminderMutationTail: Task<Void, Never>?

	init(
		notificationCenter: UNUserNotificationCenter = .current(),
		notificationClient: MedicationNotificationClient,
		startsAutomatically: Bool = false,
		performsSystemSetup: Bool = false,
		scheduleStartup: (@escaping @MainActor () async -> Void) -> Void = { action in
			Task {
				await action()
			}
		}
	) {
		self.notificationCenter = notificationCenter
		self.notificationClient = notificationClient
		showMedicationNames = UserDefaults.standard.object(forKey: UserDefaultsKeys.showMedicationNamesInNotifications) as? Bool ?? false

		if startsAutomatically {
			scheduleStartup {
				if performsSystemSetup {
					await self.checkAuthorizationStatus()
					await self.setupNotificationCategories()
				}
				await self.reconcilePendingReminders()
			}
		}
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
        let settings = await notificationCenter.notificationSettings()
        await MainActor.run {
            switch settings.authorizationStatus {
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
		let request = MedicationReminderRequest.make(
			medication: medication,
			date: date,
			isRecurring: isRecurring,
			repeatInterval: repeatInterval,
			isUrgent: true,
			showMedicationNames: showMedicationNames
		)
		let result = await enqueueReminderMutation {
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

	func reconcilePendingReminders() async {
		_ = await enqueueReminderMutation {
			let pendingRequests = await self.notificationClient.pendingRequests()
			let urgencyByMedicationID = pendingRequests.reduce(into: [UUID: Bool]()) { result, request in
				guard let medicationID = MedicationReminderRequest.identity(for: request)?.medicationID else {
					return
				}
				result[medicationID] = true
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
		}
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

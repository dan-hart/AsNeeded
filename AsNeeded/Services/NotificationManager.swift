// NotificationManager.swift
// Centralized notification handling for medication reminders

import ANModelKit
import DHLoggingKit
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
	static let shared = NotificationManager()
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
			Task { await refreshAvailabilityNotifications() }
		}
	}

	private let notificationCenter = UNUserNotificationCenter.current()
	private var availabilityObservationTasks: [Task<Void, Never>] = []
	private var availabilityRefreshTask: Task<Void, Never>?
	private var availabilityNeedsRefresh = false
	private var availabilityObservationStarted = false
	private var availabilityDataStore: DataStore?


	private init() {
		showMedicationNames = UserDefaults.standard.object(forKey: UserDefaultsKeys.showMedicationNamesInNotifications) as? Bool ?? false
		Task {
			await checkAuthorizationStatus()
			await setupNotificationCategories()
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
		notificationCenter.setNotificationCategories([medicationCategory, availabilityCategory])
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
		if availabilityObservationStarted {
			await refreshAvailabilityNotifications()
		} else {
			await bootstrapAvailabilityObservation()
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

		// Create notification content
		let content = UNMutableNotificationContent()

		if showMedicationNames {
			content.title = medication.displayName
			content.body = "It's time to take \(medication.displayName)"
		} else {
			content.title = "Medication Reminder"
			content.body = "It's time to take your medication"
		}

		content.sound = .default
		content.categoryIdentifier = "MEDICATION_REMINDER"
		content.userInfo = ["medicationId": medication.id.uuidString]

		// Create trigger
		let trigger: UNNotificationTrigger
		if isRecurring, let repeatInterval = repeatInterval {
			trigger = UNCalendarNotificationTrigger(dateMatching: repeatInterval, repeats: true)
		} else {
			let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
			trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
		}

		// Create request
		let requestId = "\(medication.id.uuidString)-\(date.timeIntervalSince1970)"
		let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

		// Schedule notification
		try await notificationCenter.add(request)
		logger.info("Reminder scheduled successfully")
	}

	func cancelReminder(for medication: ANMedicationConcept) async {
		logger.info("Cancelling medication reminders")

		let pendingRequests = await notificationCenter.pendingNotificationRequests()
		let requestsToCancel = pendingRequests
			.filter { Self.isScheduledReminder($0, for: medication) }
			.map { $0.identifier }

		if !requestsToCancel.isEmpty {
			notificationCenter.removePendingNotificationRequests(withIdentifiers: requestsToCancel)
			logger.info("Cancelled \(requestsToCancel.count) reminders")
		}
	}

	func getPendingReminders(for medication: ANMedicationConcept) async -> [UNNotificationRequest] {
		let pendingRequests = await notificationCenter.pendingNotificationRequests()
		return pendingRequests.filter { Self.isScheduledReminder($0, for: medication) }
	}

	func getReminderDetails(for medication: ANMedicationConcept) async -> [ReminderDetail] {
		let pendingRequests = await getPendingReminders(for: medication)
		return pendingRequests.compactMap { request in
			ReminderDetail(from: request)
		}.sorted { $0.nextFireDate < $1.nextFireDate }
	}

	func cancelSpecificReminder(withIdentifier identifier: String) async {
		guard !identifier.hasPrefix(MedicationAvailabilityNotificationPlanner.identifierPrefix) else { return }
		notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
		logger.info("Cancelled specific reminder")
	}

	func cancelAllReminders() async {
		let requests = await notificationCenter.pendingNotificationRequests()
		let identifiers = requests.filter {
			$0.content.categoryIdentifier == "MEDICATION_REMINDER"
		}.map(\.identifier)
		notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
		logger.info("All reminders cancelled")
	}

	private static func isScheduledReminder(_ request: UNNotificationRequest, for medication: ANMedicationConcept) -> Bool {
		request.identifier.hasPrefix(medication.id.uuidString + "-") &&
			request.content.categoryIdentifier == "MEDICATION_REMINDER"
	}

	/// Retry on foreground/permission checks after a transient migration or storage failure.
	func bootstrapAvailabilityObservation(dataStore: DataStore = .shared) async {
		do {
			try await MedicationDoseLimitMigration().migrate(dataStore: dataStore)
			try await startAvailabilityObservation(dataStore: dataStore)
		} catch {
			logger.logPrivacySafeError("Unable to prepare next-dose notifications", error: error)
			await cancelAvailabilityNotifications()
		}
	}

	private func cancelAvailabilityNotifications() async {
		let prefix = MedicationAvailabilityNotificationPlanner.identifierPrefix
		let pending = await notificationCenter.pendingNotificationRequests()
		notificationCenter.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
		let delivered = await notificationCenter.deliveredNotifications()
		notificationCenter.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix) })
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
					let names = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
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
		guard let dataStore = availabilityDataStore else { return }
		do {
			try await MedicationDoseLimitMigration().migrate(dataStore: dataStore)
		} catch {
			logger.logPrivacySafeError("Unable to migrate restored dose limits for notifications", error: error)
			await cancelAvailabilityNotifications()
			return
		}
		let pending = await notificationCenter.pendingNotificationRequests()
		let settings = await notificationCenter.notificationSettings()
		let authorized = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
		let now = Date()
		let service = MedicationDoseGuidanceService()
		let profiles = MedicationSafetyProfileStore.shared.allProfiles()
		let planner = MedicationAvailabilityNotificationPlanner()
		let candidates = dataStore.medications.map { medication in
			MedicationAvailabilityNotificationPlanner.Candidate(
				medicationID: medication.id,
				medicationName: medication.displayName,
				enabled: authorized && medication.nextDoseNotificationEnabled == true,
				archived: medication.isArchived,
				eligibleDate: service.availability(
					for: medication,
					at: now,
					events: dataStore.events,
					profile: profiles[medication.id.uuidString] ?? .empty
				).eligibleDate
			)
		}
		let desired = planner.notifications(for: candidates, at: now, showMedicationNames: showMedicationNames)
		let staleIDs = planner.identifiersToRemove(pending: pending.map(\.identifier), desired: desired)
		notificationCenter.removePendingNotificationRequests(withIdentifiers: staleIDs)
		let delivered = await notificationCenter.deliveredNotifications()
		let deliveredIDs = delivered.map(\.request.identifier).filter {
			$0.hasPrefix(MedicationAvailabilityNotificationPlanner.identifierPrefix)
		}
		notificationCenter.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
		for notification in desired {
			let content = UNMutableNotificationContent()
			content.title = notification.title
			content.body = notification.body
			content.sound = .default
			content.categoryIdentifier = MedicationAvailabilityNotificationPlanner.categoryIdentifier
			content.userInfo = ["medicationId": notification.medicationID.uuidString]
			let interval = notification.date.timeIntervalSinceNow
			guard interval > 0 else {
				notificationCenter.removePendingNotificationRequests(withIdentifiers: [notification.identifier])
				continue
			}
			let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
			do {
				try await notificationCenter.add(UNNotificationRequest(identifier: notification.identifier, content: content, trigger: trigger))
			} catch {
				notificationCenter.removePendingNotificationRequests(withIdentifiers: [notification.identifier])
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

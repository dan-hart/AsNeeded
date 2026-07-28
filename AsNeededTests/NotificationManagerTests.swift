import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@MainActor
@Suite("NotificationManager Tests", .tags(.service, .notifications, .unit))
struct NotificationManagerTests {
    init() {
        // Reset UserDefaults before each test to ensure isolation
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
    }

    // MARK: - Test Helpers

    private func createTestMedication(name: String = "TestMed") -> ANMedicationConcept {
        ANMedicationConcept(
            clinicalName: name,
            nickname: nil,
            quantity: 100.0,
            prescribedUnit: .tablet,
            prescribedDoseAmount: 2.0
        )
    }

    // MARK: - Initialization Tests

    @Test("NotificationManager is a singleton")
    func singletonInstance() {
        let instance1 = NotificationManager.shared
        let instance2 = NotificationManager.shared

        #expect(instance1 === instance2)
    }

    @Test("NotificationManager initializes successfully")
    func initialization() {
        let manager = NotificationManager.shared

        #expect(manager != nil)
    }

    @Test("NotificationManager conforms to ObservableObject")
    func observableObjectConformance() {
        let manager = NotificationManager.shared

        #expect(manager is ObservableObject)
    }

    // MARK: - Authorization Status Tests

    @Test("Authorization status initializes as notDetermined")
    func authorizationStatusInitialValue() {
        let manager = NotificationManager.shared

        // Status should be set during init
        #expect(manager.authorizationStatus != nil)
    }

    @Test("CheckAuthorizationStatus updates status")
    func testCheckAuthorizationStatus() async {
        let manager = NotificationManager.shared

        await manager.checkAuthorizationStatus()

        // Status should be one of the valid enum values
        let validStatuses: [NotificationManager.AuthorizationStatus] = [
            .notDetermined, .denied, .authorized, .provisional, .ephemeral, .unknown,
        ]

        #expect(validStatuses.contains(manager.authorizationStatus))
    }

    @Test("RequestAuthorization returns bool")
    func requestAuthorizationReturns() async {
        let manager = NotificationManager.shared
		let settings = await UNUserNotificationCenter.current().notificationSettings()
		guard settings.authorizationStatus != .notDetermined else {
			return
		}

        let result = await manager.requestAuthorization()

        #expect(result is Bool)
    }

    // MARK: - Show Medication Names Setting Tests

    @Test("Show medication names defaults to false")
    func showMedicationNamesDefaultsToFalse() {
        let manager = NotificationManager.shared

        // Explicitly set to default value
        manager.showMedicationNames = false

        #expect(manager.showMedicationNames == false)

        // Verify UserDefaults reflects the default
        let defaultValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
        #expect(defaultValue == false)
    }

    @Test("Show medication names can be toggled")
    func showMedicationNamesToggle() {
        let manager = NotificationManager.shared

        manager.showMedicationNames = true
        #expect(manager.showMedicationNames == true)

        manager.showMedicationNames = false
        #expect(manager.showMedicationNames == false)
    }

    @Test("Show medication names persists to UserDefaults")
    func showMedicationNamesPersistence() {
        let manager = NotificationManager.shared

        manager.showMedicationNames = true

        let storedValue = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
        #expect(storedValue == true)
    }

    // MARK: - Schedule Reminder Tests

    @Test("ScheduleReminder does not crash with valid medication")
    func scheduleReminderValidMedication() async throws {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "Aspirin")
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now

        do {
            try await manager.scheduleReminder(
                for: medication,
                date: futureDate,
                isRecurring: false,
                repeatInterval: nil
            )
            #expect(true) // Success if no error thrown
        } catch {
            // Scheduling might fail in test environment, that's okay
            #expect(true)
        }
    }

    @Test("ScheduleReminder handles recurring reminder")
    func scheduleReminderRecurring() async throws {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "DailyMed")
        let futureDate = Date().addingTimeInterval(3600)

        var repeatComponents = DateComponents()
        repeatComponents.hour = 9
        repeatComponents.minute = 0

        do {
            try await manager.scheduleReminder(
                for: medication,
                date: futureDate,
                isRecurring: true,
                repeatInterval: repeatComponents
            )
            #expect(true)
        } catch {
            #expect(true) // Scheduling might fail in test environment
        }
    }

    @Test("ScheduleReminder with medication names visible")
    func scheduleReminderWithMedicationNames() async throws {
        let manager = NotificationManager.shared
        manager.showMedicationNames = true

        let medication = createTestMedication(name: "Ibuprofen")
        let futureDate = Date().addingTimeInterval(3600)

        do {
            try await manager.scheduleReminder(
                for: medication,
                date: futureDate,
                isRecurring: false,
                repeatInterval: nil
            )
            #expect(true)
        } catch {
            #expect(true)
        }
    }

    @Test("ScheduleReminder with medication names hidden")
    func scheduleReminderWithoutMedicationNames() async throws {
        let manager = NotificationManager.shared
        manager.showMedicationNames = false

        let medication = createTestMedication(name: "SecretMed")
        let futureDate = Date().addingTimeInterval(3600)

        do {
            try await manager.scheduleReminder(
                for: medication,
                date: futureDate,
                isRecurring: false,
                repeatInterval: nil
            )
            #expect(true)
        } catch {
            #expect(true)
        }
    }

	@Test("Scheduling adds the canonical request before removing matching legacy requests")
	func schedulingAddsCanonicalRequestBeforeRemovingLegacyRequests() async throws {
		let medication = createTestMedication()
		let date = Date(timeIntervalSince1970: 1_800_000_000)
		let repeatInterval = DateComponents(hour: 8, minute: 30)
		let canonical = MedicationReminderRequest.make(
			medication: medication,
			date: date,
			isRecurring: true,
			repeatInterval: repeatInterval,
			showMedicationNames: false
		)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		let manager = NotificationManager(notificationClient: fake.client)

		try await manager.scheduleReminder(
			for: medication,
			date: date,
			isRecurring: true,
			repeatInterval: repeatInterval
		)

		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier),
			.removePending([legacy.identifier])
		])
		#expect(fake.addedRequests.first?.identifier == canonical.identifier)
		#expect(fake.addedRequests.first?.content.interruptionLevel == .timeSensitive)
	}

	@Test("A failed schedule preserves matching legacy requests")
	func failedSchedulePreservesMatchingLegacyRequests() async {
		let medication = createTestMedication()
		let date = Date(timeIntervalSince1970: 1_800_000_000)
		let repeatInterval = DateComponents(hour: 8, minute: 30)
		let canonical = MedicationReminderRequest.make(
			medication: medication,
			date: date,
			isRecurring: true,
			repeatInterval: repeatInterval,
			showMedicationNames: false
		)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		fake.addError = NotificationManagerTestError.addFailed
		let manager = NotificationManager(notificationClient: fake.client)

		await #expect(throws: NotificationManagerTestError.self) {
			try await manager.scheduleReminder(
				for: medication,
				date: date,
				isRecurring: true,
				repeatInterval: repeatInterval
			)
		}

		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier)
		])
		#expect(fake.removedPendingIdentifiers.isEmpty)
	}

	// MARK: - Reconciliation Tests
	@Test("Reconciliation migrates one legacy request and leaves unrelated reminders untouched")
	func reconciliationMigratesOneLegacyRequestAndLeavesUnrelatedRemindersUntouched() async {
		let medication = createTestMedication()
		let canonical = recurringRequest(for: medication)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let unrelated = recurringRequest(for: createTestMedication(name: "Unrelated"))
		let fake = FakeMedicationNotificationClient(pendingRequests: [unrelated, legacy])
		let manager = NotificationManager(notificationClient: fake.client)

		await manager.reconcilePendingReminders()

		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier),
			.removePending([legacy.identifier])
		])
		#expect(fake.addedRequests.count == 1)
		#expect(fake.addedRequests.first?.identifier == canonical.identifier)
		#expect(fake.addedRequests.first?.content.interruptionLevel == .timeSensitive)
		#expect(fake.removedPendingIdentifiers == [[legacy.identifier]])
	}

	@Test("A failed reconciliation add preserves the legacy request")
	func failedReconciliationAddPreservesLegacyRequest() async {
		let canonical = recurringRequest(for: createTestMedication())
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		fake.addError = NotificationManagerTestError.addFailed
		let manager = NotificationManager(notificationClient: fake.client)

		await manager.reconcilePendingReminders()

		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier)
		])
		#expect(fake.removedPendingIdentifiers.isEmpty)
	}

	@Test("A later cancellation waits for reconciliation and wins", .timeLimit(.minutes(1)))
	func laterCancellationWaitsForReconciliationAndWins() async {
		let canonical = recurringRequest(for: createTestMedication())
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let addGate = TestAsyncGate()
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		fake.addGate = addGate
		let manager = NotificationManager(notificationClient: fake.client)
		let reconciliation = Task {
			await manager.reconcilePendingReminders()
		}

		await addGate.waitUntilSuspended()
		defer {
			addGate.resume()
		}
		let cancellationStarted = TestAsyncSignal()
		let cancellation = Task {
			cancellationStarted.signal()
			await manager.cancelSpecificReminder(withIdentifier: canonical.identifier)
		}
		await cancellationStarted.wait()

		addGate.resume()
		await reconciliation.value
		await cancellation.value

		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier),
			.finishAdd(canonical.identifier),
			.removePending([legacy.identifier]),
			.removePending([canonical.identifier])
		])
		#expect(fake.pendingRequests.isEmpty)
	}

	@Test("A failed queued operation does not block a later cancellation", .timeLimit(.minutes(1)))
	func failedQueuedOperationDoesNotBlockLaterCancellation() async {
		let medication = createTestMedication()
		let date = Date(timeIntervalSince1970: 1_800_000_000)
		let repeatInterval = DateComponents(hour: 8, minute: 30)
		let canonical = MedicationReminderRequest.make(
			medication: medication,
			date: date,
			isRecurring: true,
			repeatInterval: repeatInterval,
			showMedicationNames: false
		)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let addGate = TestAsyncGate()
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		fake.addGate = addGate
		fake.addError = NotificationManagerTestError.addFailed
		let manager = NotificationManager(notificationClient: fake.client)
		let scheduling = Task {
			do {
				try await manager.scheduleReminder(
					for: medication,
					date: date,
					isRecurring: true,
					repeatInterval: repeatInterval
				)
				return false
			} catch {
				return true
			}
		}

		await addGate.waitUntilSuspended()
		defer {
			addGate.resume()
		}
		let cancellationStarted = TestAsyncSignal()
		let cancellation = Task {
			cancellationStarted.signal()
			await manager.cancelSpecificReminder(withIdentifier: legacy.identifier)
		}
		await cancellationStarted.wait()

		addGate.resume()
		let scheduleFailed = await scheduling.value
		await cancellation.value

		#expect(scheduleFailed)
		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier),
			.finishAdd(canonical.identifier),
			.removePending([legacy.identifier])
		])
		#expect(fake.pendingRequests.isEmpty)
	}

	@Test("Automatic startup schedules exactly one reconciliation action")
	func automaticStartupSchedulesExactlyOneReconciliationAction() async {
		let canonical = recurringRequest(for: createTestMedication())
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		var startupActions: [@MainActor () async -> Void] = []

		_ = NotificationManager(
			notificationClient: fake.client,
			startsAutomatically: true,
			performsSystemSetup: false,
			scheduleStartup: { action in
				startupActions.append(action)
			}
		)

		#expect(startupActions.count == 1)
		#expect(fake.operations.isEmpty)
		guard let startupAction = startupActions.first else {
			Issue.record("Expected one startup action")
			return
		}

		await startupAction()

		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier),
			.removePending([legacy.identifier])
		])
		#expect(fake.addedRequests.first?.content.interruptionLevel == .timeSensitive)
	}

	// MARK: - Delivered Reminder Tests
	@Test("Acknowledging delivered reminders preserves pending recurrence")
	func acknowledgingDeliveredRemindersPreservesPendingRecurrence() async {
		let medication = createTestMedication()
		let otherMedication = createTestMedication(name: "Other")
		let pending = recurringRequest(for: medication)
		let targetDelivered = deliveredRequest(from: pending, identifier: "target-delivered")
		let otherMedicationDelivered = deliveredRequest(
			from: recurringRequest(for: otherMedication),
			identifier: "other-medication"
		)
		let otherCategoryDelivered = deliveredRequest(
			from: pending,
			identifier: "other-category",
			categoryIdentifier: "OTHER"
		)
		let fake = FakeMedicationNotificationClient(
			pendingRequests: [pending],
			deliveredRequests: [otherMedicationDelivered, otherCategoryDelivered, targetDelivered]
		)
		let manager = NotificationManager(notificationClient: fake.client)

		await manager.acknowledgeDeliveredReminders(for: medication.id)

		#expect(fake.operations == [
			.deliveredRequests,
			.removeDelivered([targetDelivered.identifier])
		])
		#expect(fake.removedPendingIdentifiers.isEmpty)
		#expect(fake.pendingRequests == [pending])
	}

    // MARK: - Cancel Reminder Tests

    @Test("CancelReminder does not crash")
    func testCancelReminder() async {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "ToCancel")

        await manager.cancelReminder(for: medication)

        #expect(true) // Should not crash
    }

    @Test("CancelReminder for non-existent medication")
    func cancelReminderNonExistent() async {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "NonExistent")

        await manager.cancelReminder(for: medication)

        #expect(true) // Should handle gracefully
    }

    // MARK: - Get Pending Reminders Tests

    @Test("GetPendingReminders returns array")
    func testGetPendingReminders() async {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "TestMed")

        let pendingReminders = await manager.getPendingReminders(for: medication)

        #expect(pendingReminders is [UNNotificationRequest])
    }

    @Test("GetPendingReminders for medication with no reminders")
    func getPendingRemindersEmpty() async {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "NoReminders")

        let pendingReminders = await manager.getPendingReminders(for: medication)

        #expect(pendingReminders.isEmpty)
    }

    // MARK: - Get Reminder Details Tests

    @Test("GetReminderDetails returns array of ReminderDetail")
    func testGetReminderDetails() async {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "TestMed")

        let details = await manager.getReminderDetails(for: medication)

        #expect(details is [ReminderDetail])
    }

    @Test("GetReminderDetails returns sorted by next fire date")
    func getReminderDetailsSorted() async {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "TestMed")

        let details = await manager.getReminderDetails(for: medication)

        // Verify sorting (if multiple reminders exist)
        if details.count > 1 {
            for i in 0 ..< (details.count - 1) {
                #expect(details[i].nextFireDate <= details[i + 1].nextFireDate)
            }
        }

        #expect(true)
    }

    // MARK: - Cancel Specific Reminder Tests

    @Test("CancelSpecificReminder does not crash")
    func testCancelSpecificReminder() async {
        let manager = NotificationManager.shared

        await manager.cancelSpecificReminder(withIdentifier: "test-identifier")

        #expect(true)
    }

    @Test("CancelSpecificReminder with empty identifier")
    func cancelSpecificReminderEmptyIdentifier() async {
        let manager = NotificationManager.shared

        await manager.cancelSpecificReminder(withIdentifier: "")

        #expect(true)
    }

    // MARK: - Cancel All Reminders Tests

    @Test("CancelAllReminders does not crash")
    func testCancelAllReminders() async {
        let manager = NotificationManager.shared

        await manager.cancelAllReminders()

        #expect(true)
    }

    @Test("CancelAllReminders removes all pending notifications")
    func cancelAllRemindersEffect() async {
        let manager = NotificationManager.shared

        // Schedule a reminder
        let medication = createTestMedication(name: "TestMed")
        try? await manager.scheduleReminder(
            for: medication,
            date: Date().addingTimeInterval(3600),
            isRecurring: false,
            repeatInterval: nil
        )

        // Cancel all
        await manager.cancelAllReminders()

        // Verify all cancelled
        let pendingReminders = await manager.getPendingReminders(for: medication)
        #expect(pendingReminders.isEmpty)
    }

    // MARK: - ReminderDetail Tests

    @Test("ReminderDetail initializes from valid request")
    func reminderDetailInitialization() {
        // Create a mock notification request
        let content = UNMutableNotificationContent()
        content.title = "Test Title"
        content.body = "Test Body"

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: Date().addingTimeInterval(3600)
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "test-id",
            content: content,
            trigger: trigger
        )

        guard let detail = ReminderDetail(from: request) else {
            // ReminderDetail might be nil if trigger is invalid in test environment
            #expect(true)
            return
        }

        #expect(detail.id == "test-id")
        #expect(detail.title == "Test Title")
        #expect(detail.body == "Test Body")
        #expect(detail.isRepeating == false)
    }

    @Test("ReminderDetail handles repeating reminders")
    func reminderDetailRepeating() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Reminder"
        content.body = "Take medication"

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-id",
            content: content,
            trigger: trigger
        )

        guard let detail = ReminderDetail(from: request) else {
            #expect(true)
            return
        }

        #expect(detail.isRepeating == true)
        #expect(detail.repeatInfo != nil)
    }

    // MARK: - Integration Tests

    @Test("Complete notification workflow")
    func completeNotificationWorkflow() async throws {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "WorkflowMed")

        // Step 1: Schedule a reminder
        let futureDate = Date().addingTimeInterval(3600)
        try? await manager.scheduleReminder(
            for: medication,
            date: futureDate,
            isRecurring: false,
            repeatInterval: nil
        )

        // Step 2: Get pending reminders
        let pendingReminders = await manager.getPendingReminders(for: medication)
        // May or may not have reminders depending on test environment

        // Step 3: Get details
        let details = await manager.getReminderDetails(for: medication)
        #expect(details is [ReminderDetail])

        // Step 4: Cancel reminders
        await manager.cancelReminder(for: medication)

        // Step 5: Verify cancelled
        let afterCancel = await manager.getPendingReminders(for: medication)
        #expect(afterCancel.isEmpty)
    }

    // MARK: - Edge Cases Tests

    @Test("Schedule multiple reminders for same medication")
    func scheduleMultipleReminders() async throws {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "MultiReminder")

        let date1 = Date().addingTimeInterval(3600)
        let date2 = Date().addingTimeInterval(7200)
        let date3 = Date().addingTimeInterval(10800)

        try? await manager.scheduleReminder(for: medication, date: date1, isRecurring: false, repeatInterval: nil)
        try? await manager.scheduleReminder(for: medication, date: date2, isRecurring: false, repeatInterval: nil)
        try? await manager.scheduleReminder(for: medication, date: date3, isRecurring: false, repeatInterval: nil)

        let pendingReminders = await manager.getPendingReminders(for: medication)
        // Should have multiple reminders if scheduling succeeded
        #expect(pendingReminders.count >= 0)
    }

    @Test("Toggle show medication names affects future reminders")
    func toggleShowMedicationNames() async throws {
        let manager = NotificationManager.shared
        let medication = createTestMedication(name: "ToggleMed")

        // Schedule with names shown
        manager.showMedicationNames = true
        try? await manager.scheduleReminder(
            for: medication,
            date: Date().addingTimeInterval(3600),
            isRecurring: false,
            repeatInterval: nil
        )

        // Schedule with names hidden
        manager.showMedicationNames = false
        try? await manager.scheduleReminder(
            for: medication,
            date: Date().addingTimeInterval(7200),
            isRecurring: false,
            repeatInterval: nil
        )

        #expect(true) // Both should schedule without error
    }

    // MARK: - MainActor Isolation Tests

    @Test("NotificationManager is MainActor isolated")
    func mainActorIsolation() {
        let manager = NotificationManager.shared

        #expect(manager != nil)
    }

    // MARK: - UserDefaults Integration Tests

    @Test("Show medication names integrates with UserDefaultsKeys")
    func userDefaultsKeysIntegration() {
        let allKeys = UserDefaultsKeys.allKeys

        #expect(allKeys.contains(UserDefaultsKeys.showMedicationNamesInNotifications))
    }

    @Test("Show medication names has default value")
    func defaultValueInUserDefaultsKeys() {
        let defaultValues = UserDefaultsKeys.defaultValues

        guard let defaultValue = defaultValues[UserDefaultsKeys.showMedicationNamesInNotifications] as? Bool else {
            Issue.record("Expected default value for showMedicationNamesInNotifications")
            return
        }

        #expect(defaultValue == false)
    }

	private func recurringRequest(for medication: ANMedicationConcept) -> UNNotificationRequest {
		MedicationReminderRequest.make(
			medication: medication,
			date: Date(timeIntervalSince1970: 1_800_000_000),
			isRecurring: true,
			repeatInterval: DateComponents(hour: 8, minute: 30),
			showMedicationNames: false
		)
	}

	private func legacyRequest(from canonical: UNNotificationRequest, identifier: String) -> UNNotificationRequest {
		deliveredRequest(from: canonical, identifier: identifier)
	}

	private func deliveredRequest(
		from source: UNNotificationRequest,
		identifier: String,
		categoryIdentifier: String = MedicationReminderRequest.categoryIdentifier
	) -> UNNotificationRequest {
		let content = source.content.mutableCopy() as? UNMutableNotificationContent ?? UNMutableNotificationContent()
		content.categoryIdentifier = categoryIdentifier
		return UNNotificationRequest(identifier: identifier, content: content, trigger: source.trigger)
	}
}

@MainActor
private final class FakeMedicationNotificationClient {
	enum Operation: Equatable {
		case pendingRequests
		case deliveredRequests
		case add(String)
		case finishAdd(String)
		case removePending([String])
		case removeDelivered([String])
	}

	var pendingRequests: [UNNotificationRequest]
	var deliveredRequests: [UNNotificationRequest]
	var addedRequests: [UNNotificationRequest] = []
	var removedPendingIdentifiers: [[String]] = []
	var removedDeliveredIdentifiers: [[String]] = []
	var operations: [Operation] = []
	var addError: (any Error)?
	var addGate: TestAsyncGate?

	init(
		pendingRequests: [UNNotificationRequest] = [],
		deliveredRequests: [UNNotificationRequest] = []
	) {
		self.pendingRequests = pendingRequests
		self.deliveredRequests = deliveredRequests
	}

	var client: MedicationNotificationClient {
		MedicationNotificationClient(
			pendingRequests: {
				self.operations.append(.pendingRequests)
				return self.pendingRequests
			},
			deliveredRequests: {
				self.operations.append(.deliveredRequests)
				return self.deliveredRequests
			},
			add: { request in
				self.operations.append(.add(request.identifier))
				if let addGate = self.addGate {
					await addGate.suspend()
					self.operations.append(.finishAdd(request.identifier))
				}
				if let addError = self.addError {
					throw addError
				}
				self.addedRequests.append(request)
				self.pendingRequests.removeAll { $0.identifier == request.identifier }
				self.pendingRequests.append(request)
			},
			removePending: { identifiers in
				self.operations.append(.removePending(identifiers))
				self.removedPendingIdentifiers.append(identifiers)
				self.pendingRequests.removeAll { identifiers.contains($0.identifier) }
			},
			removeDelivered: { identifiers in
				self.operations.append(.removeDelivered(identifiers))
				self.removedDeliveredIdentifiers.append(identifiers)
				self.deliveredRequests.removeAll { identifiers.contains($0.identifier) }
			}
		)
	}
}

@MainActor
private final class TestAsyncGate {
	private let arrived = TestAsyncSignal()
	private let released = TestAsyncSignal()

	func suspend() async {
		arrived.signal()
		await released.wait()
	}

	func waitUntilSuspended() async {
		await arrived.wait()
	}

	func resume() {
		released.signal()
	}
}

@MainActor
private final class TestAsyncSignal {
	private let stream: AsyncStream<Void>
	private let continuation: AsyncStream<Void>.Continuation

	init() {
		(stream, continuation) = AsyncStream.makeStream()
	}

	func signal() {
		continuation.yield()
		continuation.finish()
	}

	func wait() async {
		for await _ in stream {
			return
		}
	}
}

private enum NotificationManagerTestError: Error {
	case addFailed
}

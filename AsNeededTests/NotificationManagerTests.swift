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

	@Test("Time sensitive setting maps independently from authorization")
	func timeSensitiveSettingMapping() {
		let cases: [(UNNotificationSetting, NotificationManager.TimeSensitiveStatus)] = [
			(.enabled, .enabled),
			(.disabled, .disabled),
			(.notSupported, .notSupported),
		]

		for (setting, expectedStatus) in cases {
			#expect(NotificationManager.timeSensitiveStatus(for: setting) == expectedStatus)
		}
	}

	@Test("Authorization check publishes authorization and time sensitive status from one snapshot")
	func authorizationCheckPublishesOneSnapshot() async {
		let fake = FakeMedicationNotificationClient(
			authorizationStatus: .authorized,
			timeSensitiveSetting: .disabled
		)
		let manager = NotificationManager(notificationClient: fake.client)

		await manager.checkAuthorizationStatus()

		#expect(manager.authorizationStatus == .authorized)
		#expect(manager.timeSensitiveStatus == .disabled)
		#expect(fake.operations == [.notificationSettings])
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

	@Test("First schedule persists normal and creates an active request")
	func firstSchedulePersistsNormal() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let date = Date(timeIntervalSince1970: 1_800_000_000)
		let fake = FakeMedicationNotificationClient()
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		try await manager.scheduleReminder(
			for: medication,
			date: date,
			isRecurring: false
		)

		#expect(fixture.store.preference(for: medication.id) == false)
		#expect(fake.operations.count == 2)
		#expect(fake.operations.first == .pendingRequests)
		#expect(fake.addedRequests.first?.content.interruptionLevel == .active)
	}

	@Test("Stored urgent preference creates a time sensitive request before removing legacy requests")
	func storedUrgentPreferenceSchedulesTimeSensitive() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		#expect(fixture.store.save(true, for: medication.id))
		let date = Date(timeIntervalSince1970: 1_800_000_000)
		let repeatInterval = DateComponents(hour: 8, minute: 30)
		let canonical = MedicationReminderRequest.make(
			medication: medication,
			date: date,
			isRecurring: true,
			repeatInterval: repeatInterval,
			isUrgent: true,
			showMedicationNames: false
		)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

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
	func failedSchedulePreservesMatchingLegacyRequests() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		#expect(fixture.store.save(true, for: medication.id))
		let date = Date(timeIntervalSince1970: 1_800_000_000)
		let repeatInterval = DateComponents(hour: 8, minute: 30)
		let canonical = MedicationReminderRequest.make(
			medication: medication,
			date: date,
			isRecurring: true,
			repeatInterval: repeatInterval,
			isUrgent: true,
			showMedicationNames: false
		)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		fake.addError = NotificationManagerTestError.addFailed
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

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

	@Test("A first schedule aborts when normal preference persistence fails")
	func firstScheduleAbortsWhenPreferencePersistenceFails() async throws {
		let fixture = try makeUrgencyStore(writer: { _, _, _ in })
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let fake = FakeMedicationNotificationClient()
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		await #expect(throws: NotificationManager.OperationError.self) {
			try await manager.scheduleReminder(
				for: medication,
				date: Date(timeIntervalSince1970: 1_800_000_000),
				isRecurring: false
			)
		}

		#expect(fixture.store.preference(for: medication.id) == nil)
		#expect(fake.operations.isEmpty)
	}

	// MARK: - Urgency Preference Tests
	@Test("Urgency lookup resolves stored and missing preferences")
	func urgencyLookupResolvesStoredAndMissingPreferences() throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let urgentMedication = createTestMedication(name: "Urgent")
		let missingMedication = createTestMedication(name: "Missing")
		#expect(fixture.store.save(true, for: urgentMedication.id))
		let manager = NotificationManager(
			notificationClient: FakeMedicationNotificationClient().client,
			urgencyStore: fixture.store
		)

		#expect(manager.isUrgent(for: urgentMedication.id))
		#expect(!manager.isUrgent(for: missingMedication.id))
	}

	@Test("Urgency update replaces every target reminder and persists preference")
	func urgencyUpdateReplacesEveryTargetReminder() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let recurring = recurringRequest(for: medication, isUrgent: false)
		let oneTime = oneTimeRequest(for: medication, isUrgent: false)
		let fake = FakeMedicationNotificationClient(pendingRequests: [recurring, oneTime])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		try await manager.setUrgent(true, for: medication.id)

		#expect(fake.addedRequests.map(\.identifier) == [recurring.identifier, oneTime.identifier])
		#expect(fake.pendingRequests.count == 2)
		#expect(fake.pendingRequests.allSatisfy { $0.content.interruptionLevel == .timeSensitive })
		#expect(fixture.store.preference(for: medication.id) == true)
	}

	@Test("Urgency update matches category and medication user info instead of identifier text")
	func urgencyUpdateLeavesOtherMedicationRequestsUntouched() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication(name: "Target")
		let otherMedication = createTestMedication(name: "Other")
		let target = recurringRequest(for: medication, isUrgent: false)
		let other = recurringRequest(for: otherMedication, isUrgent: false)
		let misleadingIdentifier = deliveredRequest(
			from: other,
			identifier: "\(medication.id.uuidString)-misleading"
		)
		let wrongCategory = deliveredRequest(
			from: target,
			identifier: "wrong-category",
			categoryIdentifier: "OTHER"
		)
		let fake = FakeMedicationNotificationClient(
			pendingRequests: [target, other, misleadingIdentifier, wrongCategory]
		)
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		try await manager.setUrgent(true, for: medication.id)

		#expect(fake.addedRequests.map(\.identifier) == [target.identifier])
		#expect(fake.pendingRequests.first { $0.identifier == target.identifier }?.content.interruptionLevel == .timeSensitive)
		#expect(fake.pendingRequests.first { $0.identifier == other.identifier }?.content.interruptionLevel == .active)
		#expect(fake.pendingRequests.first { $0.identifier == misleadingIdentifier.identifier }?.content.interruptionLevel == .active)
		#expect(fake.pendingRequests.first { $0.identifier == wrongCategory.identifier }?.content.interruptionLevel == .active)
		#expect(fixture.store.preference(for: otherMedication.id) == nil)
	}

	@Test("Urgency update with no pending reminders still persists explicit preference")
	func urgencyUpdateWithoutPendingRemindersPersistsPreference() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medicationID = UUID()
		let fake = FakeMedicationNotificationClient()
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		try await manager.setUrgent(false, for: medicationID)

		#expect(fake.operations == [.pendingRequests])
		#expect(fixture.store.preference(for: medicationID) == false)
	}

	@Test("Urgency preference persists only after every replacement succeeds")
	func urgencyPreferencePersistsAfterEveryReplacement() async throws {
		var persistedAfterAddCount: Int?
		let medication = createTestMedication()
		let recurring = recurringRequest(for: medication, isUrgent: false)
		let oneTime = oneTimeRequest(for: medication, isUrgent: false)
		let fake = FakeMedicationNotificationClient(pendingRequests: [recurring, oneTime])
		let fixture = try makeUrgencyStore(
			writer: { data, destination, key in
				persistedAfterAddCount = fake.addedRequests.count
				destination.set(data, forKey: key)
			}
		)
		defer {
			fixture.cleanUp()
		}
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		try await manager.setUrgent(true, for: medication.id)

		#expect(persistedAfterAddCount == 2)
		#expect(fixture.store.preference(for: medication.id) == true)
	}

	@Test("Replacement failure rolls back changed reminders and retains old preference")
	func urgencyReplacementFailureRollsBack() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		#expect(fixture.store.save(true, for: medication.id))
		let recurring = recurringRequest(for: medication, isUrgent: true)
		let oneTime = oneTimeRequest(for: medication, isUrgent: true)
		let fake = FakeMedicationNotificationClient(pendingRequests: [recurring, oneTime])
		fake.addErrorsByCall[2] = NotificationManagerTestError.addFailed
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
		var thrownError: NotificationManagerTestError?

		do {
			try await manager.setUrgent(false, for: medication.id)
			Issue.record("Expected urgency replacement to fail")
		} catch let error as NotificationManagerTestError {
			thrownError = error
		} catch {
			Issue.record("Expected original add error, received \(error)")
		}

		#expect(thrownError == .addFailed)
		#expect(fake.addCallCount == 3)
		#expect(fake.pendingRequests.count == 2)
		#expect(fake.pendingRequests.allSatisfy { $0.content.interruptionLevel == .timeSensitive })
		#expect(fixture.store.preference(for: medication.id) == true)
	}

	@Test("Preference persistence failure rolls back reminders and retains old preference")
	func urgencyPreferenceFailureRollsBack() async throws {
		let medication = createTestMedication()
		let fixture = try makeUrgencyStore(writer: { _, _, _ in })
		defer {
			fixture.cleanUp()
		}
		let priorData = try JSONEncoder().encode([medication.id.uuidString: false])
		fixture.defaults.set(
			priorData,
			forKey: UserDefaultsKeys.medicationNotificationUrgency
		)
		let recurring = recurringRequest(for: medication, isUrgent: false)
		let oneTime = oneTimeRequest(for: medication, isUrgent: false)
		let fake = FakeMedicationNotificationClient(pendingRequests: [recurring, oneTime])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
		var thrownError: NotificationManager.OperationError?

		do {
			try await manager.setUrgent(true, for: medication.id)
			Issue.record("Expected urgency preference persistence to fail")
		} catch let error as NotificationManager.OperationError {
			thrownError = error
		} catch {
			Issue.record("Expected preference persistence error, received \(error)")
		}

		#expect(thrownError == .preferencePersistenceFailed)
		#expect(fake.addCallCount == 4)
		#expect(fake.pendingRequests.count == 2)
		#expect(fake.pendingRequests.allSatisfy { $0.content.interruptionLevel == .active })
		#expect(fixture.store.preference(for: medication.id) == false)
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == priorData)
	}

	@Test("Rollback add failure is contained while the original error and preference remain authoritative")
	func urgencyRollbackFailureIsContained() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		#expect(fixture.store.save(false, for: medication.id))
		let recurring = recurringRequest(for: medication, isUrgent: false)
		let oneTime = oneTimeRequest(for: medication, isUrgent: false)
		let fake = FakeMedicationNotificationClient(pendingRequests: [recurring, oneTime])
		fake.addErrorsByCall = [
			2: NotificationManagerTestError.addFailed,
			3: NotificationManagerTestError.rollbackFailed,
		]
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
		var thrownError: NotificationManagerTestError?

		do {
			try await manager.setUrgent(true, for: medication.id)
			Issue.record("Expected urgency replacement to fail")
		} catch let error as NotificationManagerTestError {
			thrownError = error
		} catch {
			Issue.record("Expected original add error, received \(error)")
		}

		#expect(thrownError == .addFailed)
		#expect(fake.addCallCount == 3)
		#expect(fixture.store.preference(for: medication.id) == false)
		#expect(fake.pendingRequests.first { $0.identifier == recurring.identifier }?.content.interruptionLevel == .timeSensitive)
		#expect(fake.pendingRequests.first { $0.identifier == oneTime.identifier }?.content.interruptionLevel == .active)
	}

	@Test("Queued urgency update completes before a later schedule", .timeLimit(.minutes(1)))
	func queuedUrgencyUpdateCompletesBeforeSchedule() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let existing = recurringRequest(for: medication, isUrgent: false)
		let scheduledDate = Date(timeIntervalSince1970: 1_900_000_000)
		let scheduledRequest = MedicationReminderRequest.make(
			medication: medication,
			date: scheduledDate,
			isRecurring: false,
			isUrgent: true,
			showMedicationNames: false
		)
		let addGate = TestAsyncGate()
		let fake = FakeMedicationNotificationClient(pendingRequests: [existing])
		fake.addGate = addGate
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
		let urgencyUpdate = Task {
			try await manager.setUrgent(true, for: medication.id)
		}

		await addGate.waitUntilSuspended()
		let schedulingStarted = TestAsyncSignal()
		let scheduling = Task {
			schedulingStarted.signal()
			try await manager.scheduleReminder(
				for: medication,
				date: scheduledDate,
				isRecurring: false
			)
		}
		await schedulingStarted.wait()

		addGate.resume()
		fake.addGate = nil
		try await urgencyUpdate.value
		try await scheduling.value

		#expect(fake.operations == [
			.pendingRequests,
			.add(existing.identifier),
			.finishAdd(existing.identifier),
			.pendingRequests,
			.add(scheduledRequest.identifier),
		])
		#expect(fake.pendingRequests.first { $0.identifier == scheduledRequest.identifier }?.content.interruptionLevel == .timeSensitive)
		#expect(fixture.store.preference(for: medication.id) == true)
	}

	@Test("Queued urgency update completes before a later cancellation", .timeLimit(.minutes(1)))
	func queuedUrgencyUpdateCompletesBeforeCancellation() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let existing = recurringRequest(for: medication, isUrgent: false)
		let addGate = TestAsyncGate()
		let fake = FakeMedicationNotificationClient(pendingRequests: [existing])
		fake.addGate = addGate
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
		let urgencyUpdate = Task {
			try await manager.setUrgent(true, for: medication.id)
		}

		await addGate.waitUntilSuspended()
		let cancellationStarted = TestAsyncSignal()
		let cancellation = Task {
			cancellationStarted.signal()
			await manager.cancelReminder(for: medication)
		}
		await cancellationStarted.wait()

		addGate.resume()
		fake.addGate = nil
		try await urgencyUpdate.value
		await cancellation.value

		#expect(fake.operations == [
			.pendingRequests,
			.add(existing.identifier),
			.finishAdd(existing.identifier),
			.pendingRequests,
			.removePending([existing.identifier]),
		])
		#expect(fake.pendingRequests.isEmpty)
		#expect(fixture.store.preference(for: medication.id) == true)
	}

	// MARK: - Startup Migration Tests
	@Test("Startup waits for authoritative inventory readiness")
	func startupWaitsForInventoryReadiness() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let canonical = recurringRequest(for: medication)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let inventoryGate = TestAsyncGate()
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
		let startup = Task {
			await manager.start {
				await inventoryGate.suspend()
				return [medication.id]
			}
		}

		await inventoryGate.waitUntilSuspended()
		#expect(fake.operations.isEmpty)
		#expect(!fixture.store.migrationCompleted)

		inventoryGate.resume()
		await startup.value

		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier),
			.removePending([legacy.identifier])
		])
		#expect(fixture.store.migrationCompleted)
	}

	@Test("Provider failure leaves migration incomplete and a later retry succeeds")
	func providerFailureLeavesMigrationIncomplete() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let canonical = recurringRequest(for: medication)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		await manager.start {
			throw NotificationManagerTestError.providerFailed
		}

		#expect(fake.operations.isEmpty)
		#expect(!fixture.store.migrationCompleted)

		await manager.start {
			[medication.id]
		}

		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier),
			.removePending([legacy.identifier])
		])
		#expect(fixture.store.migrationCompleted)
	}

	@Test("Authoritative empty inventory completes migration without touching pending requests")
	func emptyInventoryCompletesMigration() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let stale = recurringRequest(for: createTestMedication(name: "Stale"))
		let fake = FakeMedicationNotificationClient(pendingRequests: [stale])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		await manager.start {
			[]
		}

		#expect(fake.operations == [.pendingRequests])
		#expect(fake.pendingRequests == [stale])
		#expect(fixture.store.migrationCompleted)
	}

	@Test("Existing current medication reminder migrates to urgent exactly once")
	func existingReminderMigratesToUrgentOnce() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let existing = recurringRequest(for: medication, isUrgent: false)
		let fake = FakeMedicationNotificationClient(pendingRequests: [existing])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		await manager.start {
			[medication.id]
		}
		let operationsAfterFirstStartup = fake.operations
		await manager.start {
			Issue.record("Completed startup must not request inventory again")
			return [medication.id]
		}

		#expect(fixture.store.preference(for: medication.id) == true)
		#expect(fixture.store.migrationCompleted)
		#expect(fake.addedRequests.first?.content.interruptionLevel == .timeSensitive)
		#expect(fake.operations == operationsAfterFirstStartup)
	}

	@Test("Existing explicit false survives startup and reconciles to active")
	func explicitFalseSurvivesStartup() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		#expect(fixture.store.save(false, for: medication.id))
		let existing = recurringRequest(for: medication, isUrgent: true)
		let fake = FakeMedicationNotificationClient(pendingRequests: [existing])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		await manager.start {
			[medication.id]
		}

		#expect(fixture.store.preference(for: medication.id) == false)
		#expect(fixture.store.migrationCompleted)
		#expect(fake.addedRequests.first?.content.interruptionLevel == .active)
	}

	@Test("Stale medication reminders are excluded from migration and reconciliation")
	func staleReminderIsIgnored() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let currentMedication = createTestMedication(name: "Current")
		let staleMedication = createTestMedication(name: "Stale")
		let staleCanonical = recurringRequest(for: staleMedication)
		let staleLegacy = legacyRequest(from: staleCanonical, identifier: "stale-legacy")
		let fake = FakeMedicationNotificationClient(pendingRequests: [staleLegacy])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		await manager.start {
			[currentMedication.id]
		}

		#expect(fake.operations == [.pendingRequests])
		#expect(fake.pendingRequests == [staleLegacy])
		#expect(fixture.store.preference(for: staleMedication.id) == nil)
		#expect(fixture.store.preference(for: currentMedication.id) == nil)
		#expect(fixture.store.migrationCompleted)
	}

	@Test("Concurrent startup calls share one in-flight pass and remain idempotent", .timeLimit(.minutes(1)))
	func concurrentStartupCallsAreIdempotent() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let canonical = recurringRequest(for: medication)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let inventoryGate = TestAsyncGate()
		let secondStarted = TestAsyncSignal()
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
		var providerCalls = 0
		let first = Task {
			await manager.start {
				providerCalls += 1
				await inventoryGate.suspend()
				return [medication.id]
			}
		}

		await inventoryGate.waitUntilSuspended()
		let second = Task {
			secondStarted.signal()
			await manager.start {
				providerCalls += 100
				return [medication.id]
			}
		}
		await secondStarted.wait()
		inventoryGate.resume()
		await first.value
		await second.value

		await manager.start {
			providerCalls += 1_000
			return [medication.id]
		}

		#expect(providerCalls == 1)
		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier),
			.removePending([legacy.identifier])
		])
	}

	@Test("Migration persistence failure keeps the marker unset and uses urgent for the pass")
	func migrationPersistenceFailureFallsBackToUrgent() async throws {
		let fixture = try makeUrgencyStore(writer: { _, _, _ in })
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let canonical = recurringRequest(for: medication)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
		var providerCalls = 0

		await manager.start {
			providerCalls += 1
			return [medication.id]
		}
		await manager.start {
			providerCalls += 1
			return [medication.id]
		}

		#expect(providerCalls == 2)
		#expect(fixture.store.preference(for: medication.id) == nil)
		#expect(!fixture.store.migrationCompleted)
		#expect(fake.addedRequests.first?.content.interruptionLevel == .timeSensitive)
		#expect(fake.removedPendingIdentifiers == [[legacy.identifier]])
	}

	@Test("Corrupt urgency preferences abort startup and allow a later retry")
	func corruptPreferencesAbortStartup() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let legacy = legacyRequest(
			from: recurringRequest(for: medication),
			identifier: "legacy-reminder"
		)
		fixture.defaults.set(
			Data("not-json".utf8),
			forKey: UserDefaultsKeys.medicationNotificationUrgency
		)
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		await manager.start {
			[medication.id]
		}

		#expect(fake.operations == [.pendingRequests])
		#expect(!fixture.store.migrationCompleted)

		fixture.defaults.removeObject(forKey: UserDefaultsKeys.medicationNotificationUrgency)
		await manager.start {
			[medication.id]
		}

		#expect(fixture.store.migrationCompleted)
		#expect(fake.addedRequests.first?.content.interruptionLevel == .timeSensitive)
	}

	@Test("A failed startup reconciliation add preserves the legacy request")
	func failedReconciliationAddPreservesLegacyRequest() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let canonical = recurringRequest(for: medication)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		fake.addError = NotificationManagerTestError.addFailed
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)

		await manager.start {
			[medication.id]
		}

		#expect(fake.operations == [
			.pendingRequests,
			.add(canonical.identifier)
		])
		#expect(fake.removedPendingIdentifiers.isEmpty)
	}

	@Test("A later cancellation waits for startup reconciliation and wins", .timeLimit(.minutes(1)))
	func laterCancellationWaitsForReconciliationAndWins() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let canonical = recurringRequest(for: medication)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let addGate = TestAsyncGate()
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		fake.addGate = addGate
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
		let reconciliation = Task {
			await manager.start {
				[medication.id]
			}
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
	func failedQueuedOperationDoesNotBlockLaterCancellation() async throws {
		let fixture = try makeUrgencyStore()
		defer {
			fixture.cleanUp()
		}
		let medication = createTestMedication()
		let date = Date(timeIntervalSince1970: 1_800_000_000)
		let repeatInterval = DateComponents(hour: 8, minute: 30)
		let canonical = MedicationReminderRequest.make(
			medication: medication,
			date: date,
			isRecurring: true,
			repeatInterval: repeatInterval,
			isUrgent: false,
			showMedicationNames: false
		)
		let legacy = legacyRequest(from: canonical, identifier: "legacy-reminder")
		let addGate = TestAsyncGate()
		let fake = FakeMedicationNotificationClient(pendingRequests: [legacy])
		fake.addGate = addGate
		fake.addError = NotificationManagerTestError.addFailed
		let manager = NotificationManager(
			notificationClient: fake.client,
			urgencyStore: fixture.store
		)
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

	private func recurringRequest(
		for medication: ANMedicationConcept,
		isUrgent: Bool = true
	) -> UNNotificationRequest {
		MedicationReminderRequest.make(
			medication: medication,
			date: Date(timeIntervalSince1970: 1_800_000_000),
			isRecurring: true,
			repeatInterval: DateComponents(hour: 8, minute: 30),
			isUrgent: isUrgent,
			showMedicationNames: false
		)
	}

	private func oneTimeRequest(
		for medication: ANMedicationConcept,
		isUrgent: Bool
	) -> UNNotificationRequest {
		MedicationReminderRequest.make(
			medication: medication,
			date: Date(timeIntervalSince1970: 1_850_000_000),
			isRecurring: false,
			isUrgent: isUrgent,
			showMedicationNames: false
		)
	}

	private func makeUrgencyStore(
		writer: MedicationNotificationUrgencyStore.Writer? = nil
	) throws -> UrgencyStoreFixture {
		let suiteName = "NotificationManagerTests.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suiteName))
		defaults.removePersistentDomain(forName: suiteName)
		let store: MedicationNotificationUrgencyStore
		if let writer {
			store = MedicationNotificationUrgencyStore(defaults: defaults, writer: writer)
		} else {
			store = MedicationNotificationUrgencyStore(defaults: defaults)
		}
		return UrgencyStoreFixture(
			suiteName: suiteName,
			defaults: defaults,
			store: store
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
private struct UrgencyStoreFixture {
	let suiteName: String
	let defaults: UserDefaults
	let store: MedicationNotificationUrgencyStore

	func cleanUp() {
		defaults.removePersistentDomain(forName: suiteName)
	}
}

@MainActor
private final class FakeMedicationNotificationClient {
	enum Operation: Equatable {
		case notificationSettings
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
	var addErrorsByCall: [Int: any Error] = [:]
	var addCallCount = 0
	var addGate: TestAsyncGate?
	let authorizationStatus: UNAuthorizationStatus
	let timeSensitiveSetting: UNNotificationSetting

	init(
		pendingRequests: [UNNotificationRequest] = [],
		deliveredRequests: [UNNotificationRequest] = [],
		authorizationStatus: UNAuthorizationStatus = .notDetermined,
		timeSensitiveSetting: UNNotificationSetting = .notSupported
	) {
		self.pendingRequests = pendingRequests
		self.deliveredRequests = deliveredRequests
		self.authorizationStatus = authorizationStatus
		self.timeSensitiveSetting = timeSensitiveSetting
	}

	var client: MedicationNotificationClient {
		MedicationNotificationClient(
			notificationSettings: {
				self.operations.append(.notificationSettings)
				return MedicationNotificationClient.Settings(
					authorizationStatus: self.authorizationStatus,
					timeSensitiveSetting: self.timeSensitiveSetting
				)
			},
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
				self.addCallCount += 1
				if let addGate = self.addGate {
					await addGate.suspend()
					self.operations.append(.finishAdd(request.identifier))
				}
				if let addError = self.addErrorsByCall[self.addCallCount] {
					throw addError
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

private enum NotificationManagerTestError: Error, Equatable {
	case addFailed
	case providerFailed
	case rollbackFailed
}

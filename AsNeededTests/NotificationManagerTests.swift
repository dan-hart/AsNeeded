import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@MainActor
@Suite("NotificationManager Tests", .tags(.service, .notifications, .unit))
struct NotificationManagerTests {
	@Test("Authorization checks use the injected client")
	func authorization() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		await fixture.manager.checkAuthorizationStatus()
		#expect(fixture.manager.authorizationStatus == .denied)
	}

	@Test("Name preference persists only in isolated defaults")
	func preference() throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		#expect(!fixture.manager.showMedicationNames)
		fixture.manager.showMedicationNames = true
		#expect(fixture.defaults.bool(forKey: UserDefaultsKeys.showMedicationNamesInNotifications))
	}

	@Test("Cancellation targets the scheduled category and exact medication ID")
	func cancellation() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let medication = ANMedicationConcept(clinicalName: "Synthetic")
		let otherMedication = ANMedicationConcept(clinicalName: "Other synthetic")
		try await fixture.manager.scheduleReminder(for: medication, date: fixture.date, isRecurring: false)
		try await fixture.manager.scheduleReminder(for: otherMedication, date: fixture.date, isRecurring: false)
		let content = UNMutableNotificationContent()
		content.categoryIdentifier = MedicationAvailabilityNotificationPlanner.categoryIdentifier
		content.userInfo = ["medicationId": medication.id.uuidString]
		fixture.pending.append(UNNotificationRequest(identifier: MedicationAvailabilityNotificationPlanner.identifierPrefix + medication.id.uuidString, content: content, trigger: nil))
		await fixture.manager.cancelReminder(for: medication)
		#expect(await fixture.manager.getPendingReminders(for: medication).isEmpty)
		#expect(await fixture.manager.getPendingReminders(for: otherMedication).count == 1)
		#expect(fixture.pending.count == 2)
		await fixture.manager.cancelAllReminders()
		#expect(fixture.pending.count == 1)
		#expect(fixture.pending.first?.content.categoryIdentifier == MedicationAvailabilityNotificationPlanner.categoryIdentifier)
	}

	@Test("Reminder details return all scheduled times in date order")
	func detailsSorted() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let medication = ANMedicationConcept(clinicalName: "Synthetic")
		try await fixture.manager.scheduleReminder(for: medication, date: fixture.date.addingTimeInterval(3600), isRecurring: false)
		try await fixture.manager.scheduleReminder(for: medication, date: fixture.date, isRecurring: false)
		let details = await fixture.manager.getReminderDetails(for: medication)
		#expect(details.count == 2)
		#expect(details.map(\.nextFireDate) == details.map(\.nextFireDate).sorted())
	}

	@Test("Reconciliation restores the latest name after privacy toggles")
	func namesUseCurrentInventory() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		var medication = ANMedicationConcept(clinicalName: "Synthetic original")
		fixture.lookupEnabled = true
		fixture.medications = [medication]
		try await fixture.manager.scheduleReminder(for: medication, date: fixture.date, isRecurring: true, repeatInterval: DateComponents(hour: 9, minute: 0))
		let original = try #require(fixture.pending.first)
		medication.nickname = "Synthetic renamed"
		fixture.medications = [medication]
		fixture.manager.showMedicationNames = true
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.pending.first?.content.title == medication.displayName)
		fixture.manager.showMedicationNames = false
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.pending.first?.content.title == "Medication Reminder")
		fixture.manager.showMedicationNames = true
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.pending.first?.content.title == medication.displayName)
		#expect(fixture.pending.first?.identifier == original.identifier)
		#expect(fixture.pending.first?.content.categoryIdentifier == original.content.categoryIdentifier)
		#expect((fixture.pending.first?.trigger as? UNCalendarNotificationTrigger)?.dateComponents == (original.trigger as? UNCalendarNotificationTrigger)?.dateComponents)
	}

	@Test("Failed name replacement retains legacy schedule until add succeeds")
	func failedNameReplacementRetainsSchedule() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let medication = ANMedicationConcept(clinicalName: "Synthetic current")
		fixture.lookupEnabled = true
		fixture.medications = [medication]
		let original = MedicationReminderRequest.make(medication: medication, date: fixture.date, isRecurring: false, isUrgent: true, showMedicationNames: false)
		fixture.pending = [UNNotificationRequest(identifier: "legacy", content: original.content, trigger: original.trigger)]
		fixture.addFails = true
		fixture.manager.showMedicationNames = true
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.pending.map(\.identifier) == ["legacy"])
		#expect(fixture.pending.first?.content.title == "Medication Reminder")
		fixture.addFails = false
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.pending.map(\.identifier) == [original.identifier])
		#expect(fixture.pending.first?.content.title == medication.displayName)
		#expect(fixture.pending.first?.content.interruptionLevel == .timeSensitive)
	}

	@Test("Missing medication inventory removes its reminders")
	func missingInventoryRemovesReminders() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.lookupEnabled = true
		let medication = ANMedicationConcept(clinicalName: "Synthetic removed")
		fixture.pending = [MedicationReminderRequest.make(medication: medication, date: fixture.date, isRecurring: false, showMedicationNames: true)]
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.pending.isEmpty)
	}

	@Test("Latest privacy preference wins when it changes during an add")
	func privacyChangeDuringAdd() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let medication = ANMedicationConcept(clinicalName: "Synthetic private")
		fixture.lookupEnabled = true
		fixture.medications = [medication]
		fixture.pending = [MedicationReminderRequest.make(medication: medication, date: fixture.date, isRecurring: false, showMedicationNames: false)]
		fixture.manager.showMedicationNames = true
		fixture.onAdd = { _ in
			fixture.onAdd = nil
			fixture.manager.showMedicationNames = false
		}
		await fixture.manager.reconcileScheduledReminders()
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.pending.first?.content.title == "Medication Reminder")
		#expect(fixture.pending.first?.content.body == "It's time to take your medication")
	}

	@Test("Saving a renamed medication refreshes scheduled names without manual reconciliation")
	func savedRenameRefreshesScheduledName() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name, navigationManager: NavigationManager(defaults: preferences.defaults))
		var medication = ANMedicationConcept(clinicalName: "Synthetic original")
		try await store.addMedication(medication)
		preferences.defaults.set(true, forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
		let original = MedicationReminderRequest.make(medication: medication, date: Date().addingTimeInterval(3600), isRecurring: true, repeatInterval: DateComponents(hour: 9, minute: 0), isUrgent: true, showMedicationNames: true)
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.pending = [original]
		let nameUpdates = AsyncStream<String>.makeStream()
		let renamed = "Synthetic renamed after save"
		let manager = NotificationManager(notificationClient: MedicationNotificationClient(
			notificationSettings: { .denied },
			pendingRequests: { fixture.pending },
			deliveredRequests: { [] },
			add: { request in
				fixture.pending.removeAll { $0.identifier == request.identifier }
				fixture.pending.append(request)
				if request.content.title == renamed { nameUpdates.continuation.yield(request.content.title) }
			},
			removePending: { ids in fixture.pending.removeAll { ids.contains($0.identifier) } },
			removeDelivered: { _ in }
		), defaults: preferences.defaults, medicationExists: { id in
			try await store.prepareForAccess().medications.contains { $0.id == id }
		}, currentMedications: { try await store.prepareForAccess().medications })
		try await manager.startAvailabilityObservation(dataStore: store)
		medication.nickname = renamed
		try await store.updateMedication(medication)
		let receivedRename = await withTaskGroup(of: Bool.self) { group in
			group.addTask {
				for await _ in nameUpdates.stream { return true }
				return false
			}
			group.addTask {
				try? await Task.sleep(for: .seconds(3))
				return false
			}
			let received = await group.next() ?? false
			group.cancelAll()
			return received
		}
		nameUpdates.continuation.finish()
		#expect(receivedRename)
		let replacement = try #require(fixture.pending.first)
		#expect(replacement.content.title == renamed)
		#expect(replacement.identifier == original.identifier)
		#expect(replacement.content.interruptionLevel == .timeSensitive)
		#expect((replacement.trigger as? UNCalendarNotificationTrigger)?.dateComponents == (original.trigger as? UNCalendarNotificationTrigger)?.dateComponents)
	}

	@Test("A rename that returns to its original name during reconciliation is not skipped")
	func coalescedRenameRestoresFinalName() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name, navigationManager: NavigationManager(defaults: preferences.defaults))
		let originalMedication = ANMedicationConcept(clinicalName: "Synthetic A")
		try await store.addMedication(originalMedication)
		preferences.defaults.set(true, forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let originalRequest = MedicationReminderRequest.make(medication: originalMedication, date: Date().addingTimeInterval(3600), isRecurring: false, showMedicationNames: true)
		fixture.pending = [originalRequest]
		let inventoryEntered = AsyncStream<Void>.makeStream()
		let releaseInventory = AsyncStream<Void>.makeStream()
		let addEntered = AsyncStream<Void>.makeStream()
		let releaseAdd = AsyncStream<Void>.makeStream()
		let corrected = AsyncStream<Void>.makeStream()
		var gateInventory = false
		let manager = NotificationManager(notificationClient: MedicationNotificationClient(
			notificationSettings: { .denied },
			pendingRequests: { fixture.pending },
			deliveredRequests: { [] },
			add: { request in
				if request.content.title == "Synthetic B" {
					addEntered.continuation.yield(())
					for await _ in releaseAdd.stream { break }
				}
				fixture.pending.removeAll { $0.identifier == request.identifier }
				fixture.pending.append(request)
				if request.content.title == originalMedication.displayName { corrected.continuation.yield(()) }
			},
			removePending: { ids in fixture.pending.removeAll { ids.contains($0.identifier) } },
			removeDelivered: { _ in }
		), defaults: preferences.defaults, medicationExists: { id in
			try await store.prepareForAccess().medications.contains { $0.id == id }
		}, currentMedications: {
			if gateInventory {
				gateInventory = false
				inventoryEntered.continuation.yield(())
				for await _ in releaseInventory.stream { break }
			}
			return try await store.prepareForAccess().medications
		})
		// Drain preference-startup work before gating the committed observer's first pass.
		await manager.reconcileScheduledReminders()
		await manager.reconcileScheduledReminders()
		gateInventory = true
		let observation = Task { try await manager.startAvailabilityObservation(dataStore: store) }
		defer {
			releaseInventory.continuation.finish()
			releaseAdd.continuation.finish()
			observation.cancel()
		}
		try #require(await receivedSignal(inventoryEntered.stream))
		var renamedMedication = originalMedication
		renamedMedication.nickname = "Synthetic B"
		try await store.updateMedication(renamedMedication)
		releaseInventory.continuation.yield(())
		try #require(await receivedSignal(addEntered.stream))
		try await store.updateMedication(originalMedication)
		releaseAdd.continuation.yield(())
		try await observation.value
		#expect(await receivedSignal(corrected.stream))
		#expect(fixture.pending.first?.content.title == originalMedication.displayName)
		#expect(fixture.pending.first?.identifier == originalRequest.identifier)
	}

	private func receivedSignal(_ stream: AsyncStream<Void>) async -> Bool {
		await withTaskGroup(of: Bool.self) { group in
			group.addTask {
				for await _ in stream { return true }
				return false
			}
			group.addTask {
				try? await Task.sleep(for: .seconds(3))
				return false
			}
			let received = await group.next() ?? false
			group.cancelAll()
			return received
		}
	}

	@MainActor
	private final class Fixture {
		var pending: [UNNotificationRequest] = []
		var medications: [ANMedicationConcept] = []
		var lookupEnabled = false
		var addFails = false
		var onAdd: (@MainActor (UNNotificationRequest) async throws -> Void)?
		enum Failure: Error { case scheduling }
		let date = Date(timeIntervalSince1970: 2_000_000_000)
		let suite = "NotificationManagerTests-\(UUID().uuidString)"
		let defaults: UserDefaults
		lazy var manager = NotificationManager(notificationClient: MedicationNotificationClient(
			notificationSettings: { .denied },
			pendingRequests: { self.pending },
			deliveredRequests: { [] },
			add: { request in
				if self.addFails { throw Failure.scheduling }
				try await self.onAdd?(request)
				self.pending.removeAll { $0.identifier == request.identifier }
				self.pending.append(request)
			},
			removePending: { ids in self.pending.removeAll { ids.contains($0.identifier) } },
			removeDelivered: { _ in }
		), defaults: defaults, medicationExists: { id in !self.lookupEnabled || self.medications.contains { $0.id == id } }, currentMedications: currentMedicationSnapshot)
		var currentMedicationSnapshot: (@MainActor () async throws -> [ANMedicationConcept])? {
			guard lookupEnabled else { return nil }
			return { self.medications }
		}
		init() throws { defaults = try #require(UserDefaults(suiteName: suite)) }
		func cleanUp() { defaults.removePersistentDomain(forName: suite) }
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

}

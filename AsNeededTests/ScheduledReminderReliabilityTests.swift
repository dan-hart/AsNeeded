import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@MainActor
@Suite("Scheduled reminder reliability", .tags(.service, .notifications, .unit))
struct ScheduledReminderReliabilityTests {
	@Test("Equivalent schedules replace instead of duplicating and keep ordinary priority")
	func stableSchedule() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let medication = fixture.medication
		try await fixture.manager.scheduleReminder(for: medication, date: fixture.date, isRecurring: true, repeatInterval: DateComponents(hour: 8, minute: 30))
		try await fixture.manager.scheduleReminder(for: medication, date: fixture.date.addingTimeInterval(100), isRecurring: true, repeatInterval: DateComponents(hour: 8, minute: 30))
		#expect(fixture.client.pending.count == 1)
		#expect(fixture.client.pending.first?.content.interruptionLevel == .active)
	}

	@Test("Reconciliation replaces duplicate legacy requests only after successful add")
	func reconcileLegacy() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let legacy = fixture.request(identifier: "legacy")
		fixture.client.pending = [legacy, fixture.request(identifier: "legacy-duplicate")]
		fixture.client.failAdd = true
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.client.pending.count == 2)
		fixture.client.failAdd = false
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.client.pending.count == 1)
		#expect(fixture.client.pending.first?.identifier != legacy.identifier)
		#expect(fixture.client.pending.first?.content.title == "Medication Reminder")
	}

	@Test("Acknowledging delivery keeps recurring schedules and unrelated availability alerts")
	func acknowledge() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let scheduled = fixture.request(identifier: "scheduled")
		let availability = fixture.request(identifier: "availability", category: MedicationAvailabilityNotificationPlanner.categoryIdentifier)
		fixture.client.pending = [scheduled, availability]
		fixture.client.delivered = [scheduled, availability]
		await fixture.manager.acknowledgeDeliveredReminders(for: fixture.medication.id)
		#expect(fixture.client.pending.count == 2)
		#expect(fixture.client.delivered.map(\.identifier) == ["availability"])
	}

	@Test("Removal while add is suspended cannot recreate pending or delivered reminders", arguments: [false, true])
	func removalDuringAdd(reconciling: Bool) async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.client.pauseAdd = true
		if reconciling { fixture.client.pending = [fixture.request(identifier: "legacy")] }
		let schedule = Task {
			if reconciling { await fixture.manager.reconcileScheduledReminders() }
			else { try await fixture.manager.scheduleReminder(for: fixture.medication, date: fixture.date, isRecurring: false) }
		}
		await fixture.client.waitForAdd()
		fixture.client.exists = false
		let removal = Task { await fixture.manager.removeMedicationNotificationArtifacts(for: [fixture.medication.id]) }
		await fixture.client.waitForRemovalGeneration { fixture.manager.removalGeneration(for: fixture.medication.id) > 0 }
		fixture.client.resumeAdd()
		_ = try? await schedule.value
		await removal.value
		#expect(fixture.client.pending.isEmpty)
		#expect(fixture.client.delivered.isEmpty)
	}

	@Test("Inventory failure never canonicalizes a request")
	func inventoryFailure() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.client.pending = [fixture.request(identifier: "legacy")]
		fixture.client.failInventory = true
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.client.pending.map(\.identifier) == ["legacy"])
		#expect(fixture.client.addCount == 0)
	}

	@Test("Reconciliation removes canonical and delivered-only reminders for absent medications")
	func removeOrphans() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.client.exists = false
		fixture.client.pending = [MedicationReminderRequest.make(medication: fixture.medication, date: fixture.date, isRecurring: true, repeatInterval: DateComponents(hour: 8, minute: 30), showMedicationNames: false)]
		fixture.client.delivered = [fixture.request(identifier: "delivered")]
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.client.pending.isEmpty)
		#expect(fixture.client.delivered.isEmpty)
		#expect(fixture.client.addCount == 0)
	}

	@Test("Cancelling a displayed legacy reminder also cancels its in-flight replacement", arguments: [false, true])
	func cancelLegacyDuringReplacement(reconciling: Bool) async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.client.pending = [fixture.request(identifier: "displayed-legacy")]
		let displayed = try #require(await fixture.manager.getReminderDetails(for: fixture.medication).first)
		fixture.client.pauseAdd = true
		let replacement = Task {
			if reconciling { await fixture.manager.reconcileScheduledReminders() }
			else {
				try await fixture.manager.scheduleReminder(for: fixture.medication, date: fixture.date, isRecurring: true, repeatInterval: DateComponents(hour: 8, minute: 30))
			}
		}
		await fixture.client.waitForAdd()
		let cancellation = Task { await fixture.manager.cancelSpecificReminder(withIdentifier: displayed.id) }
		fixture.client.resumeAdd()
		try await replacement.value
		await cancellation.value
		#expect(fixture.client.addCount == 1)
		#expect(fixture.client.pending.isEmpty)
	}

	@Test("Upgrade preserves actual reminder urgency without promoting ordinary reminders", arguments: [false, true])
	func preserveLegacyUrgency(urgent: Bool) async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let original = fixture.request(identifier: "legacy")
		let legacy = try #require(MedicationReminderRequest.updatingUrgency(of: original, isUrgent: urgent))
		fixture.client.pending = [legacy]
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.manager.isUrgent(for: fixture.medication.id) == urgent)
		#expect(fixture.client.pending.first?.content.interruptionLevel == (urgent ? .timeSensitive : .active))
	}

	@Test("Saved per-medication urgency applies to new and reconciled scheduled reminders")
	func savedUrgency() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.defaults.set(try JSONEncoder().encode([fixture.medication.id.uuidString: true]), forKey: UserDefaultsKeys.medicationNotificationUrgency)
		try await fixture.manager.scheduleReminder(for: fixture.medication, date: fixture.date, isRecurring: false)
		#expect(fixture.client.pending.first?.content.interruptionLevel == .timeSensitive)
		fixture.client.pending = [fixture.request(identifier: "legacy")]
		await fixture.manager.reconcileScheduledReminders()
		#expect(fixture.client.pending.first?.content.interruptionLevel == .timeSensitive)
	}

	@Test("Urgency changes preserve schedule, privacy and availability alerts, and survive a new manager")
	func updateUrgency() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let availability = fixture.request(identifier: "availability", category: MedicationAvailabilityNotificationPlanner.categoryIdentifier)
		let scheduled = fixture.request(identifier: "scheduled")
		fixture.client.pending = [scheduled, availability]
		try await fixture.manager.setUrgent(true, for: fixture.medication.id)
		let updated = try #require(fixture.client.pending.first { $0.identifier == "scheduled" })
		#expect(updated.content.interruptionLevel == .timeSensitive)
		#expect(updated.content.title == scheduled.content.title)
		#expect(updated.content.userInfo["medicationId"] as? String == fixture.medication.id.uuidString)
		#expect((updated.trigger as? UNCalendarNotificationTrigger)?.dateComponents == (scheduled.trigger as? UNCalendarNotificationTrigger)?.dateComponents)
		#expect(fixture.client.pending.first { $0.identifier == "availability" }?.content.interruptionLevel == .active)
		let restarted = NotificationManager(notificationClient: fixture.client.api, defaults: fixture.defaults, medicationExists: { _ in true })
		#expect(restarted.isUrgent(for: fixture.medication.id))
		#expect(!restarted.isUrgent(for: UUID()))
		try await restarted.setUrgent(false, for: fixture.medication.id)
		#expect(fixture.client.pending.first { $0.identifier == "scheduled" }?.content.interruptionLevel == .active)
	}

	@Test("A failed urgency replacement restores earlier replacements and retains the old preference")
	func failedUrgencyUpdate() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.client.pending = [fixture.request(identifier: "first"), fixture.request(identifier: "second")]
		fixture.client.failAddAt = [2]
		await #expect(throws: Failure.self) { try await fixture.manager.setUrgent(true, for: fixture.medication.id) }
		#expect(!fixture.manager.isUrgent(for: fixture.medication.id))
		#expect(fixture.client.pending.count == 2)
		#expect(fixture.client.pending.allSatisfy { $0.content.interruptionLevel == .active })
	}

	@Test("A failed preference save restores reminder priority")
	func failedPreferenceSave() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.client.pending = [fixture.request(identifier: "scheduled")]
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults, writer: { _, _, _ in })
		let manager = NotificationManager(notificationClient: fixture.client.api, defaults: fixture.defaults, medicationExists: { _ in true }, urgencyStore: store)
		await #expect(throws: NotificationManager.OperationError.self) { try await manager.setUrgent(true, for: fixture.medication.id) }
		#expect(!manager.isUrgent(for: fixture.medication.id))
		#expect(fixture.client.pending.first?.content.interruptionLevel == .active)
	}

	@Test("Removal during urgency replacement cannot recreate reminders or a preference")
	func removalDuringUrgency() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		fixture.client.pending = [fixture.request(identifier: "scheduled")]
		fixture.client.pauseAdd = true
		let change = Task { try await fixture.manager.setUrgent(true, for: fixture.medication.id) }
		await fixture.client.waitForAdd()
		fixture.client.exists = false
		let removal = Task { await fixture.manager.removeMedicationNotificationArtifacts(for: [fixture.medication.id]) }
		await fixture.client.waitForRemovalGeneration { fixture.manager.removalGeneration(for: fixture.medication.id) > 0 }
		fixture.client.resumeAdd()
		_ = try? await change.value
		await removal.value
		#expect(fixture.client.pending.isEmpty)
		#expect(!fixture.manager.isUrgent(for: fixture.medication.id))
	}

	@Test("Corrupt urgency preferences are preserved and prevent an urgency update")
	func corruptUrgency() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		let corrupt = Data("invalid".utf8)
		fixture.defaults.set(corrupt, forKey: UserDefaultsKeys.medicationNotificationUrgency)
		await #expect(throws: NotificationManager.OperationError.self) { try await fixture.manager.setUrgent(true, for: fixture.medication.id) }
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == corrupt)
		#expect(fixture.client.addCount == 0)
	}

	@MainActor
	private final class Fixture {
		let client = Client()
		let medication = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		let date = Date(timeIntervalSince1970: 2_000_000_000)
		let defaults: UserDefaults
		let suite = "ScheduledReminderReliability-\(UUID().uuidString)"
		lazy var manager = NotificationManager(notificationClient: client.api, defaults: defaults, medicationExists: { [client] _ in
			if client.failInventory { throw Failure.expected }
			return client.exists
		})

		init() throws { defaults = try #require(UserDefaults(suiteName: suite)) }
		func cleanUp() { defaults.removePersistentDomain(forName: suite) }
		func request(identifier: String, category: String = "MEDICATION_REMINDER") -> UNNotificationRequest {
			let content = UNMutableNotificationContent()
			content.title = "Synthetic private name"
			content.categoryIdentifier = category
			content.userInfo = ["medicationId": medication.id.uuidString]
			return UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 8, minute: 30), repeats: true))
		}
	}

	private enum Failure: Error { case expected }
	@MainActor
	private final class Client {
		var pending: [UNNotificationRequest] = []
		var delivered: [UNNotificationRequest] = []
		var exists = true
		var failInventory = false
		var failAddAt: Set<Int> = []
		var failAdd = false
		var pauseAdd = false
		var addCount = 0
		var addContinuation: CheckedContinuation<Void, Never>?
		var enteredContinuation: CheckedContinuation<Void, Never>?
		lazy var api = MedicationNotificationClient(
			notificationSettings: { .authorized },
			pendingRequests: { self.pending },
			deliveredRequests: { self.delivered },
			add: { request in
				self.addCount += 1
				if self.failAdd || self.failAddAt.contains(self.addCount) { throw Failure.expected }
				if self.pauseAdd {
					await withCheckedContinuation { continuation in
						self.addContinuation = continuation
						self.enteredContinuation?.resume()
						self.enteredContinuation = nil
					}
				}
				self.pending.removeAll { $0.identifier == request.identifier }
				self.pending.append(request)
			},
			removePending: { ids in self.pending.removeAll { ids.contains($0.identifier) } },
			removeDelivered: { ids in self.delivered.removeAll { ids.contains($0.identifier) } }
		)
		func waitForAdd() async {
			if addContinuation != nil { return }
			await withCheckedContinuation { enteredContinuation = $0 }
		}
		func resumeAdd() { addContinuation?.resume(); addContinuation = nil }
		func waitForRemovalGeneration(_ ready: () -> Bool) async {
			while !ready() { await Task.yield() }
		}
	}
}

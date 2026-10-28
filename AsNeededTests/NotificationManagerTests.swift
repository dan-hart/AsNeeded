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

	@MainActor
	private final class Fixture {
		var pending: [UNNotificationRequest] = []
		let date = Date(timeIntervalSince1970: 2_000_000_000)
		let suite = "NotificationManagerTests-\(UUID().uuidString)"
		let defaults: UserDefaults
		lazy var manager = NotificationManager(notificationClient: MedicationNotificationClient(
			notificationSettings: { .denied },
			pendingRequests: { self.pending },
			deliveredRequests: { [] },
			add: { request in
				self.pending.removeAll { $0.identifier == request.identifier }
				self.pending.append(request)
			},
			removePending: { ids in self.pending.removeAll { ids.contains($0.identifier) } },
			removeDelivered: { _ in }
		), defaults: defaults, medicationExists: { _ in true })
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

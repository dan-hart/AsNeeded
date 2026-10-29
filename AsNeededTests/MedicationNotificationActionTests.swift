import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@MainActor
@Suite("Medication notification actions")
struct MedicationNotificationActionTests {
	private func action(_ identifier: String = "LOG_ACTION", medicationID: UUID) throws -> MedicationNotificationAction {
		try #require(MedicationNotificationAction(actionIdentifier: identifier, requestIdentifier: "synthetic-reminder",
			categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: medicationID.uuidString))
	}

	@Test("Log is registered as an authenticated background action")
	func categories() throws {
		for category in MedicationNotificationAction.categories {
			guard [MedicationReminderRequest.categoryIdentifier, MedicationAvailabilityNotificationPlanner.categoryIdentifier].contains(category.identifier) else {
				#expect(!category.actions.contains { $0.identifier == "LOG_ACTION" })
				continue
			}
			let log = try #require(category.actions.first { $0.identifier == "LOG_ACTION" })
			#expect(log.title == "Log")
			#expect(!log.options.contains(.foreground))
			#expect(log.options.contains(.authenticationRequired))
		}
		#expect(MedicationNotificationAction.categories.count == 4)
	}

	@Test("Body taps open the exact dose form without saving", arguments: [UNNotificationDefaultActionIdentifier])
	func opensExactMedication(identifier: String) async throws {
		let preferences = try IsolatedTestPreferences()
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let seed = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let target = ANMedicationConcept(clinicalName: "Synthetic A", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		let other = ANMedicationConcept(clinicalName: "Synthetic B", quantity: 20, prescribedUnit: .tablet, prescribedDoseAmount: 3)
		try await seed.addMedication(target)
		try await seed.addMedication(other)
		let coldStore = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let navigation = NavigationManager(defaults: preferences.defaults)
		navigation.selectedTab = 1
		navigation.pendingLogMedicationID = other.id.uuidString
		navigation.pendingMedicationDetail = other.id.uuidString
		navigation.shouldShowLogDoseChooser = true
		navigation.pendingWidgetRoute = .logDose(other.id)
		let dispatcher = MedicationNotificationActionDispatcher(navigationManager: navigation, removeDelivered: { _ in Issue.record("Opening must not dismiss other reminders") })
		dispatcher.handle(try action(identifier, medicationID: target.id))
		#expect(navigation.selectedTab == 0)
		#expect(navigation.pendingLogMedicationID == target.id.uuidString)
		#expect(navigation.pendingMedicationDetail == nil)
		#expect(!navigation.shouldShowLogDoseChooser)
		#expect(navigation.pendingWidgetRoute == nil)
		// The existing form presenter resolves the queued identity only after storage is ready.
		let snapshot = try await coldStore.prepareForAccess()
		let resolved = LogDosePickerModel.medication(forDeepLink: navigation.pendingLogMedicationID ?? "", from: snapshot.medications)
		#expect(resolved?.id == target.id)
		#expect(snapshot.events.isEmpty)
		#expect(snapshot.medications.first { $0.id == target.id }?.quantity == 10)
		#expect(snapshot.medications.first { $0.id == other.id }?.quantity == 20)
		dispatcher.handle(try action(identifier, medicationID: target.id))
		#expect(navigation.pendingLogMedicationID == target.id.uuidString)
		#expect(coldStore.events.isEmpty)
	}

	@Test("Missing and archived targets never resolve to another medication")
	func unavailable() throws {
		let preferences = try IsolatedTestPreferences()
		let navigation = NavigationManager(defaults: preferences.defaults)
		let dispatcher = MedicationNotificationActionDispatcher(navigationManager: navigation, removeDelivered: { _ in })
		let active = ANMedicationConcept(clinicalName: "Synthetic active")
		var archived = ANMedicationConcept(clinicalName: "Synthetic archived")
		archived.isArchived = true
		for id in [UUID(), archived.id] {
			dispatcher.handle(try action(UNNotificationDefaultActionIdentifier, medicationID: id))
			#expect(navigation.pendingLogMedicationID == id.uuidString)
			#expect(LogDosePickerModel.medication(forDeepLink: id.uuidString, from: [active, archived]) == nil)
		}
	}

	@Test("Skip dismisses only the delivered occurrence and preserves navigation")
	func skip() throws {
		let preferences = try IsolatedTestPreferences()
		let navigation = NavigationManager(defaults: preferences.defaults)
		navigation.selectedTab = 1
		var dismissed: [String] = []
		let dispatcher = MedicationNotificationActionDispatcher(navigationManager: navigation, removeDelivered: { dismissed.append($0) })
		dispatcher.handle(try action("SKIP_ACTION", medicationID: UUID()))
		#expect(dismissed == ["synthetic-reminder"])
		#expect(navigation.pendingLogMedicationID == nil)
		#expect(navigation.selectedTab == 1)
	}

	@Test("Malformed, unrelated, and dismissed responses do not create destinations")
	func invalidResponses() {
		let id = UUID().uuidString
		#expect(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: "request", categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: id)?.kind == .log)
		#expect(MedicationNotificationAction(actionIdentifier: "TAKEN_ACTION", requestIdentifier: "request", categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: id)?.kind == .log)
		#expect(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: "request", categoryIdentifier: "unrelated", medicationID: id) == nil)
		#expect(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: "request", categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: "bad-id") == nil)
		#expect(MedicationNotificationAction(actionIdentifier: UNNotificationDismissActionIdentifier, requestIdentifier: "request", categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: id) == nil)
	}

	@Test("The application delegate exposes the system notification-response selector")
	func notificationDelegateSelector() {
		#expect(AppDelegate().responds(to: NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")))
		#expect(AppDelegate().responds(to: NSSelectorFromString("userNotificationCenter:willPresentNotification:withCompletionHandler:")))
	}

	@Test("Background notification responses finish on main after routing, including ignored payloads", arguments: [true, false])
	func responseCompletionOnMain(valid: Bool) async throws {
		let preferences = try IsolatedTestPreferences()
		let navigation = NavigationManager(defaults: preferences.defaults)
		let id = UUID()
		let responseAction = valid ? try action(UNNotificationDefaultActionIdentifier, medicationID: id) : nil
		let completedOnMain = await withCheckedContinuation { continuation in
			Task.detached {
				AppDelegate.finishNotificationResponse(responseAction, handleAction: { action in
					await Task.yield()
					MedicationNotificationActionDispatcher(navigationManager: navigation, removeDelivered: { _ in }).handle(action)
				}, completionHandler: {
					continuation.resume(returning: Thread.isMainThread)
				})
			}
		}
		#expect(completedOnMain)
		#expect(navigation.pendingLogMedicationID == (valid ? id.uuidString : nil))
	}
}

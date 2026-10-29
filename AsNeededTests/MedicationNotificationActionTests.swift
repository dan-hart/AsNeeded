import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@MainActor
@Suite("Medication notification actions")
struct MedicationNotificationActionTests {
	private let deliveredAt = Date(timeIntervalSince1970: 1_793_200_000)

	private func action(_ identifier: String = "LOG_ACTION", medicationID: UUID, deliveredAt: Date? = nil) throws -> MedicationNotificationAction {
		try #require(MedicationNotificationAction(actionIdentifier: identifier, requestIdentifier: "synthetic-reminder",
			categoryIdentifier: MedicationReminderRequest.categoryIdentifier,
			medicationID: medicationID.uuidString, deliveredAt: deliveredAt ?? self.deliveredAt, respondedAt: self.deliveredAt.addingTimeInterval(30)))
	}

	@Test("Log is registered for scheduled and availability notifications and foregrounds the app")
	func categories() throws {
		for category in MedicationNotificationAction.categories {
			let log = try #require(category.actions.first { $0.identifier == "LOG_ACTION" })
			#expect(log.title == "Log")
			#expect(log.options.contains(.foreground))
		}
		#expect(MedicationNotificationAction.categories.count == 2)
	}

	@Test("Old delivered action IDs still log, recurring occurrences have distinct durable event IDs")
	func compatibilityAndIdentity() throws {
		let id = UUID()
		let current = try action(medicationID: id)
		#expect(try action("TAKEN_ACTION", medicationID: id).eventID == current.eventID)
		#expect(try action(medicationID: id).eventID == current.eventID)
		#expect(try action(medicationID: id, deliveredAt: deliveredAt.addingTimeInterval(86_400)).eventID != current.eventID)
		#expect(try action(UNNotificationDefaultActionIdentifier, medicationID: id).kind == .open)
		#expect(try action("SKIP_ACTION", medicationID: id).kind == .skip)
		#expect(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: "request", categoryIdentifier: "unrelated", medicationID: id.uuidString, deliveredAt: deliveredAt) == nil)
		#expect(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: "request", categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: "bad-id", deliveredAt: deliveredAt) == nil)
		#expect(MedicationNotificationAction(actionIdentifier: UNNotificationDismissActionIdentifier, requestIdentifier: "request", categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: id.uuidString, deliveredAt: deliveredAt) == nil)
	}

	@Test("Log saves the exact medication and prescribed dose once, survives replay after restart, and supports Undo")
	func logsAndUndo() async throws {
		let preferences = try IsolatedTestPreferences()
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		var store = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let target = ANMedicationConcept(clinicalName: "Synthetic A", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		let other = ANMedicationConcept(clinicalName: "Synthetic B", quantity: 20, prescribedUnit: .tablet, prescribedDoseAmount: 3)
		try await store.addMedication(target)
		try await store.addMedication(other)
		// Reopen without preloading, just as a notification can arrive at a cold launch.
		store = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults)
		let request = try action(medicationID: target.id)
		#expect(try await model.handleNotificationAction(request) == .handled)
		#expect(store.events.count == 1)
		#expect(store.events.first?.id == request.eventID)
		#expect(store.events.first?.medication?.id == target.id)
		#expect(store.events.first?.dose?.amount == 2)
		#expect(store.events.first?.date == request.respondedAt)
		#expect(store.medications.first { $0.id == target.id }?.quantity == 8)
		#expect(store.medications.first { $0.id == other.id }?.quantity == 20)
		#expect(model.quickLogFeedback?.undoEventID == request.eventID)
		var acknowledged: [UUID] = []
		let restarted = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name, reminderAcknowledgement: { acknowledged.append($0) })
		let restartedModel = MedicationListViewModel(dataStore: restarted, defaults: preferences.defaults)
		#expect(try await restartedModel.handleNotificationAction(request) == .handled)
		#expect(restarted.events.count == 1)
		#expect(acknowledged == [target.id])
		#expect(restarted.medications.first { $0.id == target.id }?.quantity == 8)
		#expect(await restartedModel.undoLastQuickLog(eventID: request.eventID))
		#expect(restarted.events.isEmpty)
		#expect(restarted.medications.first { $0.id == target.id }?.quantity == 10)
	}

	@Test("Body taps open the dose form; missing and archived medications never log a replacement")
	func openAndUnavailable() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet)
		try await store.addMedication(med)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults)
		#expect(try await model.handleNotificationAction(action(UNNotificationDefaultActionIdentifier, medicationID: med.id)) == .handled)
		#expect(model.logMedication?.id == med.id)
		#expect(store.events.isEmpty)
		#expect(try await model.handleNotificationAction(action(medicationID: UUID())) == .unavailable)
		var archived = med
		archived.isArchived = true
		try await store.updateMedication(archived)
		#expect(try await model.handleNotificationAction(action(medicationID: med.id)) == .unavailable)
		#expect(store.events.isEmpty)
	}

	@Test("Failed notification saves roll back stock and can retry without a false confirmation")
	func failedSaveRetry() async throws {
		enum Failure: Error { case injected }
		let preferences = try IsolatedTestPreferences()
		var fail = false
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name, transactionFault: { phase in
				if fail, phase == .beforeCommit { throw Failure.injected }
			})
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		try await store.addMedication(med)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults)
		let request = try action(medicationID: med.id)
		fail = true
		await #expect(throws: MedicationListViewModel.NotificationActionError.saveFailed) {
			try await model.handleNotificationAction(request)
		}
		#expect(store.events.isEmpty)
		#expect(store.medications.first?.quantity == 10)
		#expect(model.quickLogFeedback == nil)
		fail = false
		#expect(try await model.handleNotificationAction(request) == .handled)
		#expect(store.events.count == 1)
		#expect(store.medications.first?.quantity == 8)
	}

	@Test("Cancellation during persistence remains retryable after transaction recovery")
	func cancelledSaveRetries() async throws {
		let preferences = try IsolatedTestPreferences()
		var cancelSave = false
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name, transactionFault: { phase in
				if cancelSave, phase == .beforeCommit {
					withUnsafeCurrentTask { $0?.cancel() }
					throw CancellationError()
				}
			})
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		try await store.addMedication(med)
		let model = MedicationListViewModel(dataStore: store, defaults: preferences.defaults)
		let request = try action(medicationID: med.id)
		cancelSave = true
		let operation = Task { try await model.handleNotificationAction(request) }
		await #expect(throws: CancellationError.self) { try await operation.value }
		#expect(model.quickLogFeedback == nil)
		cancelSave = false
		#expect(try await model.handleNotificationAction(request) == .handled)
		#expect(store.events.count == 1)
		#expect(store.medications.first?.quantity == 8)
	}

	@Test("Dispatcher queues cold-start Log once; Skip only dismisses the delivered occurrence")
	func dispatch() throws {
		let preferences = try IsolatedTestPreferences()
		let navigation = NavigationManager(defaults: preferences.defaults)
		var dismissed: [String] = []
		let dispatcher = MedicationNotificationActionDispatcher(navigationManager: navigation, removeDelivered: { dismissed.append($0) })
		let request = try action(medicationID: UUID())
		dispatcher.handle(request)
		dispatcher.handle(request)
		#expect(navigation.pendingNotificationActions.count == 1)
		#expect(navigation.selectedTab == 0)
		let skip = try action("SKIP_ACTION", medicationID: request.medicationID)
		dispatcher.handle(skip)
		#expect(dismissed == ["synthetic-reminder"])
		#expect(navigation.pendingNotificationActions == [request])
	}
}

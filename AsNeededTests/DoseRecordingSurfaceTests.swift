import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@MainActor
@Suite("Dose recording surfaces")
struct DoseRecordingSurfaceTests {
	@Test("Manual and quick logging keep the selected target, time and exact Undo")
	func appLogging() async throws {
		let ledger = try await Ledger.seeded()
		let model = MedicationListViewModel(dataStore: ledger.store, defaults: ledger.preferences.defaults, now: { ledger.now })
		let draft = LogDoseView.Draft(medication: ledger.target, at: ledger.now)
		let past = ledger.now.addingTimeInterval(-3600)
		draft.selectDate(past)
		let dose = ANDoseConcept(amount: 1.5, unit: .tablet)
		let event = ANEventConcept(eventType: .doseTaken, medication: ledger.other, dose: dose, date: draft.doseDate(at: ledger.now))
		let before = try await ledger.store.prepareForAccess()
		ledger.failCommit = true
		#expect(await !model.logDose(med: ledger.target, dose: dose, event: event, isBackdated: true))
		#expect(await !model.quickLog(medication: ledger.target))
		#expect(model.quickLogFeedback == nil)
		try await ledger.expectUnchanged(from: before)

		ledger.failCommit = false
		#expect(await model.logDose(med: ledger.target, dose: dose, event: event, isBackdated: draft.isBackdated(at: ledger.now)))
		#expect(model.quickLogFeedback?.tone == .success)
		#expect(model.quickLogFeedback?.undoEventID == event.id)
		try await ledger.expectDose(id: event.id, amount: 1.5, date: past, stock: 17.5, count: 2)

		#expect(await model.quickLog(medication: ledger.target))
		let quickID = try #require(model.quickLogFeedback?.undoEventID)
		#expect(quickID != event.id)
		#expect(model.quickLogFeedback?.tone == .warning)
		try await ledger.expectDose(id: quickID, amount: 2, date: ledger.now, stock: 15.5, count: 3)
		#expect(await model.undoLastQuickLog(eventID: quickID))
		try await ledger.expectDose(id: event.id, amount: 1.5, date: past, stock: 17.5, count: 2)
		#expect(!ledger.store.events.contains { $0.id == quickID })
	}

	@Test("Notification opens review and sees a dose already committed by the app")
	func notificationLogging() async throws {
		let ledger = try await Ledger.seeded()
		let navigation = NavigationManager(defaults: ledger.preferences.defaults)
		let logger = NotificationDoseLogger(dataStore: ledger.store, prepare: {}, profile: { _ in .empty }, now: { ledger.now })
		var requests: [UNNotificationRequest] = []
		var removed: [String] = []
		let client = notificationClient(add: { requests.append($0) }, removeDelivered: { removed += $0 })
		let handler = MedicationNotificationResponseHandler(navigationManager: navigation, notifications: client,
			logDose: { try await logger.log($0) }, showNames: { false })
		let before = try await ledger.store.prepareForAccess()
		await handler.handle(try ledger.notification(UNNotificationDefaultActionIdentifier))
		#expect(navigation.pendingLogMedicationID == ledger.target.id.uuidString)
		#expect(requests.isEmpty)
		try await ledger.expectUnchanged(from: before)

		let action = try ledger.notification("LOG_ACTION")
		let model = MedicationListViewModel(dataStore: ledger.store, defaults: ledger.preferences.defaults, now: { ledger.now })
		#expect(await model.quickLog(medication: ledger.target))
		let quickID = try #require(model.quickLogFeedback?.undoEventID)
		let afterAppDose = try await ledger.store.prepareForAccess()
		await handler.handle(action)
		#expect(requests.last?.content.categoryIdentifier == MedicationNotificationAction.reviewCategoryIdentifier)
		#expect(!removed.contains(action.requestIdentifier))
		try await ledger.expectUnchanged(from: afterAppDose)

		#expect(await model.undoLastQuickLog(eventID: quickID))
		await handler.handle(action)
		await handler.handle(action)
		try await ledger.expectDose(id: action.eventID, amount: 2, date: ledger.now, stock: 17, count: 2)
		#expect(requests.map(\.content.categoryIdentifier) == [MedicationNotificationAction.reviewCategoryIdentifier,
			MedicationNotificationAction.confirmationCategoryIdentifier,
			MedicationNotificationAction.confirmationCategoryIdentifier])
		#expect(Set(requests.map(\.identifier)).count == 1)
		#expect(removed.filter { $0 == action.requestIdentifier }.count == 2)
	}

	@Test("Feedback delivery failure leaves a committed dose durable and retryable without another deduction")
	func postCommitNotificationFailure() async throws {
		let ledger = try await Ledger.seeded()
		let action = try ledger.notification("LOG_ACTION")
		let logger = NotificationDoseLogger(dataStore: ledger.store, prepare: {}, profile: { _ in .empty }, now: { ledger.now })
		var attemptedCategories: [String] = []
		let handler = MedicationNotificationResponseHandler(
			navigationManager: NavigationManager(defaults: ledger.preferences.defaults),
			notifications: notificationClient(add: { request in
				attemptedCategories.append(request.content.categoryIdentifier)
				throw InjectedFailure.feedback
			}), logDose: { try await logger.log($0) }, showNames: { false })
		await handler.handle(action)
		try await ledger.expectDose(id: action.eventID, amount: 2, date: ledger.now, stock: 17, count: 2)
		await handler.handle(action)
		try await ledger.expectDose(id: action.eventID, amount: 2, date: ledger.now, stock: 17, count: 2)
		#expect(attemptedCategories == [MedicationNotificationAction.confirmationCategoryIdentifier,
			MedicationNotificationAction.confirmationCategoryIdentifier])
	}

	@Test("Shortcuts honors the explicit entity over a name and reports a failed save accurately")
	func shortcutLogging() async throws {
		let ledger = try await Ledger.seeded()
		var intent = LogMedicationIntent()
		intent.medicationName = ledger.other.clinicalName
		intent.amount = 1.25
		let before = try await ledger.store.prepareForAccess()
		intent.medication = MedicationEntity(medication: ANMedicationConcept(clinicalName: "Unavailable synthetic"))
		let unavailable = try await intent.doseLogDialog(in: ledger.store, now: { ledger.now }, migrate: { _ in })
		#expect(unavailable.key == "That medication is no longer available.")
		try await ledger.expectUnchanged(from: before)

		intent.medication = MedicationEntity(medication: ledger.target)
		ledger.failCommit = true
		let failure = try await intent.doseLogDialog(in: ledger.store, now: { ledger.now }, migrate: { _ in })
		#expect(failure.key == "Sorry, I couldn't log your medication. Please try again or open AsNeeded manually.")
		try await ledger.expectUnchanged(from: before)

		ledger.failCommit = false
		let success = try await intent.doseLogDialog(in: ledger.store, now: { ledger.now }, migrate: { _ in })
		#expect(String(localized: success).contains(ledger.target.displayName))
		#expect(!String(localized: success).contains(ledger.other.displayName))
		let event = try #require(ledger.store.events.first { $0.id != ledger.priorID })
		try await ledger.expectDose(id: event.id, amount: 1.25, date: ledger.now, stock: 17.75, count: 2)
	}

	@Test("Watch recording preserves a queued event's target and date, and only acknowledges a commit")
	func watchLogging() async throws {
		let ledger = try await Ledger.seeded()
		let id = UUID()
		let date = ledger.now.addingTimeInterval(-600)
		let keys = SharedPlatformContracts.WatchMessage.self
		let payload: [String: Any] = [
			keys.medicationId: ledger.target.id.uuidString,
			keys.eventID: id.uuidString,
			keys.date: date,
			keys.doseAmount: 0.5,
			keys.doseUnit: ANUnitConcept.tablet.rawValue,
			keys.quantityConsumed: 1.0,
		]
		let decoded = try #require(SendableMessage(from: [keys.logDose: payload]).logDoseData)
		let before = try await ledger.store.prepareForAccess()
		ledger.failCommit = true
		await #expect(throws: InjectedFailure.self) {
			try await WCReceiver.recordDose(decoded, in: ledger.store, now: { ledger.now }, migrate: { _ in })
		}
		try await ledger.expectUnchanged(from: before)

		ledger.failCommit = false
		#expect(try await WCReceiver.recordDose(decoded, in: ledger.store, now: { ledger.now }, migrate: { _ in }))
		#expect(try await WCReceiver.recordDose(decoded, in: ledger.store, now: { ledger.now.addingTimeInterval(1200) }, migrate: { _ in }))
		try await ledger.expectDose(id: id, amount: 0.5, date: date, stock: 18.5, count: 2)

		let mismatches: [(String, Any)] = [
			(keys.medicationId, ledger.other.id.uuidString),
			(keys.doseAmount, 1.0),
			(keys.doseUnit, ANUnitConcept.milligram.rawValue),
		]
		for (key, value) in mismatches {
			var conflictingPayload = payload
			conflictingPayload[key] = value
			let conflictingRetry = try #require(SendableMessage(from: [keys.logDose: conflictingPayload]).logDoseData)
			await #expect(throws: PersistenceTransactionError.self) {
				try await WCReceiver.recordDose(conflictingRetry, in: ledger.store, now: { ledger.now }, migrate: { _ in })
			}
		}
		try await ledger.expectDose(id: id, amount: 0.5, date: date, stock: 18.5, count: 2)

		var edited = try #require(ledger.store.events.first { $0.id == id })
		edited.date = date.addingTimeInterval(-60)
		try await ledger.store.updateEvent(edited)
		await #expect(throws: PersistenceTransactionError.self) {
			try await WCReceiver.recordDose(decoded, in: ledger.store, now: { ledger.now }, migrate: { _ in })
		}
		try await ledger.expectDose(id: id, amount: 0.5, date: edited.date, stock: 18.5, count: 2)

		try await ledger.store.deleteEvents(ids: [id])
		try await ledger.expectUnchanged(from: before)
	}

	@Test("Widget dose links navigate to the exact target or fail with the ledger untouched")
	func widgetNavigation() async throws {
		let ledger = try await Ledger.seeded()
		let navigation = NavigationManager(defaults: ledger.preferences.defaults)
		let before = try await ledger.store.prepareForAccess()
		let url = try #require(WidgetNavigationRoute.logDose(ledger.target.id).url)
		let route = try #require(WidgetNavigationRoute(url: url))
		#expect(navigation.applyWidgetRoute(route, medications: before.medications))
		#expect(navigation.pendingLogMedicationID == ledger.target.id.uuidString)
		let unavailable = try #require(WidgetNavigationRoute.logDose(UUID()).url)
		let unavailableRoute = try #require(WidgetNavigationRoute(url: unavailable))
		#expect(!navigation.applyWidgetRoute(unavailableRoute, medications: before.medications))
		#expect(navigation.showWidgetUnavailable)
		#expect(navigation.pendingLogMedicationID == nil)
		#expect(!navigation.shouldShowLogDoseChooser)
		try await ledger.expectUnchanged(from: before)
	}

	private func notificationClient(
		add: @escaping @MainActor (UNNotificationRequest) async throws -> Void,
		removeDelivered: @escaping @MainActor ([String]) -> Void = { _ in }
	) -> MedicationNotificationClient {
		MedicationNotificationClient(notificationSettings: { .authorized }, pendingRequests: { [] },
			deliveredRequests: { [] }, add: add, removePending: { _ in }, removeDelivered: removeDelivered)
	}

	private enum InjectedFailure: Error { case commit, feedback }

	@MainActor
	private final class Ledger {
		let now = Date(timeIntervalSince1970: 1_790_000_000)
		let preferences: IsolatedTestPreferences
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DoseRecordingSurfaces-\(UUID().uuidString)")
		let target = ANMedicationConcept(clinicalName: "Synthetic target", quantity: 20,
			prescribedUnit: .tablet, prescribedDoseAmount: 2, minimumHoursBetweenDoses: 4)
		let other = ANMedicationConcept(clinicalName: "Synthetic other", quantity: 41,
			prescribedUnit: .tablet, prescribedDoseAmount: 4)
		let priorID = UUID()
		var failCommit = false
		lazy var store = DataStore(storageDirectory: directory, defaults: preferences.defaults,
			defaultsDomainName: preferences.name, navigationManager: NavigationManager(defaults: preferences.defaults),
			transactionFault: { [weak self] phase in
				if self?.failCommit == true, phase == .beforeCommit { throw InjectedFailure.commit }
			})

		private init() throws { preferences = try IsolatedTestPreferences() }

		static func seeded() async throws -> Ledger {
			let ledger = try Ledger()
			try await ledger.store.addMedication(ledger.other)
			try await ledger.store.addMedication(ledger.target)
			let dose = ANDoseConcept(amount: 1, unit: .tablet)
			try await ledger.store.recordDose(ANEventConcept(id: ledger.priorID, eventType: .doseTaken,
				medication: ledger.target, dose: dose, date: ledger.now.addingTimeInterval(-172_800)))
			return ledger
		}

		func notification(_ identifier: String) throws -> MedicationNotificationAction {
			try #require(MedicationNotificationAction(actionIdentifier: identifier, requestIdentifier: "synthetic-reminder",
				categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: target.id.uuidString,
				deliveredAt: now.addingTimeInterval(-900)))
		}

		func expectDose(id: UUID, amount: Double, date: Date, stock: Double, count: Int) async throws {
			let reader = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name,
				navigationManager: NavigationManager(defaults: preferences.defaults))
			let snapshot = try await reader.prepareForAccess()
			let dose = try #require(snapshot.events.first { $0.id == id })
			#expect(dose.medication?.id == target.id)
			#expect(dose.eventType == .doseTaken)
			#expect(dose.dose?.amount == amount)
			#expect(dose.dose?.unit == .tablet)
			#expect(dose.date == date)
			#expect(snapshot.events.count == count)
			#expect(snapshot.events.contains { $0.id == priorID })
			#expect(snapshot.medications.first { $0.id == target.id }?.quantity == stock)
			#expect(snapshot.medications.first { $0.id == other.id }?.quantity == other.quantity)
		}

		func expectUnchanged(from before: MedicationPersistenceSnapshot) async throws {
			let after = try await store.prepareForAccess()
			#expect(Set(after.events) == Set(before.events))
			#expect(Set(after.medications) == Set(before.medications))
		}
	}
}

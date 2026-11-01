import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@MainActor
struct NotificationDoseLoggerTests {
	private let now = Date(timeIntervalSince1970: 1_790_000_000)

	private func action(_ med: ANMedicationConcept, deliveredAt: Date? = nil) throws -> MedicationNotificationAction {
		try #require(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: "synthetic-recurring",
			categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: med.id.uuidString,
			deliveredAt: deliveredAt ?? now))
	}

	private func store(_ preferences: IsolatedTestPreferences) -> DataStore {
		DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name,
			navigationManager: NavigationManager(defaults: preferences.defaults))
	}

	@Test("Background Log prepares cold storage, saves the current prescribed dose atomically and records recency")
	func coldSave() async throws {
		let preferences = try IsolatedTestPreferences()
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let seed = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		var med = ANMedicationConcept(clinicalName: "Private synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		try await seed.addMedication(med)
		let cold = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		var prepared = false
		let logger = NotificationDoseLogger(dataStore: cold, prepare: {
			med.prescribedDoseAmount = 3
			try await seed.updateMedication(med)
			prepared = true
		}, profile: { _ in .empty }, now: { #expect(prepared); return now })
		let saved = try await logger.log(try action(med))
		#expect(saved.dose?.amount == 3)
		#expect(saved.date == now)
		#expect(cold.events.count == 1)
		#expect(cold.medications.first?.quantity == 7)
		#expect(cold.lastLoggedMedication?.id == med.id)
		#expect(preferences.defaults.stringArray(forKey: UserDefaultsKeys.lastLoggedDoseEventIDs)?.first == saved.id.uuidString)
	}

	@Test("Replaying an occurrence preserves the original dose and date even after prescription edits and archival")
	func replay() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = store(preferences)
		var med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		try await store.addMedication(med)
		let logger = NotificationDoseLogger(dataStore: store, prepare: {}, profile: { _ in .empty }, now: { now })
		let response = try action(med)
		async let first = logger.log(response)
		async let second = logger.log(response)
		let (a, b) = try await (first, second)
		#expect(a.id == b.id)
		#expect(store.events.count == 1)
		#expect(store.medications.first?.quantity == 8)
		med = try #require(store.medications.first)
		med.prescribedDoseAmount = 4
		med.prescribedUnit = .milligram
		med.isArchived = true
		try await store.updateMedication(med)
		let replayed = try await logger.log(response)
		#expect(replayed == a)
		#expect(store.medications.first?.quantity == 8)
		#expect(store.events.count == 1)
		#expect(response.eventID != (try action(med, deliveredAt: now.addingTimeInterval(86400))).eventID)
	}

	@Test("Missing dose details and saved guidance needing review never mutate stock", arguments:
		["amount", "unit", "zero", "archived", "deleted", "interval", "maximum", "units", "caution", "duplicate"])
	func requiresReview(reason: String) async throws {
		let preferences = try IsolatedTestPreferences()
		let store = store(preferences)
		var med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 2)
		var profile = MedicationSafetyProfile.empty
		if reason == "amount" { med.prescribedDoseAmount = nil }
		if reason == "unit" { med.prescribedUnit = nil }
		if reason == "zero" { med.prescribedDoseAmount = 0 }
		if reason == "archived" { med.isArchived = true }
		if reason == "interval" { med.minimumHoursBetweenDoses = 4 }
		if reason == "maximum" { med.maximumDailyDoseAmount = 2 }
		if reason == "units" { med.maximumDailyDoseAmount = 4 }
		if reason == "caution" { profile.cautionHoursBetweenDoses = 4 }
		try await store.addMedication(med)
		if ["interval", "maximum", "units", "caution", "duplicate"].contains(reason) {
			try await store.addEvent(ANEventConcept(eventType: .doseTaken, medication: med,
				dose: ANDoseConcept(amount: reason == "duplicate" ? 2 : 1, unit: reason == "units" ? .milligram : .tablet),
				date: now.addingTimeInterval(reason == "duplicate" ? -60 : -7200)))
		}
		if reason == "deleted" { try await store.deleteMedication(med) }
		let before = try await store.prepareForAccess()
		let logger = NotificationDoseLogger(dataStore: store, prepare: {}, profile: { _ in profile }, now: { now })
		await #expect(throws: (any Error).self) { try await logger.log(try action(med)) }
		let after = try await store.prepareForAccess()
		#expect(after.medications == before.medications)
		#expect(after.events == before.events)
	}

	@Test("Distinct occurrences racing for the same medication assess earlier commits inside the transaction")
	func competingOccurrences() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = store(preferences)
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet,
			prescribedDoseAmount: 1, minimumHoursBetweenDoses: 4)
		try await store.addMedication(med)
		var clockReads = 0
		let logger = NotificationDoseLogger(dataStore: store, prepare: {}, profile: { _ in .empty }, now: {
			clockReads += 1
			return now.addingTimeInterval(Double(clockReads))
		})
		let a = try action(med)
		let b = try action(med, deliveredAt: now.addingTimeInterval(-86400))
		async let first = try? logger.log(a)
		async let second = try? logger.log(b)
		let results = await [first, second].compactMap { $0 }
		#expect(results.count == 1)
		#expect(store.events.count == 1)
		#expect(store.medications.first?.quantity == 9)
		#expect(clockReads == 2)
	}

	@Test("Preparation and transaction failures leave no partial dose or recency change", arguments: [true, false])
	func failedSave(preparation: Bool) async throws {
		enum Failure: Error { case injected }
		let preferences = try IsolatedTestPreferences()
		var fail = false
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name,
			transactionFault: { phase in if fail && phase == .beforeCommit { throw Failure.injected } })
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet, prescribedDoseAmount: 1)
		try await store.addMedication(med)
		fail = !preparation
		let logger = NotificationDoseLogger(dataStore: store,
			prepare: { if preparation { throw Failure.injected } }, profile: { _ in .empty }, now: { now })
		await #expect(throws: (any Error).self) { try await logger.log(try action(med)) }
		fail = false
		let after = try await store.prepareForAccess()
		#expect(after.events.isEmpty)
		#expect(after.medications.first?.quantity == 10)
		#expect(preferences.defaults.stringArray(forKey: UserDefaultsKeys.lastLoggedDoseEventIDs) == nil)
	}
}

@MainActor
struct NotificationDoseFeedbackTests {
	@Test("A successful retry replaces earlier failure feedback for the same occurrence")
	func feedbackRetry() async throws {
		enum Failure: Error { case injected }
		let preferences = try IsolatedTestPreferences()
		let navigation = NavigationManager(defaults: preferences.defaults)
		let med = ANMedicationConcept(clinicalName: "Synthetic")
		let action = try #require(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: "reminder",
			categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: med.id.uuidString))
		var delivered: [String: UNNotificationRequest] = [:]
		var fails = true
		let client = MedicationNotificationClient(notificationSettings: { .authorized }, pendingRequests: { [] },
			deliveredRequests: { Array(delivered.values) }, add: { delivered[$0.identifier] = $0 },
			removePending: { _ in }, removeDelivered: { ids in for id in ids { delivered[id] = nil } })
		let handler = MedicationNotificationResponseHandler(navigationManager: navigation, notifications: client,
			logDose: { _ in
				if fails { throw Failure.injected }
				return ANEventConcept(eventType: .doseTaken, medication: med)
			}, showNames: { false })
		await handler.handle(action)
		#expect(delivered.values.first?.content.title == "Dose not logged")
		fails = false
		await handler.handle(action)
		#expect(delivered.count == 1)
		#expect(delivered.values.first?.content.title == "Dose logged")
	}

	@Test("Background success feedback is private by default and never opens the app", arguments: [false, true])
	func success(showNames: Bool) async throws {
		let preferences = try IsolatedTestPreferences()
		let navigation = NavigationManager(defaults: preferences.defaults)
		navigation.selectedTab = 2
		let med = ANMedicationConcept(clinicalName: "Private synthetic", prescribedUnit: .tablet, prescribedDoseAmount: 2)
		let event = ANEventConcept(eventType: .doseTaken, medication: med, dose: ANDoseConcept(amount: 2, unit: .tablet))
		let action = try #require(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: "reminder",
			categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: med.id.uuidString))
		var requests: [UNNotificationRequest] = []
		let client = MedicationNotificationClient(notificationSettings: { .authorized }, pendingRequests: { [] },
			deliveredRequests: { [] }, add: { requests.append($0) }, removePending: { _ in }, removeDelivered: { _ in })
		await MedicationNotificationResponseHandler(navigationManager: navigation, notifications: client,
			logDose: { _ in event }, showNames: { showNames }).handle(action)
		let feedback = try #require(requests.first)
		#expect(requests.count == 1)
		#expect(feedback.content.title == "Dose logged")
		#expect(feedback.content.body.contains(med.clinicalName) == showNames)
		#expect(feedback.content.sound == nil)
		#expect(navigation.selectedTab == 2)
		#expect(navigation.pendingLogMedicationID == nil)
		let tap = try #require(MedicationNotificationAction(actionIdentifier: UNNotificationDefaultActionIdentifier,
			requestIdentifier: feedback.identifier, categoryIdentifier: feedback.content.categoryIdentifier,
			medicationID: feedback.content.userInfo[MedicationReminderRequest.medicationIDKey] as? String))
		#expect(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: feedback.identifier,
			categoryIdentifier: feedback.content.categoryIdentifier, medicationID: med.id.uuidString) == nil)
		await MedicationNotificationResponseHandler(navigationManager: navigation, notifications: client,
			logDose: { _ in Issue.record("Feedback taps must not log another dose"); return event }, showNames: { false }).handle(tap)
		#expect(navigation.selectedTab == 1)
		#expect(navigation.historyTargetMedicationID == med.id.uuidString)
		#expect(requests.count == 1)
	}

	@Test("Save failure reports no save; feedback delivery failure cannot misreport a committed dose", arguments: [true, false])
	func failures(saveFails: Bool) async throws {
		enum Failure: Error { case injected }
		let preferences = try IsolatedTestPreferences()
		let navigation = NavigationManager(defaults: preferences.defaults)
		let med = ANMedicationConcept(clinicalName: "Private synthetic")
		let event = ANEventConcept(eventType: .doseTaken, medication: med)
		let action = try #require(MedicationNotificationAction(actionIdentifier: "LOG_ACTION", requestIdentifier: "reminder",
			categoryIdentifier: MedicationReminderRequest.categoryIdentifier, medicationID: med.id.uuidString))
		var requests: [UNNotificationRequest] = []
		var saves = 0
		let client = MedicationNotificationClient(notificationSettings: { .authorized }, pendingRequests: { [] },
			deliveredRequests: { [] }, add: { requests.append($0); if !saveFails { throw Failure.injected } },
			removePending: { _ in }, removeDelivered: { _ in })
		await MedicationNotificationResponseHandler(navigationManager: navigation, notifications: client,
			logDose: { _ in saves += 1; if saveFails { throw Failure.injected }; return event }, showNames: { false }).handle(action)
		#expect(saves == 1)
		#expect(requests.count == 1)
		let feedback = try #require(requests.first)
		#expect(feedback.content.title == (saveFails ? "Dose not logged" : "Dose logged"))
		#expect(!feedback.content.body.contains(med.clinicalName))
		if saveFails {
			let tap = try #require(MedicationNotificationAction(actionIdentifier: UNNotificationDefaultActionIdentifier,
				requestIdentifier: feedback.identifier, categoryIdentifier: feedback.content.categoryIdentifier, medicationID: med.id.uuidString))
			MedicationNotificationActionDispatcher(navigationManager: navigation, removeDelivered: { _ in }).handle(tap)
			#expect(navigation.pendingLogMedicationID == med.id.uuidString)
		}
	}
}

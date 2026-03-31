import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationLiveActivityStateBuilder Tests", .tags(.unit))
struct MedicationLiveActivityStateBuilderTests {
	private final class MockSession: MedicationLiveActivitySession, @unchecked Sendable {
		var updates: [MedicationLiveActivityContent] = []
		var endCount = 0

		func update(content: MedicationLiveActivityContent) async {
			updates.append(content)
		}

		func end() async {
			endCount += 1
		}
	}

	private final class MockClient: MedicationLiveActivityClient, @unchecked Sendable {
		var activitiesEnabled: Bool
		let storedSessions: [MockSession]
		var requestedContents: [MedicationLiveActivityContent] = []
		var shouldThrowOnRequest = false

		init(activitiesEnabled: Bool, storedSessions: [MockSession] = []) {
			self.activitiesEnabled = activitiesEnabled
			self.storedSessions = storedSessions
		}

		func sessions() -> [any MedicationLiveActivitySession] {
			storedSessions
		}

		func request(content: MedicationLiveActivityContent) async throws {
			if shouldThrowOnRequest {
				struct MockError: Error {}
				throw MockError()
			}

			requestedContents.append(content)
		}
	}

	private func medication(
		name: String,
		quantity: Double? = 30,
		unit: ANUnitConcept = .tablet
	) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: name,
			nickname: nil,
			quantity: quantity,
			initialQuantity: quantity,
			lastRefillDate: Date().addingTimeInterval(-7 * 86_400),
			nextRefillDate: Date().addingTimeInterval(5 * 86_400),
			prescribedUnit: unit,
			prescribedDoseAmount: 1
		)
	}

	private func event(
		for medication: ANMedicationConcept,
		hoursAgo: Double,
		amount: Double = 1
	) -> ANEventConcept {
		ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: amount, unit: medication.prescribedUnit ?? .tablet),
			date: Date().addingTimeInterval(-(hoursAgo * 3600))
		)
	}

	@Test("Snapshot is nil when there are no active medications")
	func snapshotIsNilWithoutMedications() {
		let builder = MedicationLiveActivityStateBuilder()

		#expect(
			builder.snapshot(
				medications: [],
				events: [],
				safetyProfiles: [:]
			) == nil
		)
	}

	@Test("Snapshot prefers a medication that can be taken now")
	func snapshotPrefersAvailableMedication() {
		let builder = MedicationLiveActivityStateBuilder()
		let availableMedication = medication(name: "Ibuprofen", quantity: 4)
		let delayedMedication = medication(name: "Naproxen", quantity: 12)
		let profiles = [
			delayedMedication.id.uuidString: MedicationSafetyProfile(
				minimumHoursBetweenDoses: 4,
				lowStockThreshold: 6
			),
			availableMedication.id.uuidString: MedicationSafetyProfile(
				lowStockThreshold: 6
			),
		]

		let snapshot = builder.snapshot(
			medications: [delayedMedication, availableMedication],
			events: [event(for: delayedMedication, hoursAgo: 1)],
			safetyProfiles: profiles
		)

		#expect(snapshot?.medicationID == availableMedication.id.uuidString)
		#expect(snapshot?.canTakeNow == true)
		#expect(snapshot?.statusText == "Available now")
		#expect(snapshot?.lowStock == true)
		#expect(snapshot?.detailText.contains("Low stock") == true)
	}

	@Test("Snapshot formats the next-dose state when a medication is not yet available")
	func snapshotFormatsUpcomingDoseState() {
		let builder = MedicationLiveActivityStateBuilder()
		let delayedMedication = medication(name: "Naproxen", quantity: 12)
		let profiles = [
			delayedMedication.id.uuidString: MedicationSafetyProfile(minimumHoursBetweenDoses: 4),
		]

		let snapshot = builder.snapshot(
			medications: [delayedMedication],
			events: [event(for: delayedMedication, hoursAgo: 1)],
			safetyProfiles: profiles
		)

		#expect(snapshot?.canTakeNow == false)
		#expect(snapshot?.statusText.contains("Next dose") == true)
		#expect(snapshot?.detailText.isEmpty == false)
	}

	@Test("Refresh requests a live activity when enabled and none exist")
	func refreshRequestsActivityWhenMissing() async {
		let client = MockClient(activitiesEnabled: true)
		let medication = medication(name: "Ibuprofen", quantity: 8)

		await MedicationLiveActivityManager.refresh(
			medications: [medication],
			events: [],
			safetyProfiles: [:],
			liveActivityClient: client
		)

		#expect(client.requestedContents.count == 1)
		#expect(client.requestedContents.first?.medicationName == "Ibuprofen")
	}

	@Test("Refresh swallows request failures from the live activity client")
	func refreshIgnoresRequestFailures() async {
		let client = MockClient(activitiesEnabled: true)
		client.shouldThrowOnRequest = true
		let medication = medication(name: "Ibuprofen", quantity: 8)

		await MedicationLiveActivityManager.refresh(
			medications: [medication],
			events: [],
			safetyProfiles: [:],
			liveActivityClient: client
		)

		#expect(client.requestedContents.isEmpty)
	}

	@Test("Refresh updates the first activity and ends extras")
	func refreshUpdatesExistingActivityAndEndsExtras() async {
		let primarySession = MockSession()
		let secondarySession = MockSession()
		let client = MockClient(
			activitiesEnabled: true,
			storedSessions: [primarySession, secondarySession]
		)
		let medication = medication(name: "Ibuprofen", quantity: 8)

		await MedicationLiveActivityManager.refresh(
			medications: [medication],
			events: [],
			safetyProfiles: [:],
			liveActivityClient: client
		)

		#expect(primarySession.updates.count == 1)
		#expect(primarySession.endCount == 0)
		#expect(secondarySession.endCount == 1)
	}

	@Test("Refresh ends activities when the capability is unavailable")
	func refreshEndsActivitiesWhenDisabled() async {
		let session = MockSession()
		let client = MockClient(
			activitiesEnabled: false,
			storedSessions: [session]
		)
		let medication = medication(name: "Ibuprofen", quantity: 8)

		await MedicationLiveActivityManager.refresh(
			medications: [medication],
			events: [],
			safetyProfiles: [:],
			liveActivityClient: client
		)

		#expect(session.endCount == 1)
		#expect(client.requestedContents.isEmpty)
	}

	@Test("Refresh ends activities when there is no medication to display")
	func refreshEndsActivitiesForEmptyState() async {
		let session = MockSession()
		let client = MockClient(
			activitiesEnabled: true,
			storedSessions: [session]
		)

		await MedicationLiveActivityManager.refresh(
			medications: [],
			events: [],
			safetyProfiles: [:],
			liveActivityClient: client
		)

		#expect(session.endCount == 1)
		#expect(client.requestedContents.isEmpty)
	}

	@MainActor
	@Test("RefreshFromDataStore reads medications and events from the supplied store")
	func refreshFromDataStoreUsesProvidedStore() async throws {
		let dataStore = DataStore(testIdentifier: "LiveActivity-RefreshFromStore")
		let client = MockClient(activitiesEnabled: true)
		let medication = medication(name: "Acetaminophen", quantity: 10)
		try await dataStore.addMedication(medication)

		await MedicationLiveActivityManager.refreshFromDataStore(
			dataStore: dataStore,
			safetyProfiles: [:],
			liveActivityClient: client
		)

		#expect(client.requestedContents.count == 1)
		#expect(client.requestedContents.first?.medicationName == "Acetaminophen")
	}

	@Test("EndAll ends every active session from the client")
	func endAllEndsActiveSessions() async {
		let firstSession = MockSession()
		let secondSession = MockSession()
		let client = MockClient(
			activitiesEnabled: true,
			storedSessions: [firstSession, secondSession]
		)

		await MedicationLiveActivityManager.endAll(liveActivityClient: client)

		#expect(firstSession.endCount == 1)
		#expect(secondSession.endCount == 1)
	}
}

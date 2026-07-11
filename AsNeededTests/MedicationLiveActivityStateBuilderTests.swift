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
		id: UUID = UUID(),
		name: String,
		quantity: Double? = 30,
		nextRefillDate: Date? = nil,
		unit: ANUnitConcept = .tablet
	) -> ANMedicationConcept {
		ANMedicationConcept(
			id: id,
			clinicalName: name,
			nickname: nil,
			quantity: quantity,
			initialQuantity: quantity,
			lastRefillDate: nil,
			nextRefillDate: nextRefillDate,
			prescribedUnit: unit,
			prescribedDoseAmount: 1
		)
	}

	@Test("Snapshot is nil when there are no active medications")
	func snapshotIsNilWithoutMedications() {
		let builder = MedicationLiveActivityStateBuilder()

		#expect(
			builder.snapshot(
				medications: [],
				events: [],
				refillProfiles: [:]
			) == nil
		)
	}

	@Test("Snapshot prioritizes low stock before refill soon and alphabetical medications")
	func snapshotPrioritizesLowStock() {
		let builder = MedicationLiveActivityStateBuilder()
		let date = Date(timeIntervalSince1970: 1_735_689_600)
		let alphabeticalMedication = medication(name: "Acetaminophen", quantity: 30)
		let refillSoonMedication = medication(
			name: "Ibuprofen",
			quantity: 30,
			nextRefillDate: date.addingTimeInterval(3 * 86_400)
		)
		let lowStockMedication = medication(name: "Naproxen", quantity: 4)
		let profiles = [
			lowStockMedication.id.uuidString: MedicationRefillProfile(lowStockThreshold: 6),
		]

		let snapshot = builder.snapshot(
			at: date,
			medications: [alphabeticalMedication, refillSoonMedication, lowStockMedication],
			events: [],
			refillProfiles: profiles
		)

		#expect(snapshot?.medicationID == lowStockMedication.id.uuidString)
		#expect(snapshot?.statusText == "Low stock")
		#expect(snapshot?.lowStock == true)
		#expect(snapshot?.detailText == "Refill prep would be timely.")
		#expect(snapshot?.staleDate == date.addingTimeInterval(30 * 60))
	}

	@Test("Snapshot prioritizes refill soon before alphabetical medications")
	func snapshotPrioritizesRefillSoon() {
		let builder = MedicationLiveActivityStateBuilder()
		let date = Date(timeIntervalSince1970: 1_735_689_600)
		let alphabeticalMedication = medication(name: "Acetaminophen", quantity: 30)
		let refillSoonMedication = medication(
			name: "Naproxen",
			quantity: 30,
			nextRefillDate: date.addingTimeInterval(3 * 86_400)
		)

		let snapshot = builder.snapshot(
			at: date,
			medications: [alphabeticalMedication, refillSoonMedication],
			events: [],
			refillProfiles: [:]
		)

		#expect(snapshot?.medicationID == refillSoonMedication.id.uuidString)
		#expect(snapshot?.statusText == "Refill soon")
		#expect(snapshot?.detailText == "You’re approaching your refill window.")
	}

	@Test("Snapshot uses deterministic alphabetical and identifier tie breaking")
	func snapshotUsesDeterministicTieBreaking() {
		let builder = MedicationLiveActivityStateBuilder()
		let laterID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb") ?? UUID()
		let earlierID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa") ?? UUID()
		let naproxen = medication(name: "Naproxen", quantity: 30)
		let laterIbuprofen = medication(id: laterID, name: "ibuprofen", quantity: 30)
		let earlierIbuprofen = medication(id: earlierID, name: "Ibuprofen", quantity: 30)

		let snapshot = builder.snapshot(
			medications: [naproxen, laterIbuprofen, earlierIbuprofen],
			events: [],
			refillProfiles: [:]
		)

		#expect(snapshot?.medicationID == earlierIbuprofen.id.uuidString)
		#expect(snapshot?.statusText == "Refill status")
		#expect(snapshot?.detailText == "Log more doses to estimate your run-out date.")
	}

	@Test("Live Activity snapshot, content, and ActivityKit state omit dose eligibility")
	func liveActivityStateOmitsDoseEligibility() {
		let medication = medication(name: "Ibuprofen", quantity: 4)
		let snapshot = MedicationLiveActivityStateBuilder().snapshot(
			medications: [medication],
			events: [],
			refillProfiles: [:]
		)
		let snapshotLabelValues: [String] = snapshot.map {
			Mirror(reflecting: $0).children.compactMap(\.label)
		} ?? []
		let snapshotLabels = Set(snapshotLabelValues)
		let contentLabelValues: [String] = snapshot.map {
			Mirror(reflecting: MedicationLiveActivityContent(snapshot: $0)).children.compactMap(\.label)
		} ?? []
		let contentLabels = Set(contentLabelValues)

		#expect(!snapshotLabels.contains("nextDoseDate"))
		#expect(!snapshotLabels.contains("canTakeNow"))
		#expect(!contentLabels.contains("nextDoseDate"))
		#expect(!contentLabels.contains("canTakeNow"))

		#if canImport(ActivityKit)
			let state = MedicationLiveActivityAttributes.ContentState(
				medicationID: medication.id.uuidString,
				medicationName: medication.displayName,
				symbolName: "pills.fill",
				statusText: "Low stock",
				detailText: "Refill prep would be timely.",
				lowStock: true,
				refillSoon: true
			)
			let stateLabels = Set(Mirror(reflecting: state).children.compactMap(\.label))
			#expect(!stateLabels.contains("nextDoseDate"))
			#expect(!stateLabels.contains("canTakeNow"))
			#expect(state.medicationURL == URL(string: "asneeded://log/\(medication.id.uuidString)"))
			#expect(state.compactStatusAccessibilityLabel == "Low stock for Ibuprofen")

			let refillState = MedicationLiveActivityAttributes.ContentState(
				medicationID: medication.id.uuidString,
				medicationName: medication.displayName,
				symbolName: "pills.fill",
				statusText: "Refill soon",
				detailText: "You’re approaching your refill window.",
				lowStock: false,
				refillSoon: true
			)
			#expect(refillState.compactStatusAccessibilityLabel == "Refill soon for Ibuprofen")

			var normalState = refillState
			normalState.refillSoon = false
			#expect(normalState.compactStatusAccessibilityLabel == "Refill status for Ibuprofen")
		#endif
	}

	@Test("Refresh requests a live activity when enabled and none exist")
	func refreshRequestsActivityWhenMissing() async {
		let client = MockClient(activitiesEnabled: true)
		let medication = medication(name: "Ibuprofen", quantity: 8)

		await MedicationLiveActivityManager.refresh(
			medications: [medication],
			events: [],
			refillProfiles: [:],
			liveActivityClient: client
		)

		#expect(client.requestedContents.count == 1)
		#expect(client.requestedContents.first?.medicationName == "Ibuprofen")
	}

	@MainActor
	@Test("Live Activity medication URL routes to the featured medication log surface")
	func medicationURLRoutesToMedicationLog() throws {
		let medicationID = try #require(UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
		let handler = QuickActionHandler.shared
		handler.pendingAction = nil

		handler.handleURL(try #require(URL(string: "asneeded://log/\(medicationID.uuidString)")))

		#expect(handler.pendingAction == .logDose(medicationID: medicationID))
		handler.pendingAction = nil
	}

	@Test("Refresh swallows request failures from the live activity client")
	func refreshIgnoresRequestFailures() async {
		let client = MockClient(activitiesEnabled: true)
		client.shouldThrowOnRequest = true
		let medication = medication(name: "Ibuprofen", quantity: 8)

		await MedicationLiveActivityManager.refresh(
			medications: [medication],
			events: [],
			refillProfiles: [:],
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
			refillProfiles: [:],
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
			refillProfiles: [:],
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
			refillProfiles: [:],
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
			refillProfiles: [:],
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

import ANModelKit
import Foundation

#if canImport(ActivityKit)
	import ActivityKit
#endif

struct MedicationLiveActivitySnapshot: Equatable {
	let medicationID: String
	let medicationName: String
	let symbolName: String
	let statusText: String
	let detailText: String
	let lowStock: Bool
	let refillSoon: Bool
	let staleDate: Date?
}

struct MedicationLiveActivityContent: Equatable {
	let medicationID: String
	let medicationName: String
	let symbolName: String
	let statusText: String
	let detailText: String
	let lowStock: Bool
	let refillSoon: Bool
	let staleDate: Date?

	init(snapshot: MedicationLiveActivitySnapshot) {
		medicationID = snapshot.medicationID
		medicationName = snapshot.medicationName
		symbolName = snapshot.symbolName
		statusText = snapshot.statusText
		detailText = snapshot.detailText
		lowStock = snapshot.lowStock
		refillSoon = snapshot.refillSoon
		staleDate = snapshot.staleDate
	}
}

protocol MedicationLiveActivitySession: Sendable {
	func update(content: MedicationLiveActivityContent) async
	func end() async
}

protocol MedicationLiveActivityClient: Sendable {
	var activitiesEnabled: Bool { get }
	func sessions() -> [any MedicationLiveActivitySession]
	func request(content: MedicationLiveActivityContent) async throws
}

struct MedicationLiveActivityStateBuilder {
	private let refillProjectionService: MedicationRefillProjectionService

	init(
		calendar: Calendar = .current,
		refillProjectionService: MedicationRefillProjectionService? = nil
	) {
		self.refillProjectionService = refillProjectionService ?? MedicationRefillProjectionService(calendar: calendar)
	}

	func snapshot(
		at date: Date = .now,
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		refillProfiles: [String: MedicationRefillProfile]
	) -> MedicationLiveActivitySnapshot? {
		let activeMedications = medications.filter { !$0.isArchived }
		guard let medication = featuredMedication(
			at: date,
			medications: activeMedications,
			events: events,
			refillProfiles: refillProfiles
		) else {
			return nil
		}

		let profile = refillProfiles[medication.id.uuidString] ?? .empty
		let refillProjection = refillProjectionService.projection(
			for: medication,
			at: date,
			events: events,
			profile: profile
		)
		let statusText = if refillProjection.lowStock {
			"Low stock"
		} else if refillProjection.refillSoon {
			"Refill soon"
		} else {
			"Refill status"
		}

		return MedicationLiveActivitySnapshot(
			medicationID: medication.id.uuidString,
			medicationName: medication.displayName,
			symbolName: medication.symbolInfo?.name ?? "pills.fill",
			statusText: statusText,
			detailText: refillProjection.statusMessage,
			lowStock: refillProjection.lowStock,
			refillSoon: refillProjection.refillSoon,
			staleDate: date.addingTimeInterval(30 * 60)
		)
	}

	private func featuredMedication(
		at date: Date,
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		refillProfiles: [String: MedicationRefillProfile]
	) -> ANMedicationConcept? {
		medications.min { left, right in
			let leftPriority = priority(for: left, at: date, events: events, refillProfiles: refillProfiles)
			let rightPriority = priority(for: right, at: date, events: events, refillProfiles: refillProfiles)

			if leftPriority != rightPriority {
				return leftPriority < rightPriority
			}

			let nameOrder = left.displayName.localizedCaseInsensitiveCompare(right.displayName)
			if nameOrder != .orderedSame {
				return nameOrder == .orderedAscending
			}

			return left.id.uuidString < right.id.uuidString
		}
	}

	private func priority(
		for medication: ANMedicationConcept,
		at date: Date,
		events: [ANEventConcept],
		refillProfiles: [String: MedicationRefillProfile]
	) -> Int {
		let profile = refillProfiles[medication.id.uuidString] ?? .empty
		let projection = refillProjectionService.projection(
			for: medication,
			at: date,
			events: events,
			profile: profile
		)

		if projection.lowStock {
			return 0
		}
		if projection.refillSoon {
			return 1
		}
		return 2
	}
}

#if canImport(ActivityKit)
struct MedicationLiveActivityAttributes: ActivityAttributes {
	public struct ContentState: Codable, Hashable {
		var medicationID: String
		var medicationName: String
		var symbolName: String
		var statusText: String
		var detailText: String
		var lowStock: Bool
		var refillSoon: Bool
	}

	var title: String
}

private struct SystemMedicationLiveActivitySession: MedicationLiveActivitySession, @unchecked Sendable {
	let activity: Activity<MedicationLiveActivityAttributes>

	func update(content: MedicationLiveActivityContent) async {
		await activity.update(activityContent(from: content))
	}

	func end() async {
		await activity.end(nil, dismissalPolicy: .immediate)
	}
}

private struct SystemMedicationLiveActivityClient: MedicationLiveActivityClient, @unchecked Sendable {
	var activitiesEnabled: Bool {
		ActivityAuthorizationInfo().areActivitiesEnabled
	}

	func sessions() -> [any MedicationLiveActivitySession] {
		Activity<MedicationLiveActivityAttributes>.activities.map(SystemMedicationLiveActivitySession.init)
	}

	func request(content: MedicationLiveActivityContent) async throws {
		_ = try Activity.request(
			attributes: MedicationLiveActivityAttributes(title: "As Needed"),
			content: activityContent(from: content),
			pushType: nil
		)
	}
}

private func activityContent(from content: MedicationLiveActivityContent) -> ActivityContent<MedicationLiveActivityAttributes.ContentState> {
	ActivityContent(
		state: MedicationLiveActivityAttributes.ContentState(
			medicationID: content.medicationID,
			medicationName: content.medicationName,
			symbolName: content.symbolName,
			statusText: content.statusText,
			detailText: content.detailText,
			lowStock: content.lowStock,
			refillSoon: content.refillSoon
		),
		staleDate: content.staleDate
	)
}

enum MedicationLiveActivityManager {
	@MainActor
	static func refreshFromDataStore(
		dataStore: DataStore = .shared,
		refillProfiles: [String: MedicationRefillProfile]? = nil,
		liveActivityClient: any MedicationLiveActivityClient = SystemMedicationLiveActivityClient()
	) async {
		await refresh(
			medications: dataStore.medications,
			events: dataStore.events,
			refillProfiles: refillProfiles ?? MedicationRefillProfileStore.shared.allProfiles(),
			liveActivityClient: liveActivityClient
		)
	}

	static func refresh(
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		refillProfiles: [String: MedicationRefillProfile],
		liveActivityClient: any MedicationLiveActivityClient
	) async {
		guard #available(iOS 16.2, *) else {
			return
		}

		let sessions = liveActivityClient.sessions()

		guard liveActivityClient.activitiesEnabled else {
			await end(sessions)
			return
		}

		let stateBuilder = MedicationLiveActivityStateBuilder()

		guard let snapshot = stateBuilder.snapshot(
			medications: medications,
			events: events,
			refillProfiles: refillProfiles
		) else {
			await end(sessions)
			return
		}

		let content = MedicationLiveActivityContent(snapshot: snapshot)

		if let session = sessions.first {
			await session.update(content: content)

			if sessions.count > 1 {
				await end(Array(sessions.dropFirst()))
			}

			return
		}

		do {
			try await liveActivityClient.request(content: content)
		} catch {
			// Ignore request failures so the rest of the app can continue normally.
		}
	}

	static func endAll(
		liveActivityClient: any MedicationLiveActivityClient = SystemMedicationLiveActivityClient()
	) async {
		guard #available(iOS 16.2, *) else {
			return
		}

		await end(liveActivityClient.sessions())
	}

	@available(iOS 16.2, *)
	private static func end(_ sessions: [any MedicationLiveActivitySession]) async {
		for session in sessions {
			await session.end()
		}
	}
}
#endif

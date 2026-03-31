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
	let nextDoseDate: Date?
	let canTakeNow: Bool
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
	let nextDoseDate: Date?
	let canTakeNow: Bool
	let lowStock: Bool
	let refillSoon: Bool
	let staleDate: Date?

	init(snapshot: MedicationLiveActivitySnapshot) {
		medicationID = snapshot.medicationID
		medicationName = snapshot.medicationName
		symbolName = snapshot.symbolName
		statusText = snapshot.statusText
		detailText = snapshot.detailText
		nextDoseDate = snapshot.nextDoseDate
		canTakeNow = snapshot.canTakeNow
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
	private let calendar: Calendar
	private let guidanceService: MedicationDoseGuidanceService

	init(
		calendar: Calendar = .current,
		guidanceService: MedicationDoseGuidanceService = MedicationDoseGuidanceService()
	) {
		self.calendar = calendar
		self.guidanceService = guidanceService
	}

	func snapshot(
		at date: Date = .now,
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		safetyProfiles: [String: MedicationSafetyProfile]
	) -> MedicationLiveActivitySnapshot? {
		let activeMedications = medications.filter { !$0.isArchived }
		guard let medication = featuredMedication(
			at: date,
			medications: activeMedications,
			events: events,
			safetyProfiles: safetyProfiles
		) else {
			return nil
		}

		let profile = safetyProfiles[medication.id.uuidString] ?? .empty
		let nextDoseDate = guidanceService.nextEligibleDate(
			for: medication,
			at: date,
			events: events,
			profile: profile
		)
		let refillProjection = guidanceService.refillProjection(
			for: medication,
			at: date,
			events: events,
			profile: profile
		)
		let canTakeNow = nextDoseDate == nil || nextDoseDate ?? .distantPast <= date
			let statusText = {
				if canTakeNow {
					return "Available now"
				}

				return "Next dose \(formattedTime(nextDoseDate ?? date))"
			}()

		var detailFragments: [String] = []
		if refillProjection.lowStock {
			detailFragments.append("Low stock")
		} else if refillProjection.refillSoon {
			detailFragments.append("Refill soon")
		}
		detailFragments.append(refillProjection.statusMessage)

		let staleDate = nextDoseDate?.addingTimeInterval(300) ??
			calendar.date(byAdding: .minute, value: 30, to: date)

		return MedicationLiveActivitySnapshot(
			medicationID: medication.id.uuidString,
			medicationName: medication.displayName,
			symbolName: medication.symbolInfo?.name ?? "pills.fill",
			statusText: statusText,
			detailText: detailFragments.joined(separator: " • "),
			nextDoseDate: nextDoseDate,
			canTakeNow: canTakeNow,
			lowStock: refillProjection.lowStock,
			refillSoon: refillProjection.refillSoon,
			staleDate: staleDate
		)
	}

	private func featuredMedication(
		at date: Date,
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		safetyProfiles: [String: MedicationSafetyProfile]
	) -> ANMedicationConcept? {
		medications.min { left, right in
			let leftDate = dueDate(for: left, at: date, events: events, safetyProfiles: safetyProfiles)
			let rightDate = dueDate(for: right, at: date, events: events, safetyProfiles: safetyProfiles)

			if leftDate == rightDate {
				return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
			}

			return leftDate < rightDate
		}
	}

	private func dueDate(
		for medication: ANMedicationConcept,
		at date: Date,
		events: [ANEventConcept],
		safetyProfiles: [String: MedicationSafetyProfile]
	) -> Date {
		let profile = safetyProfiles[medication.id.uuidString] ?? .empty
		return guidanceService.nextEligibleDate(
			for: medication,
			at: date,
			events: events,
			profile: profile
		) ?? .distantPast
	}

	private func formattedTime(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.timeStyle = .short
		formatter.dateStyle = .none
		return formatter.string(from: date)
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
		var nextDoseDate: Date?
		var canTakeNow: Bool
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
			nextDoseDate: content.nextDoseDate,
			canTakeNow: content.canTakeNow,
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
		safetyProfiles: [String: MedicationSafetyProfile]? = nil,
		liveActivityClient: any MedicationLiveActivityClient = SystemMedicationLiveActivityClient()
	) async {
		await refresh(
			medications: dataStore.medications,
			events: dataStore.events,
			safetyProfiles: safetyProfiles ?? MedicationSafetyProfileStore.shared.allProfiles(),
			liveActivityClient: liveActivityClient
		)
	}

	static func refresh(
		medications: [ANMedicationConcept],
		events: [ANEventConcept],
		safetyProfiles: [String: MedicationSafetyProfile],
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
			safetyProfiles: safetyProfiles
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

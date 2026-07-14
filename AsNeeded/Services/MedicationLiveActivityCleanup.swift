import Foundation

#if canImport(ActivityKit)
	import ActivityKit

	protocol MedicationLiveActivitySession: Sendable {
		func end() async
	}

	protocol MedicationLiveActivityClient: Sendable {
		func sessions() -> [any MedicationLiveActivitySession]
	}

	// Retain build 301's attribute shape for one upgrade cycle so its activities can be dismissed.
	struct MedicationLiveActivityAttributes: ActivityAttributes {
		struct ContentState: Codable, Hashable {
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

		func end() async {
			await activity.end(nil, dismissalPolicy: .immediate)
		}
	}

	private struct SystemMedicationLiveActivityClient: MedicationLiveActivityClient, @unchecked Sendable {
		func sessions() -> [any MedicationLiveActivitySession] {
			Activity<MedicationLiveActivityAttributes>.activities.map(SystemMedicationLiveActivitySession.init)
		}
	}

	enum MedicationLiveActivityCleanup {
		static func endAll(
			liveActivityClient: any MedicationLiveActivityClient = SystemMedicationLiveActivityClient()
		) async {
			guard #available(iOS 16.2, *) else {
				return
			}

			for session in liveActivityClient.sessions() {
				await session.end()
			}
		}
	}
#endif

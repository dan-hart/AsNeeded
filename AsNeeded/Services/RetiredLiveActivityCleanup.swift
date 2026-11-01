#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

// Keep the original decoding shape only to retire activities from earlier builds.
// This type has no widget configuration or activity creation path.
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
#endif

enum RetiredLiveActivityCleanup {
	static func endExistingActivities() async {
		#if os(iOS) && canImport(ActivityKit)
		for activity in Activity<MedicationLiveActivityAttributes>.activities {
			await activity.end(nil, dismissalPolicy: .immediate)
		}
		#endif
	}
}

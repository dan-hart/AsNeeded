import Foundation

#if canImport(ActivityKit)
	import ActivityKit
#endif

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
#endif

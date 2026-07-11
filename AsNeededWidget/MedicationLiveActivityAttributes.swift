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
		var lowStock: Bool
		var refillSoon: Bool

		var medicationURL: URL? {
			URL(string: "asneeded://log/\(medicationID)")
		}

		var compactStatusAccessibilityLabel: String {
			let status = if lowStock {
				"Low stock"
			} else if refillSoon {
				"Refill soon"
			} else {
				"Refill status"
			}
			return "\(status) for \(medicationName)"
		}
	}

	var title: String
}
#endif

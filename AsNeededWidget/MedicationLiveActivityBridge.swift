import ANModelKit
import Foundation

#if canImport(ActivityKit)
	import ActivityKit
#endif

@MainActor
enum MedicationLiveActivityBridge {
	static func refreshFromSharedStores(provider: WidgetDataProvider = .shared) async {
		guard #available(iOSApplicationExtension 16.2, *) else {
			return
		}

		#if canImport(ActivityKit)
			let activities = Activity<MedicationLiveActivityAttributes>.activities
			guard !activities.isEmpty else {
				return
			}

			let lowStockIDs = Set(provider.lowQuantityMedications.map(\.id))
			let refillSoonIDs = Set(provider.refillDueSoon.map(\.id))
			guard let medication = provider.medications.min(by: { left, right in
				let leftPriority = priority(
					for: left,
					lowStockIDs: lowStockIDs,
					refillSoonIDs: refillSoonIDs
				)
				let rightPriority = priority(
					for: right,
					lowStockIDs: lowStockIDs,
					refillSoonIDs: refillSoonIDs
				)

				if leftPriority != rightPriority {
					return leftPriority < rightPriority
				}

				let nameOrder = left.displayName.localizedCaseInsensitiveCompare(right.displayName)
				if nameOrder != .orderedSame {
					return nameOrder == .orderedAscending
				}

				return left.id.uuidString < right.id.uuidString
			}) else {
				for activity in activities {
					await activity.end(nil, dismissalPolicy: .immediate)
				}
				return
			}

			let lowStock = lowStockIDs.contains(medication.id)
			let refillSoon = refillSoonIDs.contains(medication.id)
			let statusText = if lowStock {
				"Low stock"
			} else if refillSoon {
				"Refill soon"
			} else {
				"Refill status"
			}

			let content = ActivityContent(
				state: MedicationLiveActivityAttributes.ContentState(
					medicationID: medication.id.uuidString,
					medicationName: medication.displayName,
					symbolName: medication.effectiveDisplaySymbol,
					statusText: statusText,
					detailText: provider.refillStatusMessage(for: medication),
					lowStock: lowStock,
					refillSoon: refillSoon
				),
				staleDate: Date().addingTimeInterval(30 * 60)
			)

			for activity in activities {
				await activity.update(content)
			}
		#endif
	}

	private static func priority(
		for medication: ANMedicationConcept,
		lowStockIDs: Set<UUID>,
		refillSoonIDs: Set<UUID>
	) -> Int {
		if lowStockIDs.contains(medication.id) {
			return 0
		}
		if refillSoonIDs.contains(medication.id) {
			return 1
		}
		return 2
	}
}

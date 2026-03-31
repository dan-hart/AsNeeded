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

			guard let medication = provider.nextMedicationDue else {
				for activity in activities {
					await activity.end(nil, dismissalPolicy: .immediate)
				}
				return
			}

			let nextDoseDate = provider.nextDoseTime(for: medication)
			let canTakeNow = provider.canTakeNow(medication)
			let lowStock = provider.lowQuantityMedications.contains { $0.id == medication.id }
			let refillSoon = provider.refillDueSoon.contains { $0.id == medication.id }
			let statusText = {
				if canTakeNow {
					return "Available now"
				}

				guard let nextDoseDate else {
					return "Check in the app"
				}

				return "Next dose \(nextDoseDate.formatted(date: .omitted, time: .shortened))"
			}()
			let detailText = {
				var parts: [String] = []
				if lowStock {
					parts.append("Low stock")
				} else if refillSoon {
					parts.append("Refill soon")
				}
				parts.append(provider.refillStatusMessage(for: medication))
				return parts.joined(separator: " • ")
			}()

			let content = ActivityContent(
				state: MedicationLiveActivityAttributes.ContentState(
					medicationID: medication.id.uuidString,
					medicationName: medication.displayName,
					symbolName: medication.effectiveDisplaySymbol,
					statusText: statusText,
					detailText: detailText,
					nextDoseDate: nextDoseDate,
					canTakeNow: canTakeNow,
					lowStock: lowStock,
					refillSoon: refillSoon
				),
				staleDate: nextDoseDate?.addingTimeInterval(300) ?? Date().addingTimeInterval(1800)
			)

			for activity in activities {
				await activity.update(content)
			}
		#endif
	}
}

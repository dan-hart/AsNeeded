// QuickLogHintPolicy.swift
// Decides when a Log Dose control shows its "hold to quick log" hint.

import ANModelKit
import Foundation

/// Log Dose controls quick log on a hold, which nothing on screen advertises. This policy shows a short
/// hint next to the control until the user has either used the hold once, on any tab, or seen the hint a
/// few times, so it teaches the gesture without nagging. The Medication tab and the History tab share one
/// discovery flag and one impression count, so learning the hold in one place retires the hint everywhere.
enum QuickLogHintPolicy {
	/// How many separate appearances may show the hint before it retires on its own.
	static let maxImpressions = 3

	/// Whether the hint should be shown for this appearance of the control.
	/// - Parameters:
	///   - hasDiscoveredQuickLog: The user has quick logged from any Log Dose control at least once.
	///   - impressions: How many times the hint has already been shown.
	static func shouldShow(hasDiscoveredQuickLog: Bool, impressions: Int) -> Bool {
		!hasDiscoveredQuickLog && impressions < maxImpressions
	}

	/// Retires the hint everywhere without waiting for a hold, for the pill's close button. Spends the
	/// remaining impressions rather than claiming the gesture was discovered.
	static func dismissForever(defaults: UserDefaults = .standard) {
		defaults.set(maxImpressions, forKey: UserDefaultsKeys.quickLogHintImpressions)
	}

	/// The hint text, naming the dose the hold will log so the user knows what to expect.
	static func hintText(for medication: ANMedicationConcept) -> String {
		let amount = (medication.prescribedDoseAmount ?? 1).formattedAmount
		let unit = medication.prescribedUnit ?? .unit
		return String(localized: "Hold to log \(amount) \(unit.abbreviation)")
	}
}

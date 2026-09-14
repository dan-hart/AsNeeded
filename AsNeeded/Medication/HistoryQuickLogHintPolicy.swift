// HistoryQuickLogHintPolicy.swift
// Decides when the History tab shows its "hold to quick log" hint.

import ANModelKit
import Foundation

/// The floating Log Dose button on the History tab quick logs on a hold, which nothing on screen
/// advertises. This policy shows a short hint next to the button until the user has either used the
/// hold once or seen the hint a few times, so it teaches the gesture without nagging.
enum HistoryQuickLogHintPolicy {
	/// How many separate appearances of the button may show the hint before it retires on its own.
	static let maxImpressions = 3

	/// Whether the hint should be shown for this appearance of the button.
	/// - Parameters:
	///   - hasDiscoveredQuickLog: The user has quick logged from the History button at least once.
	///   - impressions: How many times the hint has already been shown.
	static func shouldShow(hasDiscoveredQuickLog: Bool, impressions: Int) -> Bool {
		!hasDiscoveredQuickLog && impressions < maxImpressions
	}

	/// The hint text, naming the dose the hold will log so the user knows what to expect.
	static func hintText(for medication: ANMedicationConcept) -> String {
		let amount = (medication.prescribedDoseAmount ?? 1).formattedAmount
		let unit = medication.prescribedUnit ?? .unit
		return String(localized: "Hold to log \(amount) \(unit.abbreviation)")
	}
}

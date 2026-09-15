// QuickLogHintPolicyTests.swift
// Covers when Log Dose controls teach the hold-to-quick-log gesture.

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("QuickLogHintPolicy Tests")
struct QuickLogHintPolicyTests {
	@Test("Hint shows until the user has seen it the maximum number of times")
	func hintShowsUntilMaxImpressions() {
		for impressions in 0 ..< QuickLogHintPolicy.maxImpressions {
			#expect(QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: false, impressions: impressions))
		}

		#expect(!QuickLogHintPolicy.shouldShow(
			hasDiscoveredQuickLog: false,
			impressions: QuickLogHintPolicy.maxImpressions
		))
		#expect(!QuickLogHintPolicy.shouldShow(
			hasDiscoveredQuickLog: false,
			impressions: QuickLogHintPolicy.maxImpressions + 5
		))
	}

	@Test("Hint retires as soon as the user has quick logged once")
	func hintRetiresAfterDiscovery() {
		#expect(!QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: true, impressions: 0))
		#expect(!QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: true, impressions: 2))
	}

	@Test("Dismissing for good spends the remaining impressions so the hint never returns")
	func dismissForeverSpendsImpressions() throws {
		let suiteName = "QuickLogHintPolicyTests.dismiss.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suiteName))
		defer { defaults.removePersistentDomain(forName: suiteName) }

		QuickLogHintPolicy.dismissForever(defaults: defaults)

		let impressions = defaults.integer(forKey: UserDefaultsKeys.quickLogHintImpressions)
		#expect(impressions == QuickLogHintPolicy.maxImpressions)
		#expect(!QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: false, impressions: impressions))
	}

	@Test("Hint text names the default dose the hold will log")
	func hintTextNamesDefaultDose() {
		let medication = ANMedicationConcept(
			clinicalName: "Ibuprofen",
			quantity: 20,
			prescribedUnit: .tablet,
			prescribedDoseAmount: 2
		)

		let text = QuickLogHintPolicy.hintText(for: medication)
		#expect(text.hasPrefix("Hold to log"))
		#expect(text.contains("2"))
		#expect(text.contains(ANUnitConcept.tablet.abbreviation))
	}

	@Test("Hint text falls back to one unit when no default dose is set")
	func hintTextFallsBackToOneUnit() {
		let medication = ANMedicationConcept(clinicalName: "Cetirizine")

		let text = QuickLogHintPolicy.hintText(for: medication)
		#expect(text.contains("1"))
		#expect(text.contains(ANUnitConcept.unit.abbreviation))
	}
}

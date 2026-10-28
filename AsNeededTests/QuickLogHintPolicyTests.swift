import ANModelKit
@testable import AsNeeded
import Testing

@Suite("Shared quick log hints")
struct QuickLogHintPolicyTests {
	@Test("Discovery or dismissal retires hints across both tabs")
	func discovery() {
		#expect(QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: false, impressions: 0))
		#expect(!QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: true, impressions: 0))
	}

	@Test("Hints retire after three actual presentations")
	func impressionLimit() {
		#expect(QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: false, impressions: 2))
		#expect(!QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: false, impressions: 3))
		#expect(!QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: false, impressions: 4))
	}

	@Test("Hint describes exactly the default dose including fallback")
	func doseDescription() {
		let medication = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet, prescribedDoseAmount: 2)
		#expect(QuickLogHintPolicy.hintText(for: medication) == "Hold to log 2 tab")
		let fallback = ANMedicationConcept(clinicalName: "Synthetic fallback")
		#expect(QuickLogHintPolicy.hintText(for: fallback) == "Hold to log 1 \(ANUnitConcept.unit.abbreviation)")
	}
}

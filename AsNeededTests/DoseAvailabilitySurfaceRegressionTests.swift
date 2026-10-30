import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("Dose availability surface regressions", .tags(.unit, .regression))
@MainActor
struct DoseAvailabilitySurfaceRegressionTests {
	private let now = Date(timeIntervalSince1970: 1_800_000_000)

	@Test("Watch payload never treats indeterminate availability as eligibility")
	func watchUnknownAvailability() {
		for availability: MedicationDoseGuidanceService.Availability in [.notConfigured, .noDoseHistory, .unavailable("Review mismatched units")] {
			let payload = WCReceiver.availabilityFields(for: availability, at: now)
			#expect(payload["canTakeNow"] as? Bool == false)
			#expect(payload["nextDoseDate"] == nil)
			#expect(payload["statusMessage"] as? String == availability.message)
		}
	}

	@Test("Watch payload exposes the exact future window and switches at its boundary")
	func watchEligibilityBoundary() {
		let date = now.addingTimeInterval(3600)
		let pending = WCReceiver.availabilityFields(for: .eligible(date), at: now)
		#expect(pending["canTakeNow"] as? Bool == false)
		#expect(pending["nextDoseDate"] as? Date == date)
		let elapsed = WCReceiver.availabilityFields(for: .eligible(date), at: date)
		#expect(elapsed["canTakeNow"] as? Bool == true)
		#expect(elapsed["statusMessage"] as? String == "Saved limits met based on logged doses. Follow your prescription and care instructions.")
	}

	@Test("Trends preserves no-limit and no-history states")
	func trendsUnknownAvailability() async throws {
		let dataStore = DataStore(testIdentifier: "TrendsUnknownAvailability")
		var medication = ANMedicationConcept(clinicalName: "Test medication")
		try await dataStore.addMedication(medication)
		let viewModel = MedicationTrendsViewModel(dataStore: dataStore, selectedMedicationID: medication.id)
		#expect(viewModel.doseAvailability(at: now) == .notConfigured)
		medication.minimumHoursBetweenDoses = 4
		try await dataStore.updateMedication(medication)
		viewModel.medications = [medication]
		#expect(viewModel.doseAvailability(at: now) == .noDoseHistory)
	}
}

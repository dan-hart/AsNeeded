import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("Medication availability", .tags(.unit))
struct MedicationAvailabilityTests {
	private let now = Date(timeIntervalSince1970: 1_800_000_000)
	private let service = MedicationDoseGuidanceService()

	private func medication(interval: Double? = nil, maximum: Double? = nil, dose: Double = 2) -> ANMedicationConcept {
		var medication = ANMedicationConcept(clinicalName: "Test", prescribedUnit: .tablet, prescribedDoseAmount: dose)
		medication.minimumHoursBetweenDoses = interval
		medication.maximumDailyDoseAmount = maximum
		return medication
	}

	private func event(_ medication: ANMedicationConcept, hoursAgo: Double, amount: Double = 2, unit: ANUnitConcept = .tablet) -> ANEventConcept {
		ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: amount, unit: unit), date: now.addingTimeInterval(-hoursAgo * 3600))
	}

	@Test("Missing limits and history have explicit states")
	func missingConfiguration() {
		let medication = medication()
		#expect(service.availability(for: medication, at: now, events: []) == .notConfigured)
		#expect(service.availability(for: self.medication(interval: 4), at: now, events: []) == .noDoseHistory)
		#expect(!service.canTakeNow(medication: medication, at: now, events: []))
	}

	@Test("Minimum interval is independent of a daily limit")
	func intervalOnly() {
		let medication = medication(interval: 4)
		#expect(service.availability(for: medication, at: now, events: [event(medication, hoursAgo: 2)]) == .eligible(now.addingTimeInterval(2 * 3600)))
	}

	@Test("Daily limit sums quantity, and releases only enough quantity for a full dose")
	func rollingQuantity() {
		let medication = medication(maximum: 6, dose: 3)
		let events = [event(medication, hoursAgo: 23, amount: 1), event(medication, hoursAgo: 22, amount: 2), event(medication, hoursAgo: 1, amount: 3)]
		#expect(service.availability(for: medication, at: now, events: events) == .eligible(now.addingTimeInterval(2 * 3600)))
	}

	@Test("Dose exactly 24 hours old is outside the rolling window")
	func exactBoundary() {
		let medication = medication(maximum: 4)
		#expect(service.availability(for: medication, at: now, events: [event(medication, hoursAgo: 24, amount: 4)]) == .eligible(now))
	}

	@Test("Both limits must be met, including quantity that expires during the interval")
	func combinedLimits() {
		let medication = medication(interval: 4, maximum: 4)
		let events = [event(medication, hoursAgo: 23), event(medication, hoursAgo: 1)]
		#expect(service.availability(for: medication, at: now, events: events) == .eligible(now.addingTimeInterval(3 * 3600)))
		let later = [event(medication, hoursAgo: 3), event(medication, hoursAgo: 1)]
		#expect(service.availability(for: medication, at: now, events: later) == .eligible(now.addingTimeInterval(21 * 3600)))
	}

	@Test("Future and non-dose events and other medications do not affect timing")
	func eventFiltering() {
		let medication = medication(interval: 4)
		let other = self.medication(interval: 4)
		var reconciliation = event(medication, hoursAgo: 0)
		reconciliation.eventType = .reconcile
		let events = [event(medication, hoursAgo: 2), event(medication, hoursAgo: -1), event(other, hoursAgo: 0), reconciliation]
		#expect(service.availability(for: medication, at: now, events: events) == .eligible(now.addingTimeInterval(2 * 3600)))
	}

	@Test("Unknown quantities, incompatible units, impossible doses, and invalid limits never imply eligibility")
	func indeterminateLimits() {
		var medication = medication(maximum: 4)
		#expect(service.availability(for: medication, at: now, events: [event(medication, hoursAgo: 1, unit: .milligram)]).eligibleDate == nil)
		var missingDose = event(medication, hoursAgo: 1)
		missingDose.dose = nil
		#expect(service.availability(for: medication, at: now, events: [missingDose]).eligibleDate == nil)
		medication.prescribedDoseAmount = 5
		#expect(service.availability(for: medication, at: now, events: [event(medication, hoursAgo: 1)]).eligibleDate == nil)
		medication.maximumDailyDoseAmount = .infinity
		#expect(service.availability(for: medication, at: now, events: [event(medication, hoursAgo: 1)]).eligibleDate == nil)
		medication = self.medication(interval: -1)
		#expect(service.availability(for: medication, at: now, events: [event(medication, hoursAgo: 1)]).eligibleDate == nil)
	}

	@Test("Model limits take priority over legacy sidecar values")
	func modelPriority() {
		let medication = medication(interval: 8, maximum: 4)
		let profile = MedicationSafetyProfile(minimumHoursBetweenDoses: 1, maxDailyAmount: 100)
		#expect(service.availability(for: medication, at: now, events: [event(medication, hoursAgo: 1)], profile: profile) == .eligible(now.addingTimeInterval(7 * 3600)))
	}
	@Test("A custom-unit dose never reinterprets the saved daily quantity unit")
	func proposedUnitMismatch() {
		let medication = medication(maximum: 6)
		let assessment = service.assessment(for: medication, proposedDose: ANDoseConcept(amount: 1, unit: .milligram), at: now, events: [event(medication, hoursAgo: 2, amount: 1, unit: .milligram)])
		#expect(assessment.severity == .warning)
		#expect(assessment.nextEligibleDate == nil)
		#expect(assessment.reasons.contains { $0.contains("unit") })
	}

	@Test("Fractional quantities respect the saved maximum without binary rounding delays")
	func fractionalQuantities() {
		let medication = medication(maximum: 0.3, dose: 0.2)
		let events = [event(medication, hoursAgo: 2, amount: 0.1)]
		#expect(service.availability(for: medication, at: now, events: events) == .eligible(now))
		let assessment = service.assessment(for: medication, proposedDose: ANDoseConcept(amount: 0.2, unit: .tablet), at: now, events: events)
		#expect(assessment.severity != .warning)
	}

}

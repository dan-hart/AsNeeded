import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationDoseGuidanceService Tests", .tags(.unit))
struct MedicationDoseGuidanceServiceTests {
	private let calendar = Calendar(identifier: .gregorian)

	private func medication(
		quantity: Double? = 30,
		unit: ANUnitConcept = .tablet,
		dose: Double = 2
	) -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: "Ibuprofen",
			nickname: nil,
			quantity: quantity,
			initialQuantity: 60,
			lastRefillDate: calendar.date(byAdding: .day, value: -15, to: .now),
			nextRefillDate: calendar.date(byAdding: .day, value: 10, to: .now),
			prescribedUnit: unit,
			prescribedDoseAmount: dose
		)
	}

	private func event(
		medication: ANMedicationConcept,
		hoursAgo: Double,
		amount: Double = 2,
		unit: ANUnitConcept = .tablet
	) -> ANEventConcept {
		ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: amount, unit: unit),
			date: Date().addingTimeInterval(-(hoursAgo * 3600))
		)
	}

	@Test("Assessment warns when minimum interval has not elapsed")
	func assessmentWarnsWhenMinimumIntervalNotElapsed() {
		let medication = medication()
		let profile = MedicationSafetyProfile(minimumHoursBetweenDoses: 4)
		let service = MedicationDoseGuidanceService()

		let assessment = service.assessment(
			for: medication,
			proposedDose: ANDoseConcept(amount: 2, unit: .tablet),
			at: .now,
			events: [event(medication: medication, hoursAgo: 2)],
			profile: profile
		)

		#expect(assessment.severity == .warning)
		#expect(assessment.nextEligibleDate != nil)
		#expect(assessment.reasons.contains { $0.contains("minimum interval") })
	}

	@Test("Assessment marks duplicate candidates within duplicate window")
	func assessmentMarksDuplicateCandidates() {
		let medication = medication()
		let profile = MedicationSafetyProfile(duplicateDoseWindowMinutes: 30)
		let recentEvent = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 2, unit: .tablet),
			date: Date().addingTimeInterval(-10 * 60)
		)
		let service = MedicationDoseGuidanceService()

		let assessment = service.assessment(
			for: medication,
			proposedDose: ANDoseConcept(amount: 2, unit: .tablet),
			at: .now,
			events: [recentEvent],
			profile: profile
		)

		#expect(assessment.isDuplicateCandidate == true)
		#expect(assessment.reasons.contains { $0.contains("duplicate") })
	}

	@Test("Assessment cautions when projected daily total is close to daily limit")
	func assessmentCautionsNearDailyLimit() {
		let medication = medication()
		let profile = MedicationSafetyProfile(maxDailyAmount: 8)
		let service = MedicationDoseGuidanceService()
		let events = [
			event(medication: medication, hoursAgo: 2, amount: 2),
			event(medication: medication, hoursAgo: 6, amount: 2),
			event(medication: medication, hoursAgo: 12, amount: 2),
		]

		let assessment = service.assessment(
			for: medication,
			proposedDose: ANDoseConcept(amount: 1.5, unit: .tablet),
			at: .now,
			events: events,
			profile: profile
		)

		#expect(assessment.severity == .caution)
		#expect(assessment.projectedDailyTotal == 7.5)
	}

	@Test("Refill projection identifies low stock and refill soon states")
	func refillProjectionIdentifiesLowStockAndRefillSoon() {
		let medication = medication(quantity: 6)
		let profile = MedicationSafetyProfile(
			lowStockThreshold: 10,
			refillLeadDays: 7
		)
		let service = MedicationDoseGuidanceService()
		let events = [
			event(medication: medication, hoursAgo: 12, amount: 2),
			event(medication: medication, hoursAgo: 36, amount: 2),
			event(medication: medication, hoursAgo: 60, amount: 2),
		]

		let projection = service.refillProjection(
			for: medication,
			events: events,
			profile: profile
		)

		#expect(projection.lowStock == true)
		#expect(projection.refillSoon == true)
		#expect(projection.projectedRunOutDate != nil)
	}
}

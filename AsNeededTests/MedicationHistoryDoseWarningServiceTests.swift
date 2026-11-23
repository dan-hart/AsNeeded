import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite(.tags(.unit))
struct MedicationHistoryDoseWarningServiceTests {
	private let date = Date(timeIntervalSince1970: 1_730_592_000)

	@Test func actualAmountsAndSpacingAreIndependentAcrossMidnight() {
		let medication = medication(interval: 4, daily: 4, single: 2)
		let earlier = dose(medication, -5, 1.75)
		let later = dose(medication, 1, 2.5)
		let close = dose(medication, 2, 0.25)
		let result = warnings(medication, [later, close, earlier])
		#expect(result[earlier.id] == nil)
		#expect(result[later.id]?.spacing == nil)
		#expect(result[later.id]?.singleDose == .exceeded(2.5))
		#expect(result[later.id]?.rolling == .exceeded(4.25))
		#expect(result[close.id]?.spacing?.previous.id == later.id)
		#expect(result[close.id]?.spacing?.elapsed == 3_600)
	}

	@Test func exactBoundariesAndEqualLimitsClear() {
		let medication = medication(interval: 4, daily: 0.3, single: 0.2)
		let other = self.medication()
		#expect(warnings(medication, [
			dose(medication, -24, 0.2),
			dose(medication, -4, 0.1),
			dose(other, -1, 500),
			dose(medication, 0, 0.2)
		]).isEmpty)
	}

	@Test func aFiniteMinimumStillAppliesWhenConvertingItToSecondsOverflows() {
		let medication = medication(interval: 1e306)
		let earlier = dose(medication, -2, 1)
		let later = dose(medication, 0, 1)
		let result = warnings(medication, [earlier, later])
		#expect(result[earlier.id] == nil)
		#expect(result[later.id]?.spacing?.previous.id == earlier.id)
		#expect(result[later.id]?.spacing?.minimumHours == 1e306)
	}

	@Test func simultaneousEntriesCountOnceOnStableAnchor() throws {
		let medication = medication(interval: 1, daily: 3)
		let first = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
		let second = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
		let a = dose(medication, 0, 2, id: first)
		let b = dose(medication, 0, 2, id: second)
		let result = warnings(medication, [b, a, b])
		#expect(result.count == 1)
		#expect(result[second]?.rolling == .exceeded(4))
		#expect(result[second]?.spacing?.previous.id == first)
	}

	@Test func incompleteAmountsPreserveProvenWarningsAndExpire() {
		let medication = medication(interval: 2, daily: 4, single: 2)
		let incompatible = dose(medication, -23, 50, unit: .milligram)
		let missing = dose(medication, -22, nil)
		let excessive = dose(medication, 0, 5)
		let later = dose(medication, 24, 1)
		let result = warnings(medication, [incompatible, missing, excessive, later])
		#expect(result[missing.id]?.spacing?.previous.id == incompatible.id)
		#expect(result[missing.id]?.rolling == .unavailable)
		#expect(result[excessive.id]?.rolling == .atLeast(5))
		#expect(result[excessive.id]?.singleDose == .exceeded(5))
		#expect(result[later.id] == nil)
	}

	@Test func expirationPreservesSmallSurvivingAmountsAfterOverflow() {
		let medication = medication(daily: 1)
		let events = [
			dose(medication, -25, .greatestFiniteMagnitude),
			dose(medication, -24, .greatestFiniteMagnitude),
			dose(medication, -1, 1),
			dose(medication, 0, 0.5)
		]
		let result = warnings(medication, events)
		#expect(result[events[1].id]?.rolling == .overflow)
		#expect(result[events[3].id]?.rolling == .exceeded(1.5))
	}

	@Test func currentSettingsAndLegacyFallbackOverrideEmbeddedSettings() {
		let current = medication()
		var historical = current
		historical.minimumHoursBetweenDoses = 24
		let earlier = dose(historical, -5, 1)
		let later = dose(historical, -1, 1)
		let events = [earlier, later]
		let service = MedicationHistoryDoseWarningService()
		#expect(warnings(current, events).isEmpty)
		#expect(service.warnings(medications: [], events: events).isEmpty)
		let profiles = [current.id.uuidString: MedicationSafetyProfile(minimumHoursBetweenDoses: 6, maxDailyAmount: 1)]
		let result = service.warnings(medications: [current], events: events, profiles: profiles)
		#expect(result[later.id]?.spacing?.previous.id == earlier.id)
		#expect(result[later.id]?.rolling == .exceeded(2))
	}

	@Test func rollingWindowUsesElapsedTimeAcrossDaylightSaving() throws {
		let zone = try #require(TimeZone(identifier: "America/Chicago"))
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = zone
		let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12)))
		let nextNoon = try #require(calendar.date(byAdding: .day, value: 1, to: start))
		let medication = medication(interval: 24, daily: 3)
		let first = ANEventConcept(eventType: .doseTaken, medication: medication, dose: .init(amount: 2, unit: .tablet), date: start)
		let next = ANEventConcept(eventType: .doseTaken, medication: medication, dose: .init(amount: 2, unit: .tablet), date: nextNoon)
		let result = warnings(medication, [first, next])
		#expect(result[next.id]?.spacing?.elapsed == TimeInterval(23 * 3_600))
		#expect(result[next.id]?.rolling == .exceeded(4))
	}

	@Test(arguments: [0.0, -1, Double.nan, Double.infinity])
	func invalidAmountsNeverSupplyQuantityEvidence(invalid: Double) {
		let medication = medication(interval: 2, daily: 1, single: 1)
		let earlier = dose(medication, -1, invalid)
		let next = dose(medication, 0, 1)
		let result = warnings(medication, [earlier, next])
		#expect(result[earlier.id]?.singleDose == .unavailable)
		#expect(result[next.id]?.singleDose == nil)
		#expect(result[next.id]?.rolling == .unavailable)
		#expect(result[next.id]?.spacing?.previous.id == earlier.id)
	}

	@Test func independentlyConfiguredSingleLimitFlagsOneEntryBelowTheRollingLimit() {
		let medication = medication(daily: 5, single: 2)
		let only = dose(medication, 0, 2.5)
		let result = warnings(medication, [only])
		#expect(result[only.id]?.singleDose == .exceeded(2.5))
		#expect(result[only.id]?.rolling == nil)
	}

	private func medication(interval: Double? = nil, daily: Double? = nil, single: Double? = nil) -> ANMedicationConcept {
		var medication = ANMedicationConcept(clinicalName: "Sample A", prescribedUnit: .tablet, prescribedDoseAmount: 1)
		medication.minimumHoursBetweenDoses = interval
		medication.maximumDailyDoseAmount = daily
		medication.maximumDoseAmount = single
		return medication
	}

	private func dose(_ medication: ANMedicationConcept, _ hours: Double, _ amount: Double?, unit: ANUnitConcept = .tablet, id: UUID = UUID()) -> ANEventConcept {
		ANEventConcept(id: id, eventType: .doseTaken, medication: medication, dose: amount.map { ANDoseConcept(amount: $0, unit: unit) }, date: date.addingTimeInterval(hours * 3_600))
	}

	private func warnings(_ medication: ANMedicationConcept, _ events: [ANEventConcept]) -> [UUID: MedicationHistoryDoseWarningService.Warning] {
		MedicationHistoryDoseWarningService().warnings(medications: [medication], events: events)
	}
}

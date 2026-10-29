import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("Widget experience projection", .tags(.unit))
struct WidgetExperienceProjectionTests {
	private func calendar(_ zone: String = "America/Chicago") throws -> Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(identifier: zone))
		return calendar
	}
	private func date(_ value: String) throws -> Date {
		try #require(ISO8601DateFormatter().date(from: value))
	}
	private func event(_ medication: ANMedicationConcept, _ date: Date, amount: Double? = 1, unit: ANUnitConcept = .tablet) -> ANEventConcept {
		ANEventConcept(eventType: .doseTaken, medication: medication,
			dose: amount.map { ANDoseConcept(amount: $0, unit: unit) }, date: date)
	}

	@Test("Explicit missing or archived choices never fall back to another medication")
	func exactSelection() throws {
		let now = try date("2026-10-28T18:00:00Z")
		let active = ANMedicationConcept(clinicalName: "Active")
		var archived = ANMedicationConcept(clinicalName: "Archived")
		archived.isArchived = true
		for id in [UUID(), archived.id] {
			let projection = WidgetExperienceProjection(medications: [active, archived], events: [], selectedID: id, at: now)
			#expect(projection.state == .selectionUnavailable)
			#expect(projection.medications.isEmpty)
			#expect(projection.automaticID == nil)
			#expect(projection.usage == nil)
		}
	}

	@Test("Automatic selection preserves unknown-before-known timing order")
	func automaticContinuity() throws {
		let now = try date("2026-10-28T18:00:00Z")
		let unknown = ANMedicationConcept(clinicalName: "Z synthetic")
		let eligible = ANMedicationConcept(clinicalName: "A synthetic", prescribedUnit: .tablet, minimumHoursBetweenDoses: 1)
		let projection = WidgetExperienceProjection(medications: [eligible, unknown],
			events: [event(eligible, now.addingTimeInterval(-7200))], at: now)
		#expect(projection.automaticID == unknown.id)
	}

	@Test("UUID selection survives reordering and renaming; hidden name labels contain no medication name")
	func selectionAndPrivacy() throws {
		var medication = ANMedicationConcept(clinicalName: "Synthetic long medication name", nickname: "Renamed")
		let other = ANMedicationConcept(clinicalName: "First")
		medication.nickname = "New name"
		let projection = WidgetExperienceProjection(medications: [other, medication], events: [], selectedID: medication.id, showNames: false, at: try date("2026-10-28T18:00:00Z"))
		let selected = try #require(projection.medications.first)
		#expect(selected.id == medication.id)
		#expect(selected.name == "New name")
		#expect(projection.visibleName(for: selected) == "Medication")
		#expect(selected.nextWindow == nil)
		#expect(selected.lastDose == nil)
	}

	@Test("Unreadable storage is distinct from an empty committed snapshot")
	func storageStates() throws {
		let now = try date("2026-10-28T18:00:00Z")
		let medication = ANMedicationConcept(clinicalName: "Synthetic")
		let failed = WidgetExperienceProjection(medications: [medication], events: [], storageAvailable: false, at: now)
		#expect(failed.state == .unavailable)
		#expect(failed.medications.isEmpty)
		#expect(failed.usage == nil)
		#expect(WidgetExperienceProjection(medications: [], events: [], at: now).state == .empty)
	}

	@Test("Seven complete local days exclude today's doses and include zero days")
	func completeDays() throws {
		let calendar = try calendar()
		let now = try date("2026-10-28T18:00:00Z")
		let medication = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet)
		let events = [event(medication, try date("2026-10-21T05:00:00Z"), amount: 0.5),
			event(medication, try date("2026-10-27T22:00:00Z"), amount: 2),
			event(medication, try date("2026-10-28T05:00:00Z"), amount: 100)]
		let usage = try #require(WidgetExperienceProjection(medications: [medication], events: events, at: now, calendar: calendar).usage)
		#expect(usage.days.count == 7)
		#expect(usage.total == 2.5)
		#expect(usage.count == 2)
		#expect(usage.days.filter { $0.quantity == 0 }.count == 5)
		#expect(usage.days.first?.date == calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)))
	}

	@Test("Spring and fall DST days use calendar boundaries, not fixed 24-hour subtraction")
	func daylightSaving() throws {
		let calendar = try calendar()
		for value in ["2026-03-10T18:00:00Z", "2026-11-03T18:00:00Z"] {
			let now = try date(value)
			let medication = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet)
			let usage = try #require(WidgetExperienceProjection(medications: [medication], events: [], at: now, calendar: calendar).usage)
			#expect(usage.days.count == 7)
			#expect(usage.days.allSatisfy { calendar.component(.hour, from: $0.date) == 0 })
			let intervals = zip(usage.days, usage.days.dropFirst()).map { $1.date.timeIntervalSince($0.date) }
			#expect(intervals.contains { $0 != 86400 })
		}
	}

	@Test("Incompatible, missing or invalid quantities produce count summaries, never mixed totals")
	func incompatibleAmounts() throws {
		let now = try date("2026-10-28T18:00:00Z")
		let logged = try date("2026-10-27T18:00:00Z")
		let medication = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet)
		for bad in [event(medication, logged, unit: .capsule), event(medication, logged, amount: nil), event(medication, logged, amount: .infinity), event(medication, logged, amount: -1)] {
			let usage = try #require(WidgetExperienceProjection(medications: [medication], events: [event(medication, logged), bad], at: now).usage)
			#expect(!usage.quantitiesComplete)
			#expect(usage.count == 2)
			#expect(usage.total == 0)
			#expect(usage.previousTotal == nil)
		}
	}

	@Test("Preferred unit uses oldest dose when unprescribed and remains scoped to selected medication")
	func oldestUnit() throws {
		let now = try date("2026-10-28T18:00:00Z")
		let medication = ANMedicationConcept(clinicalName: "Synthetic")
		let other = ANMedicationConcept(clinicalName: "Other", prescribedUnit: .tablet)
		let events = [event(medication, try date("2026-10-01T18:00:00Z"), unit: .capsule),
			event(medication, try date("2026-10-27T18:00:00Z"), amount: 0.5, unit: .capsule),
			event(other, try date("2026-10-27T18:00:00Z"), amount: 100)]
		let usage = try #require(WidgetExperienceProjection(medications: [other, medication], events: Array(events.reversed()), selectedID: medication.id, at: now).usage)
		#expect(usage.quantitiesComplete)
		#expect(usage.unit == ANUnitConcept.capsule.abbreviation)
		#expect(usage.total == 0.5)
	}

	@Test("Comparison uses preceding seven complete days only when quantities are complete")
	func comparison() throws {
		let now = try date("2026-10-28T18:00:00Z")
		let medication = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet)
		let events = [event(medication, try date("2026-10-20T18:00:00Z"), amount: 3), event(medication, try date("2026-10-27T18:00:00Z"), amount: 2)]
		let usage = try #require(WidgetExperienceProjection(medications: [medication], events: events, at: now).usage)
		#expect(usage.previousTotal == 3)
		#expect(usage.total == 2)
	}

	@Test("Timelines include upcoming saved boundary and local midnight within bounded reloads")
	func timeline() throws {
		let calendar = try calendar()
		let now = try date("2026-10-29T03:00:00Z")
		let last = try date("2026-10-29T02:00:00Z")
		let medication = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet)
		let profiles = [medication.id.uuidString: MedicationSafetyProfile(minimumHoursBetweenDoses: 2)]
		let projection = WidgetExperienceProjection(medications: [medication], events: [event(medication, last)], profiles: profiles, at: now, calendar: calendar)
		#expect(projection.timelineDates.first == now)
		#expect(projection.timelineDates.contains(last.addingTimeInterval(7200)))
		#expect(projection.timelineDates.contains(try date("2026-10-29T05:00:00Z")))
		#expect(projection.timelineDates.count <= 16)
		let boundary = WidgetExperienceProjection(medications: [medication], events: [event(medication, last)], profiles: profiles, at: last.addingTimeInterval(7200), calendar: calendar)
		#expect(boundary.medications.first?.nextWindow == nil)
	}

	@Test("Unknown units and missing limits never imply timing clearance")
	func unknown() throws {
		let now = try date("2026-10-28T18:00:00Z")
		let medication = ANMedicationConcept(clinicalName: "Synthetic")
		let projection = WidgetExperienceProjection(medications: [medication], events: [], at: now)
		#expect(projection.medications.first?.nextWindow == nil)
		#expect(projection.usage?.quantitiesComplete == false)
		#expect(projection.usage?.count == 0)
	}
}

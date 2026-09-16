// LogDosePickerModelTests.swift
// Covers the ordering, filtering and labels behind the Log Dose picker.

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("LogDosePickerModel Tests")
struct LogDosePickerModelTests {
	private func medication(_ name: String, nickname: String? = nil) -> ANMedicationConcept {
		ANMedicationConcept(clinicalName: name, nickname: nickname, prescribedUnit: .tablet, prescribedDoseAmount: 1)
	}

	private func dose(_ medication: ANMedicationConcept, daysAgo: Double) -> ANEventConcept {
		ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 1, unit: .tablet),
			date: Date().addingTimeInterval(-daysAgo * 86_400)
		)
	}

	@Test("Items are ordered by most recent dose, with never-logged medications last alphabetically")
	func itemsOrderedByRecencyThenName() {
		let daily = medication("Zyrtec")
		let occasional = medication("Advil")
		let neverB = medication("Benadryl")
		let neverA = medication("Aspirin")
		let events = [dose(occasional, daysAgo: 3), dose(daily, daysAgo: 0.1), dose(daily, daysAgo: 5)]

		let items = LogDosePickerModel.items(medications: [neverB, occasional, neverA, daily], events: events)

		#expect(items.map(\.medication.clinicalName) == ["Zyrtec", "Advil", "Aspirin", "Benadryl"])
		#expect(items.first?.lastDoseDate != nil)
		#expect(items.last?.lastDoseDate == nil)
	}

	@Test("Only dose events count toward recency")
	func onlyDoseEventsCount() {
		let medication = medication("Tums")
		let reconcile = ANEventConcept(eventType: .reconcile, medication: medication, dose: nil, date: Date())

		let items = LogDosePickerModel.items(medications: [medication], events: [reconcile])

		#expect(items.first?.lastDoseDate == nil)
	}

	@Test("Filter matches clinical name, nickname and display name case-insensitively")
	func filterMatchesNames() {
		let items = LogDosePickerModel.items(
			medications: [medication("Ibuprofen", nickname: "Pain Relief"), medication("Cetirizine")],
			events: []
		)

		#expect(LogDosePickerModel.filter(items, query: "").count == 2)
		#expect(LogDosePickerModel.filter(items, query: "   ").count == 2)
		#expect(LogDosePickerModel.filter(items, query: "ibu").map(\.medication.clinicalName) == ["Ibuprofen"])
		#expect(LogDosePickerModel.filter(items, query: "PAIN").map(\.medication.clinicalName) == ["Ibuprofen"])
		#expect(LogDosePickerModel.filter(items, query: "zzz").isEmpty)
	}

	@Test("Last taken label distinguishes today, yesterday, older and never")
	func lastTakenLabels() {
		let now = Date()
		let calendar = Calendar.current

		#expect(LogDosePickerModel.lastTakenText(for: nil, now: now) == "Not logged yet")
		#expect(LogDosePickerModel.lastTakenText(for: now, now: now).hasPrefix("Today"))

		let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
		#expect(LogDosePickerModel.lastTakenText(for: yesterday, now: now).hasPrefix("Yesterday"))

		let older = calendar.date(byAdding: .day, value: -10, to: now) ?? now
		let olderText = LogDosePickerModel.lastTakenText(for: older, now: now)
		#expect(!olderText.hasPrefix("Today"))
		#expect(!olderText.hasPrefix("Yesterday"))
		#expect(!olderText.isEmpty)
	}
}

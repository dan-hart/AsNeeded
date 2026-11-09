import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct LongHistoryWorkloadTests {
	@Test("Four years of history stay consistent across selection, cache reuse, and export")
	func longHistory() async throws {
		let preferences = try IsolatedTestPreferences()
		let suite = preferences.name
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
		defer { try? FileManager.default.removeItem(at: directory) }
		let defaults = preferences.defaults
		func makeStore() -> DataStore {
			DataStore(storageDirectory: directory, defaults: defaults, defaultsDomainName: suite,
				navigationManager: NavigationManager(defaults: defaults))
		}

		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
		let referenceCalendar = calendar
		let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12)))
		let active = ANMedicationConcept(id: fixtureID(kind: 1, index: 1), clinicalName: "Synthetic active workload", quantity: 100,
			prescribedUnit: .tablet, prescribedDoseAmount: 0.5)
		var archived = ANMedicationConcept(id: fixtureID(kind: 1, index: 2), clinicalName: "Synthetic archived workload", quantity: 20,
			prescribedUnit: .milliliter, prescribedDoseAmount: 1.25)
		archived.isArchived = true
		let days = 1_461
		var events: [ANEventConcept] = []
		for offset in 1...days {
			let date = try #require(calendar.date(byAdding: .day, value: -offset, to: now))
			for index in 0..<4 {
				let medication = index == 3 ? archived : active
				let eventIndex = offset * 4 + index
				let dose = ANDoseConcept(id: fixtureID(kind: 2, index: eventIndex), amount: index == 3 ? 1.25 : 0.5, unit: index == 3 ? .milliliter : .tablet)
				events.append(ANEventConcept(id: fixtureID(kind: 3, index: eventIndex), eventType: .doseTaken, medication: medication, dose: dose,
					date: date.addingTimeInterval(Double(index) * 60), note: index == 0 ? "Synthetic workload note" : nil))
			}
		}
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let fixture = DataExport(medications: [active, archived], events: events, exportDate: now,
			appVersion: "synthetic-workload", dataVersion: "1.0", settings: nil)
		try await makeStore().importDataFromJSON(encoder.encode(fixture))

		let clock = ContinuousClock()
		let start = clock.now
		let store = makeStore()
		let snapshot = try await store.prepareForAccess()
		let coldOpen = start.duration(to: clock.now)
		#expect(snapshot.events.count == days * 4)

		let history = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: active.id.uuidString,
			notificationCenter: NotificationCenter(), defaults: defaults, calendar: { referenceCalendar }, now: { now })
		let historyStart = clock.now
		let grouped = history.groupedHistory
		let firstHistory = historyStart.duration(to: clock.now)
		#expect(grouped.count == days)
		#expect(grouped.first?.entries.count == 3)
		let warmHistoryStart = clock.now
		let cached = history.groupedHistory
		let warmHistory = warmHistoryStart.duration(to: clock.now)
		#expect(cached.map(\.day) == grouped.map(\.day))
		history.selectedMedicationID = "all"
		#expect(history.groupedHistory.reduce(0) { $0 + $1.entries.count } == days * 4)

		let trends = MedicationTrendsViewModel(dataStore: store, defaults: defaults, selectedMedicationID: active.id,
			notificationCenter: NotificationCenter(), calendar: { referenceCalendar }, now: { now })
		let range = try #require(TrendsPeriod.twoYears.range(calendar: calendar, now: now))
		let trendsStart = clock.now
		let totals = trends.dailyTotals(in: range)
		let firstTrends = trendsStart.duration(to: clock.now)
		#expect(totals.count == range.dayCount(calendar: calendar))
		#expect(totals.allSatisfy { $0.total == 1.5 })
		let warmTrendsStart = clock.now
		let cachedTotals = trends.dailyTotals(in: range)
		let warmTrends = warmTrendsStart.duration(to: clock.now)
		#expect(cachedTotals.map(\.total) == totals.map(\.total))

		let exportStart = clock.now
		let data = try await store.exportDataAsJSON(includeSettings: true)
		let exportTime = exportStart.duration(to: clock.now)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let export = try decoder.decode(DataExport.self, from: data)
		#expect(Set(export.events.map(\.id)) == Set(events.map(\.id)))
		#expect(export.medications.count == 2)
		print("Long history (\(events.count) events): store open \(coldOpen), History \(firstHistory) / warm \(warmHistory), Trends \(firstTrends) / warm \(warmTrends), export \(exportTime)")
	}

	private func fixtureID(kind: UInt8, index: Int) -> UUID {
		UUID(uuid: (kind, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			UInt8(truncatingIfNeeded: index >> 8), UInt8(truncatingIfNeeded: index)))
	}
}

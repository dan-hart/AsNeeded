import ANModelKit
import Foundation
import Testing
@testable import AsNeeded

@MainActor
@Suite("History date filters")
struct HistoryDateFilterTests {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
		return calendar
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) throws -> Date {
		try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
	}

	@Test("History presets include today while Trends retains complete days", arguments: TrendsPeriod.allCases)
	func historyAndTrendsBounds(period: TrendsPeriod) throws {
		let now = try date(2024, 3, 1, hour: 12)
		let history = try #require(HistoryDateFilter.period(period).range(calendar: calendar, now: now))
		let trends = try #require(period.range(calendar: calendar, now: now))
		#expect(history.end == calendar.startOfDay(for: now))
		#expect(trends.end == (try date(2024, 2, 29)))
		if period.rawValue > 0 { #expect(history.dayCount(calendar: calendar) == period.rawValue) }
		if period == .oneYear {
			#expect(history.start == (try date(2023, 3, 2)))
			#expect(history.dayCount(calendar: calendar) == 366)
		}
		if period == .twoYears { #expect(history.dayCount(calendar: calendar) == 731) }
	}

	@Test("History custom ranges accept today and reject tomorrow")
	func customToday() throws {
		let now = try date(2026, 11, 4, hour: 12)
		#expect(TrendsDateRange(start: now, end: now, calendar: calendar, now: now, includingToday: true) != nil)
		#expect(TrendsDateRange(start: now, end: now, calendar: calendar, now: now) == nil)
		#expect(TrendsDateRange(start: now, end: try date(2026, 11, 5), calendar: calendar, now: now, includingToday: true) == nil)
	}

	@Test("Date and medication filters combine, include exact bounds, and invalidate the cache")
	func combinedFilters() throws {
		let defaults = try IsolatedTestPreferences()
		let store = DataStore(testIdentifier: "History-Range-\(UUID().uuidString)")
		let now = try date(2026, 11, 4, hour: 12)
		let cal = calendar
		let first = ANMedicationConcept(clinicalName: "First")
		let second = ANMedicationConcept(clinicalName: "Second")
		let model = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: "all", defaults: defaults.defaults, calendar: { cal }, now: { now })
		let dates = try [date(2026, 10, 21, hour: 23), date(2026, 10, 22), date(2026, 11, 4, hour: 23), date(2026, 11, 5)]
		model.events = dates.map { ANEventConcept(eventType: .doseTaken, medication: first, date: $0) }
		let other = ANEventConcept(eventType: .doseTaken, medication: second, date: now)
		model.events.append(other)
		#expect(model.dateFilter == .allTime)
		#expect(model.groupedHistory.flatMap(\.entries).count == 5)
		model.dateFilter = .period(.fourteenDays)
		#expect(model.groupedHistory.flatMap(\.entries).count == 3)
		model.selectedMedicationID = first.id.uuidString
		#expect(model.groupedHistory.flatMap(\.entries).count == 2)
		model.dateFilter = .allTime
		#expect(model.groupedHistory.flatMap(\.entries).count == 4)
	}

	@Test("Jump outside date filter clears only that filter and selects a real group")
	func jumpOutsideRange() throws {
		let defaults = try IsolatedTestPreferences()
		let store = DataStore(testIdentifier: "History-Jump-\(UUID().uuidString)")
		let now = try date(2026, 11, 4)
		let cal = calendar
		let medication = ANMedicationConcept(clinicalName: "Example")
		let model = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: medication.id.uuidString, defaults: defaults.defaults, calendar: { cal }, now: { now })
		let old = try date(2026, 9, 2)
		model.events = [ANEventConcept(eventType: .doseTaken, medication: medication, date: old), ANEventConcept(eventType: .doseTaken, medication: medication, date: now)]
		model.dateFilter = .period(.fourteenDays)
		#expect(model.jumpTarget(for: now) == now)
		#expect(model.dateFilter == .period(.fourteenDays))
		#expect(model.jumpTarget(for: try date(2026, 9, 3)) == old)
		#expect(model.dateFilter == .allTime)
		#expect(model.selectedMedicationID == medication.id.uuidString)
		#expect(model.jumpTarget(for: try date(2026, 11, 3)) == now)
	}

	@Test("Rolling history cache advances at midnight even without new doses")
	func midnightRefresh() throws {
		let defaults = try IsolatedTestPreferences()
		let store = DataStore(testIdentifier: "History-Midnight-\(UUID().uuidString)")
		var now = try date(2026, 11, 4)
		let cal = calendar
		let oldest = try date(2026, 10, 22)
		let model = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: "all", defaults: defaults.defaults, calendar: { cal }, now: { now })
		model.events = [ANEventConcept(eventType: .doseTaken, date: oldest)]
		model.dateFilter = .period(.fourteenDays)
		#expect(model.groupedHistory.count == 1)
		now = try date(2026, 11, 5)
		#expect(model.groupedHistory.isEmpty)
	}

	@Test("Custom History filters preserve selected dates across DST and timezone changes")
	func customTimezoneRange() throws {
		let defaults = try IsolatedTestPreferences()
		let store = DataStore(testIdentifier: "History-Custom-Zone-\(UUID().uuidString)")
		var cal = calendar
		let now = try date(2026, 3, 10, hour: 12)
		let start = try date(2026, 3, 7)
		let end = try date(2026, 3, 9)
		let range = try #require(TrendsDateRange(start: start, end: end, calendar: cal, now: now, includingToday: true))
		let model = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: "all", defaults: defaults.defaults, calendar: { cal }, now: { now })
		let event = ANEventConcept(eventType: .doseTaken, date: try date(2026, 3, 8, hour: 12))
		model.events = [event, ANEventConcept(eventType: .doseTaken, date: now)]
		model.dateFilter = .custom(range)
		#expect(model.groupedHistory.flatMap(\.entries).map(\.id) == [event.id])
		cal.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
		#expect(model.groupedHistory.flatMap(\.entries).map(\.id) == [event.id])
		let resolved = try #require(model.activeDateRange)
		#expect(cal.component(.day, from: resolved.start) == 7)
		#expect(cal.component(.day, from: resolved.end) == 9)
	}

	@Test("History opened from Trends retains complete-day bounds instead of adding today")
	func trendsRangeInHistory() throws {
		let defaults = try IsolatedTestPreferences()
		let store = DataStore(testIdentifier: "History-Trends-Range-\(UUID().uuidString)")
		let cal = calendar
		let now = try date(2026, 11, 4, hour: 12)
		let yesterday = try date(2026, 11, 3, hour: 12)
		let model = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: "all", defaults: defaults.defaults, calendar: { cal }, now: { now })
		let completed = ANEventConcept(eventType: .doseTaken, date: yesterday)
		model.events = [completed, ANEventConcept(eventType: .doseTaken, date: now)]
		model.dateFilter = .custom(try #require(TrendsPeriod.fourteenDays.range(calendar: cal, now: now)))
		#expect(model.groupedHistory.flatMap(\.entries).map(\.id) == [completed.id])
		model.dateFilter = .period(.fourteenDays)
		#expect(model.groupedHistory.flatMap(\.entries).count == 2)
	}

	@Test("Trends navigation carries exact date range and clears stale payloads")
	func navigationRange() throws {
		let defaults = try IsolatedTestPreferences()
		let navigation = NavigationManager(defaults: defaults.defaults)
		let now = try date(2026, 11, 4)
		let range = try #require(TrendsPeriod.oneYear.range(calendar: calendar, now: now))
		let medicationID = UUID().uuidString
		navigation.navigateToHistory(medicationID: medicationID, range: range)
		#expect(navigation.historyTargetRange == range)
		#expect(navigation.historyTargetMedicationID == medicationID)
		navigation.navigateToHistory()
		#expect(navigation.historyTargetRange == nil)
		navigation.navigateToHistory(range: range)
		navigation.clearHistoryNavigation()
		#expect(navigation.historyTargetRange == nil)
	}
}

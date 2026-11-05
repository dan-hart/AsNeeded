import Foundation
import Testing
@testable import AsNeeded

@Suite("Trends date ranges")
struct TrendsDateRangeTests {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
		return calendar
	}

	private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) throws -> Date {
		try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
	}

	@Test("Existing presets preserve complete-day counts", arguments: [14, 30, 90])
	func existingPresets(days: Int) throws {
		let now = try date(2026, 11, 4, hour: 12)
		let period = try #require(TrendsPeriod(rawValue: days))
		let range = try #require(period.range(calendar: calendar, now: now))
		#expect(range.dayCount(calendar: calendar) == days)
		#expect(range.end == (try date(2026, 11, 3)))
	}

	@Test("Existing seven-day widget scope remains seven complete days")
	func widgetSevenDayScope() throws {
		let period = try #require(TrendsPeriod(rawValue: 7))
		let now = try date(2026, 11, 4, hour: 12)
		let range = try #require(period.range(calendar: calendar, now: now))
		#expect(range.start == (try date(2026, 10, 28)))
		#expect(range.end == (try date(2026, 11, 3)))
		#expect(range.dayCount(calendar: calendar) == 7)
	}

	@Test("Year presets use calendar years including leap day")
	func yearPresets() throws {
		let now = try date(2024, 3, 1, hour: 12)
		let year = try #require(TrendsPeriod.oneYear.range(calendar: calendar, now: now))
		#expect(year.start == (try date(2023, 3, 1)))
		#expect(year.end == (try date(2024, 2, 29)))
		#expect(year.dayCount(calendar: calendar) == 366)
		let twoYears = try #require(TrendsPeriod.twoYears.range(calendar: calendar, now: now))
		#expect(twoYears.start == (try date(2022, 3, 1)))
		#expect(twoYears.dayCount(calendar: calendar) == 731)
	}

	@Test("Year ending after February 29 remains a calendar year")
	func leapYearAnniversary() throws {
		let range = try #require(TrendsPeriod.oneYear.range(calendar: calendar, now: date(2024, 2, 29)))
		#expect(range.start == (try date(2023, 2, 28)))
		#expect(range.end == (try date(2024, 2, 28)))
	}

	@Test("Custom range includes both selected dates and normalizes times")
	func customInclusive() throws {
		let range = try #require(TrendsDateRange(start: date(2026, 3, 7, hour: 12), end: date(2026, 3, 9, hour: 18), calendar: calendar, now: date(2026, 3, 10)))
		#expect(range.start == (try date(2026, 3, 7)))
		#expect(range.end == (try date(2026, 3, 9)))
		#expect(range.dayCount(calendar: calendar) == 3)
	}

	@Test("Single-day custom range is valid")
	func singleDay() throws {
		let day = try date(2026, 11, 3)
		let range = try #require(TrendsDateRange(start: day, end: day, calendar: calendar, now: date(2026, 11, 4)))
		#expect(range.dayCount(calendar: calendar) == 1)
	}

	@Test("Invalid custom ranges exclude reversed, current and future dates")
	func invalidCustom() throws {
		let now = try date(2026, 11, 4, hour: 12)
		#expect(TrendsDateRange(start: try date(2026, 11, 3), end: try date(2026, 11, 2), calendar: calendar, now: now) == nil)
		#expect(TrendsDateRange(start: try date(2026, 11, 3), end: now, calendar: calendar, now: now) == nil)
		#expect(TrendsDateRange(start: now, end: try date(2026, 11, 5), calendar: calendar, now: now) == nil)
	}
}

import Foundation

/// Rolling presets end at yesterday; years use calendar arithmetic rather than fixed day counts.
enum TrendsPeriod: Int, CaseIterable {
	case fourteenDays = 14
	case thirtyDays = 30
	case ninetyDays = 90
	case oneYear = -1
	case twoYears = -2

	var displayName: String {
		switch self {
		case .fourteenDays, .thirtyDays, .ninetyDays:
			return String(localized: "\(rawValue) Days")
		case .oneYear, .twoYears:
			return DateComponentsFormatter.localizedString(from: DateComponents(year: -rawValue), unitsStyle: .full) ?? (-rawValue).formatted()
		}
	}

	func range(calendar: Calendar, now: Date) -> TrendsDateRange? {
		let today = calendar.startOfDay(for: now)
		let component: Calendar.Component = rawValue > 0 ? .day : .year
		let offset = rawValue > 0 ? -rawValue : rawValue
		guard let start = calendar.date(byAdding: component, value: offset, to: today),
			let end = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
		return TrendsDateRange(start: start, end: end, calendar: calendar, now: now)
	}
}

/// Inclusive local calendar dates. Invalid, partial, and future days are rejected.
struct TrendsDateRange: Equatable {
	let start: Date
	let end: Date
	private let timeZone: TimeZone

	init?(start: Date, end: Date, calendar: Calendar, now: Date) {
		let first = calendar.startOfDay(for: start)
		let last = calendar.startOfDay(for: end)
		guard first <= last, last < calendar.startOfDay(for: now) else { return nil }
		self.start = first
		self.end = last
		self.timeZone = calendar.timeZone
	}

	/// Keep the selected wall-calendar dates when the system timezone changes.
	func resolved(calendar: Calendar, now: Date) -> TrendsDateRange? {
		var originalCalendar = calendar
		originalCalendar.timeZone = timeZone
		guard let first = calendar.date(from: originalCalendar.dateComponents([.era, .year, .month, .day], from: start)),
			let last = calendar.date(from: originalCalendar.dateComponents([.era, .year, .month, .day], from: end)) else { return nil }
		return TrendsDateRange(start: first, end: last, calendar: calendar, now: now)
	}

	func dayCount(calendar: Calendar) -> Int {
		(calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
	}

	var displayName: String {
		let first = start.formatted(date: .abbreviated, time: .omitted)
		let last = end.formatted(date: .abbreviated, time: .omitted)
		return start == end ? first : "\(first) – \(last)"
	}
}

import Foundation

/// Shared rolling presets. Trends ends yesterday; History can include today. Years use calendar arithmetic.
enum TrendsPeriod: Int, CaseIterable {
	case sevenDays = 7
	case fourteenDays = 14
	case thirtyDays = 30
	case ninetyDays = 90
	case oneYear = -1
	case twoYears = -2

	/// The existing widget has a seven-day scope; keep standard app menu choices unchanged.
	static let menuPeriods: [Self] = [.fourteenDays, .thirtyDays, .ninetyDays, .oneYear, .twoYears]

	var displayName: String {
		switch self {
		case .sevenDays, .fourteenDays, .thirtyDays, .ninetyDays:
			return String(localized: "\(rawValue) Days")
		case .oneYear, .twoYears:
			return DateComponentsFormatter.localizedString(from: DateComponents(year: -rawValue), unitsStyle: .full) ?? (-rawValue).formatted()
		}
	}

	func range(calendar: Calendar, now: Date, includingToday: Bool = false) -> TrendsDateRange? {
		let today = calendar.startOfDay(for: now)
		guard let endExclusive = calendar.date(byAdding: .day, value: includingToday ? 1 : 0, to: today) else { return nil }
		let component: Calendar.Component = rawValue > 0 ? .day : .year
		let offset = rawValue > 0 ? -rawValue : rawValue
		guard let start = calendar.date(byAdding: component, value: offset, to: endExclusive),
			let end = calendar.date(byAdding: .day, value: -1, to: endExclusive) else { return nil }
		return TrendsDateRange(start: start, end: end, calendar: calendar, now: now, includingToday: includingToday)
	}
}

/// Inclusive local calendar dates. Today is accepted only when explicitly requested by History.
struct TrendsDateRange: Equatable {
	let start: Date
	let end: Date
	private let timeZone: TimeZone
	private let includingToday: Bool

	init?(start: Date, end: Date, calendar: Calendar, now: Date, includingToday: Bool = false) {
		let first = calendar.startOfDay(for: start)
		let last = calendar.startOfDay(for: end)
		let today = calendar.startOfDay(for: now)
		guard first <= last, includingToday ? last <= today : last < today else { return nil }
		self.start = first
		self.end = last
		self.timeZone = calendar.timeZone
		self.includingToday = includingToday
	}

	/// Keep the selected wall-calendar dates when the system timezone changes.
	func resolved(calendar: Calendar, now: Date) -> TrendsDateRange? {
		var originalCalendar = calendar
		originalCalendar.timeZone = timeZone
		guard let first = calendar.date(from: originalCalendar.dateComponents([.era, .year, .month, .day], from: start)),
			let last = calendar.date(from: originalCalendar.dateComponents([.era, .year, .month, .day], from: end)) else { return nil }
		return TrendsDateRange(start: first, end: last, calendar: calendar, now: now, includingToday: includingToday)
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

import Foundation

/// Session-only History filters leave the default All Time experience unchanged.
enum HistoryDateFilter: Equatable {
	case allTime
	case period(TrendsPeriod)
	case custom(TrendsDateRange)

	func range(calendar: Calendar, now: Date) -> TrendsDateRange? {
		switch self {
		case .allTime: nil
		case let .period(period): period.range(calendar: calendar, now: now, includingToday: true)
		case let .custom(range): range.resolved(calendar: calendar, now: now)
		}
	}
}

// Date+RelativeFormatting.swift
// Extension for human-friendly relative date formatting

import Foundation

extension Date {
	/// Formats date relative to now with human-friendly text
	/// - Parameter isPast: Whether the date is in the past (affects phrasing)
	/// - Returns: Human-readable relative date string (e.g., "3 days ago", "in 2 weeks")
	func relativeFormatted(isPast: Bool, now: Date = .now, locale: Locale = .current) -> String {
		let calendar = Calendar.current
		let day = calendar.startOfDay(for: self)
		let referenceDay = calendar.startOfDay(for: now)
		let days = abs(calendar.dateComponents([.day], from: referenceDay, to: day).day ?? 0)
		let component: DateComponents
		let direction = isPast ? -1 : 1
		switch days {
		case 0: component = DateComponents(day: 0)
		case 1...6: component = DateComponents(day: direction * days)
		case 7...29: component = DateComponents(weekOfMonth: direction * (days / 7))
		case 30...364: component = DateComponents(month: direction * (days / 30))
		default: component = DateComponents(year: direction * (days / 365))
		}
		let formatter = RelativeDateTimeFormatter()
		formatter.locale = locale
		formatter.dateTimeStyle = days <= 1 ? .named : .numeric
		return formatter.localizedString(from: component)
	}

	/// Convenience method for past dates
	/// - Returns: Past relative formatting (e.g., "3 days ago")
	var relativeFormattedAsPast: String {
		relativeFormatted(isPast: true)
	}

	/// Convenience method for future dates
	/// - Returns: Future relative formatting (e.g., "in 5 days")
	var relativeFormattedAsFuture: String {
		relativeFormatted(isPast: false)
	}

	/// Automatic relative formatting that determines if date is past or future
	/// - Returns: Appropriate relative formatting based on relationship to now
	var relativeFormatted: String {
		let now = Date()
		return relativeFormatted(isPast: self < now)
	}
}

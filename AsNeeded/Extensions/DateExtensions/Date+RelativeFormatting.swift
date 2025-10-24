// Date+RelativeFormatting.swift
// Extension for human-friendly relative date formatting

import Foundation

extension Date {
    /// Formats date relative to now with human-friendly text
    /// - Parameter isPast: Whether the date is in the past (affects phrasing)
    /// - Returns: Human-readable relative date string (e.g., "3 days ago", "in 2 weeks")
    func relativeFormatted(isPast: Bool) -> String {
        let calendar = Calendar.current
        let now = Date()

        // Use start of day for more reliable day calculations
        let selfStartOfDay = calendar.startOfDay(for: self)
        let nowStartOfDay = calendar.startOfDay(for: now)

        let components = calendar.dateComponents([.day], from: selfStartOfDay, to: nowStartOfDay)

        guard let daysDifference = components.day else {
            // Fallback to short date format
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: self)
        }

        let days = abs(daysDifference)

        switch days {
        case 0:
            return "today"
        case 1:
            return isPast ? "yesterday" : "tomorrow"
        case 2 ... 6:
            return isPast ? "\(days) days ago" : "in \(days) days"
        case 7 ... 13:
            let weeks = days / 7
            return isPast ? "\(weeks) week\(weeks == 1 ? "" : "s") ago" : "in \(weeks) week\(weeks == 1 ? "" : "s")"
        case 14 ... 29:
            let weeks = days / 7
            return isPast ? "\(weeks) weeks ago" : "in \(weeks) weeks"
        case 30 ... 364:
            let months = days / 30
            return isPast ? "\(months) month\(months == 1 ? "" : "s") ago" : "in \(months) month\(months == 1 ? "" : "s")"
        default:
            let years = days / 365
            return isPast ? "\(years) year\(years == 1 ? "" : "s") ago" : "in \(years) year\(years == 1 ? "" : "s")"
        }
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

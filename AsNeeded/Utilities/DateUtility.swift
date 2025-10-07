// DateUtility.swift
// Centralized date operations and formatting utilities

import Foundation
import ANModelKit
import DHLoggingKit

public enum DateUtility {
	private static let logger = DHLogger(category: "DateUtility")
	
	// MARK: - Date Range Operations
	
	/// Get the start of the current day
	public static var startOfToday: Date {
		Calendar.current.startOfDay(for: Date())
	}
	
	/// Get the start of tomorrow
	public static var startOfTomorrow: Date {
		Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
	}
	
	/// Get the start and end of a specific day
	public static func dayRange(for date: Date) -> (start: Date, end: Date) {
		let calendar = Calendar.current
		let start = calendar.startOfDay(for: date)
		let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
		return (start, end)
	}
	
	/// Get the start and end of the current week
	public static func currentWeekRange() -> (start: Date, end: Date) {
		let calendar = Calendar.current
		let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
		let start = calendar.date(from: components) ?? Date()
		let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? Date()
		return (start, end)
	}
	
	/// Get the start and end of the current month
	public static func currentMonthRange() -> (start: Date, end: Date) {
		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: Date())
		let start = calendar.date(from: components) ?? Date()
		let end = calendar.date(byAdding: .month, value: 1, to: start) ?? Date()
		return (start, end)
	}
	
	// MARK: - Event Filtering
	
	/// Filter events for today
	public static func filterEventsForToday(_ events: [ANEventConcept]) -> [ANEventConcept] {
		let (start, end) = dayRange(for: Date())
		return events.filter { $0.date >= start && $0.date < end }
	}
	
	/// Filter events for a specific date range
	public static func filterEvents(_ events: [ANEventConcept], from startDate: Date, to endDate: Date) -> [ANEventConcept] {
		return events.filter { $0.date >= startDate && $0.date <= endDate }
	}
	
	/// Filter events for a specific medication within a date range
	public static func filterEvents(
		_ events: [ANEventConcept],
		for medication: ANMedicationConcept,
		from startDate: Date? = nil,
		to endDate: Date? = nil
	) -> [ANEventConcept] {
		var filtered = events.filter { $0.medication?.id == medication.id }
		
		if let start = startDate {
			filtered = filtered.filter { $0.date >= start }
		}
		
		if let end = endDate {
			filtered = filtered.filter { $0.date <= end }
		}
		
		return filtered
	}
	
	// MARK: - Statistics
	
	/// Calculate daily statistics for a medication
	public static func calculateDailyStats(
		for medication: ANMedicationConcept,
		events: [ANEventConcept],
		on date: Date
	) -> (totalDoses: Int, totalAmount: Double, unit: ANUnitConcept) {
		let (start, end) = dayRange(for: date)
		let dayEvents = events.filter { event in
			event.eventType == .doseTaken &&
			event.medication?.id == medication.id &&
			event.date >= start &&
			event.date < end
		}
		
		let totalDoses = dayEvents.count
		let totalAmount = dayEvents.compactMap { $0.dose?.amount }.reduce(0, +)
		let unit = medication.prescribedUnit ?? .unit
		
		logger.debug("Daily stats for medication \(medication.id) on \(date): \(totalDoses) doses, \(totalAmount) \(unit.displayName)")
		
		return (totalDoses, totalAmount, unit)
	}
	
	/// Calculate weekly statistics for a medication
	public static func calculateWeeklyStats(
		for medication: ANMedicationConcept,
		events: [ANEventConcept]
	) -> [(date: Date, doses: Int, amount: Double)] {
		let calendar = Calendar.current
		let endDate = Date()

		var stats: [(date: Date, doses: Int, amount: Double)] = []
		
		for dayOffset in 0..<7 {
			let date = calendar.date(byAdding: .day, value: -dayOffset, to: endDate) ?? endDate
			let (doses, amount, _) = calculateDailyStats(for: medication, events: events, on: date)
			stats.append((date: date, doses: doses, amount: amount))
		}
		
		return stats.reversed()
	}
	
	// MARK: - Formatting
	
	/// Format a date for display in history
	public static func formatForHistory(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .short
		return formatter.string(from: date)
	}
	
	/// Format a date for relative display (e.g., "2 hours ago")
	public static func formatRelative(_ date: Date) -> String {
		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .full
		return formatter.localizedString(for: date, relativeTo: Date())
	}
	
	/// Format a time interval as duration
	public static func formatDuration(_ interval: TimeInterval) -> String {
		let hours = Int(interval) / 3600
		let minutes = (Int(interval) % 3600) / 60
		
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		} else {
			return "\(minutes)m"
		}
	}
	
	// MARK: - Validation
	
	/// Check if a date is today
	public static func isToday(_ date: Date) -> Bool {
		Calendar.current.isDateInToday(date)
	}
	
	/// Check if a date is in the future
	public static func isFuture(_ date: Date) -> Bool {
		date > Date()
	}
	
	/// Check if a date is within a reasonable range for logging medications
	public static func isValidMedicationDate(_ date: Date) -> Bool {
		let calendar = Calendar.current
		let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
		let oneWeekFromNow = calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
		
		return date >= oneYearAgo && date <= oneWeekFromNow
	}
}
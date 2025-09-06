// DateUtilityTests.swift
// Comprehensive unit tests for DateUtility

import Testing
import Foundation
@testable import AsNeeded
import ANModelKit

@Suite("DateUtility Tests", .tags(.date, .utility, .unit))
struct DateUtilityTests {
	
	// MARK: - Helper Properties
	
	private var calendar: Calendar { Calendar.current }
	
	private var testDate: Date {
		// Create a fixed test date for consistent testing
		let components = DateComponents(year: 2024, month: 6, day: 15, hour: 14, minute: 30)
		return calendar.date(from: components) ?? Date()
	}
	
	// MARK: - Date Range Tests
	
	@Test("Start of today should be midnight")
	func testStartOfToday() {
		let startOfToday = DateUtility.startOfToday
		let components = calendar.dateComponents([.hour, .minute, .second], from: startOfToday)
		
		#expect(components.hour == 0)
		#expect(components.minute == 0)
		#expect(components.second == 0)
		#expect(calendar.isDateInToday(startOfToday))
	}
	
	@Test("Start of tomorrow should be next day midnight")
	func testStartOfTomorrow() {
		let startOfTomorrow = DateUtility.startOfTomorrow
		let components = calendar.dateComponents([.hour, .minute, .second], from: startOfTomorrow)
		
		#expect(components.hour == 0)
		#expect(components.minute == 0)
		#expect(components.second == 0)
		#expect(calendar.isDateInTomorrow(startOfTomorrow))
	}
	
	@Test("Day range should span exactly 24 hours")
	func testDayRange() {
		let (start, end) = DateUtility.dayRange(for: testDate)
		
		let startComponents = calendar.dateComponents([.hour, .minute, .second], from: start)
		#expect(startComponents.hour == 0)
		#expect(startComponents.minute == 0)
		#expect(startComponents.second == 0)
		
		let interval = end.timeIntervalSince(start)
		#expect(interval == 24 * 60 * 60) // 24 hours in seconds
	}
	
	@Test("Current week range should start on correct weekday")
	func testCurrentWeekRange() {
		let (start, end) = DateUtility.currentWeekRange()
		
		// Week should start on Sunday (or Monday depending on locale)
		let weekday = calendar.component(.weekday, from: start)
		#expect(weekday == calendar.firstWeekday)
		
		// Should span exactly one week
		let days = calendar.dateComponents([.day], from: start, to: end).day
		#expect(days == 7)
	}
	
	@Test("Current month range should start on first day")
	func testCurrentMonthRange() {
		let (start, end) = DateUtility.currentMonthRange()
		
		let startDay = calendar.component(.day, from: start)
		#expect(startDay == 1)
		
		// End should be start of next month
		let endComponents = calendar.dateComponents([.month, .day], from: end)
		#expect(endComponents.day == 1)
	}
	
	// MARK: - Event Filtering Tests
	
	@Test("Filter events for today should only include today's events")
	func testFilterEventsForToday() {
		let todayEvent1 = ANEventConcept(eventType: .doseTaken, date: Date())
		let todayEvent2 = ANEventConcept(eventType: .doseTaken, date: Date().addingTimeInterval(-3600))
		let yesterdayEvent = ANEventConcept(eventType: .doseTaken, date: Date().addingTimeInterval(-86400))
		let tomorrowEvent = ANEventConcept(eventType: .doseTaken, date: Date().addingTimeInterval(86400))
		
		let events = [todayEvent1, todayEvent2, yesterdayEvent, tomorrowEvent]
		let filtered = DateUtility.filterEventsForToday(events)
		
		#expect(filtered.count == 2)
		#expect(filtered.contains { $0.id == todayEvent1.id })
		#expect(filtered.contains { $0.id == todayEvent2.id })
	}
	
	@Test("Filter events by date range should be inclusive")
	func testFilterEventsByDateRange() {
		let startDate = Date().addingTimeInterval(-7200) // 2 hours ago
		let endDate = Date().addingTimeInterval(3600) // 1 hour from now
		
		let beforeEvent = ANEventConcept(eventType: .doseTaken, date: startDate.addingTimeInterval(-3600))
		let startEvent = ANEventConcept(eventType: .doseTaken, date: startDate)
		let middleEvent = ANEventConcept(eventType: .doseTaken, date: Date())
		let endEvent = ANEventConcept(eventType: .doseTaken, date: endDate)
		let afterEvent = ANEventConcept(eventType: .doseTaken, date: endDate.addingTimeInterval(3600))
		
		let events = [beforeEvent, startEvent, middleEvent, endEvent, afterEvent]
		let filtered = DateUtility.filterEvents(events, from: startDate, to: endDate)
		
		#expect(filtered.count == 3)
		#expect(filtered.contains { $0.id == startEvent.id })
		#expect(filtered.contains { $0.id == middleEvent.id })
		#expect(filtered.contains { $0.id == endEvent.id })
	}
	
	@Test("Filter events for medication should only include matching medication")
	func testFilterEventsForMedication() {
		let med1 = ANMedicationConcept(clinicalName: "Med1")
		let med2 = ANMedicationConcept(clinicalName: "Med2")
		
		let event1 = ANEventConcept(eventType: .doseTaken, medication: med1, date: Date())
		let event2 = ANEventConcept(eventType: .doseTaken, medication: med1, date: Date().addingTimeInterval(-3600))
		let event3 = ANEventConcept(eventType: .doseTaken, medication: med2, date: Date())
		
		let events = [event1, event2, event3]
		let filtered = DateUtility.filterEvents(events, for: med1)
		
		#expect(filtered.count == 2)
		#expect(filtered.allSatisfy { $0.medication?.id == med1.id })
	}
	
	// MARK: - Statistics Tests
	
	@Test("Calculate daily stats should sum correctly")
	func testCalculateDailyStats() {
		let medication = ANMedicationConcept(
			clinicalName: "Test Med",
			prescribedUnit: .milligram,
			prescribedDoseAmount: 10
		)
		
		let dose1 = ANDoseConcept(amount: 10, unit: .milligram)
		let dose2 = ANDoseConcept(amount: 20, unit: .milligram)
		let dose3 = ANDoseConcept(amount: 15, unit: .milligram)
		
		let today = Date()
		let event1 = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose1, date: today)
		let event2 = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose2, date: today.addingTimeInterval(-3600))
		let event3 = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose3, date: today.addingTimeInterval(-7200))
		let yesterdayEvent = ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose1, date: today.addingTimeInterval(-86400))
		
		let events = [event1, event2, event3, yesterdayEvent]
		let (totalDoses, totalAmount, unit) = DateUtility.calculateDailyStats(for: medication, events: events, on: today)
		
		#expect(totalDoses == 3)
		#expect(totalAmount == 45) // 10 + 20 + 15
		#expect(unit.displayName == "Milligram")
	}
	
	@Test("Calculate weekly stats should return 7 days")
	func testCalculateWeeklyStats() {
		let medication = ANMedicationConcept(clinicalName: "Test Med")
		let dose = ANDoseConcept(amount: 10, unit: .milligram)
		
		var events: [ANEventConcept] = []
		for dayOffset in 0..<7 {
			let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
			events.append(ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose, date: date))
		}
		
		let stats = DateUtility.calculateWeeklyStats(for: medication, events: events)
		
		#expect(stats.count == 7)
		#expect(stats.allSatisfy { $0.doses == 1 && $0.amount == 10 })
	}
	
	// MARK: - Formatting Tests
	
	@Test("Format for history should include date and time")
	func testFormatForHistory() {
		let formatted = DateUtility.formatForHistory(testDate)
		
		// Should contain both date and time components
		#expect(formatted.contains("2024") || formatted.contains("24"))
		#expect(formatted.contains("Jun") || formatted.contains("6") || formatted.contains("06"))
		#expect(formatted.contains("15"))
		#expect(formatted.contains("2:30") || formatted.contains("14:30"))
	}
	
	@Test("Format relative should use relative terms")
	func testFormatRelative() {
		let oneHourAgo = Date().addingTimeInterval(-3600)
		let formatted = DateUtility.formatRelative(oneHourAgo)
		
		// Should contain "hour" or "ago" or similar relative term
		#expect(formatted.contains("hour") || formatted.contains("ago") || formatted.contains("1"))
	}
	
	@Test("Format duration should handle hours and minutes")
	func testFormatDuration() {
		#expect(DateUtility.formatDuration(30) == "0m")
		#expect(DateUtility.formatDuration(60) == "1m")
		#expect(DateUtility.formatDuration(3600) == "1h 0m")
		#expect(DateUtility.formatDuration(3660) == "1h 1m")
		#expect(DateUtility.formatDuration(7320) == "2h 2m")
	}
	
	// MARK: - Validation Tests
	
	@Test("Is today should correctly identify today's date")
	func testIsToday() {
		#expect(DateUtility.isToday(Date()) == true)
		#expect(DateUtility.isToday(Date().addingTimeInterval(-86400)) == false) // Yesterday
		#expect(DateUtility.isToday(Date().addingTimeInterval(86400)) == false) // Tomorrow
	}
	
	@Test("Is future should correctly identify future dates")
	func testIsFuture() {
		#expect(DateUtility.isFuture(Date().addingTimeInterval(60)) == true)
		#expect(DateUtility.isFuture(Date().addingTimeInterval(-60)) == false)
		#expect(DateUtility.isFuture(Date()) == false) // Now is not future
	}
	
	@Test("Is valid medication date should enforce reasonable range")
	func testIsValidMedicationDate() {
		let now = Date()
		let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
		let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: now) ?? now
		let threeDaysFromNow = calendar.date(byAdding: .day, value: 3, to: now) ?? now
		let twoWeeksFromNow = calendar.date(byAdding: .weekOfYear, value: 2, to: now) ?? now
		
		#expect(DateUtility.isValidMedicationDate(now) == true)
		#expect(DateUtility.isValidMedicationDate(sixMonthsAgo) == true)
		#expect(DateUtility.isValidMedicationDate(twoYearsAgo) == false) // Too old
		#expect(DateUtility.isValidMedicationDate(threeDaysFromNow) == true)
		#expect(DateUtility.isValidMedicationDate(twoWeeksFromNow) == false) // Too far future
	}
	
	// MARK: - Performance Tests
	
	@Test("Filtering large event sets should be performant")
	func testFilteringPerformance() {
		// Create 10000 events spread over a month
		var events: [ANEventConcept] = []
		for i in 0..<10000 {
			let timeOffset = TimeInterval(i * 300) // 5 minute intervals
			let date = Date().addingTimeInterval(-timeOffset)
			events.append(ANEventConcept(eventType: .doseTaken, date: date))
		}
		
		let startTime = Date()
		let filtered = DateUtility.filterEventsForToday(events)
		let elapsed = Date().timeIntervalSince(startTime)
		
		#expect(filtered.count > 0)
		#expect(elapsed < 0.1) // Should complete in less than 100ms
	}
	
	@Test("Statistics calculation should be performant")
	func testStatisticsPerformance() {
		let medication = ANMedicationConcept(clinicalName: "Test Med")
		let dose = ANDoseConcept(amount: 10, unit: .milligram)
		
		// Create 1000 events for the medication
		var events: [ANEventConcept] = []
		for i in 0..<1000 {
			let timeOffset = TimeInterval(i * 3600) // Hourly events
			let date = Date().addingTimeInterval(-timeOffset)
			events.append(ANEventConcept(eventType: .doseTaken, medication: medication, dose: dose, date: date))
		}
		
		let startTime = Date()
		let stats = DateUtility.calculateWeeklyStats(for: medication, events: events)
		let elapsed = Date().timeIntervalSince(startTime)
		
		#expect(stats.count == 7)
		#expect(elapsed < 0.5) // Should complete in less than 500ms
	}
}

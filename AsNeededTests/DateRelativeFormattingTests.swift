//
//  DateRelativeFormattingTests.swift
//  AsNeededTests
//
//  Tests for Date relative formatting extension
//

import Testing
import Foundation
@testable import AsNeeded

@MainActor
struct DateRelativeFormattingTests {
	
	private let calendar = Calendar.current
	private let now = Date()
	
	// MARK: - Same Day Tests

	@Test("Today should return 'today'")
	func testToday() {
		#expect(now.relativeFormatted(isPast: true) == "today")
		#expect(now.relativeFormatted(isPast: false) == "today")
	}
	
	// MARK: - Yesterday/Tomorrow Tests

	@Test("Yesterday should return 'yesterday'")
	func testYesterday() {
		guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
			#expect(false, "Failed to create yesterday date")
			return
		}
		#expect(yesterday.relativeFormattedAsPast == "yesterday")
	}
	
	@Test("Tomorrow should return 'tomorrow'")
	func testTomorrow() {
		guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
			#expect(false, "Failed to create tomorrow date")
			return
		}
		#expect(tomorrow.relativeFormattedAsFuture == "tomorrow")
	}
	
	// MARK: - Days Tests

	@Test("Past days should format correctly")
	func testPastDays() {
		let testCases = [
			(days: -2, expected: "2 days ago"),
			(days: -3, expected: "3 days ago"),
			(days: -6, expected: "6 days ago")
		]
		
		for testCase in testCases {
			guard let date = calendar.date(byAdding: .day, value: testCase.days, to: now) else {
				#expect(false, "Failed to create date for \(testCase.days) days")
				continue
			}
			#expect(date.relativeFormattedAsPast == testCase.expected)
		}
	}
	
	@Test("Future days should format correctly")
	func testFutureDays() {
		let testCases = [
			(days: 2, expected: "in 2 days"),
			(days: 3, expected: "in 3 days"),
			(days: 6, expected: "in 6 days")
		]
		
		for testCase in testCases {
			guard let date = calendar.date(byAdding: .day, value: testCase.days, to: now) else {
				#expect(false, "Failed to create date for \(testCase.days) days")
				continue
			}
			#expect(date.relativeFormattedAsFuture == testCase.expected)
		}
	}
	
	// MARK: - Weeks Tests

	@Test("Past weeks should format correctly")
	func testPastWeeks() {
		let testCases = [
			(days: -7, expected: "1 week ago"),
			(days: -10, expected: "1 week ago"), // 10 days = 1 week (integer division)
			(days: -13, expected: "1 week ago"),
			(days: -14, expected: "2 weeks ago"),
			(days: -21, expected: "3 weeks ago"),
			(days: -28, expected: "4 weeks ago")
		]
		
		for testCase in testCases {
			guard let date = calendar.date(byAdding: .day, value: testCase.days, to: now) else {
				#expect(false, "Failed to create date for \(testCase.days) days")
				continue
			}
			#expect(date.relativeFormattedAsPast == testCase.expected)
		}
	}
	
	@Test("Future weeks should format correctly")
	func testFutureWeeks() {
		let testCases = [
			(days: 7, expected: "in 1 week"),
			(days: 10, expected: "in 1 week"),
			(days: 14, expected: "in 2 weeks"),
			(days: 21, expected: "in 3 weeks")
		]
		
		for testCase in testCases {
			guard let date = calendar.date(byAdding: .day, value: testCase.days, to: now) else {
				#expect(false, "Failed to create date for \(testCase.days) days")
				continue
			}
			#expect(date.relativeFormattedAsFuture == testCase.expected)
		}
	}
	
	// MARK: - Months Tests

	@Test("Past months should format correctly")
	func testPastMonths() {
		let testCases = [
			(days: -30, expected: "1 month ago"),
			(days: -45, expected: "1 month ago"), // 45 days = 1 month (integer division)
			(days: -60, expected: "2 months ago"),
			(days: -90, expected: "3 months ago"),
			(days: -180, expected: "6 months ago"),
			(days: -300, expected: "10 months ago")
		]
		
		for testCase in testCases {
			guard let date = calendar.date(byAdding: .day, value: testCase.days, to: now) else {
				#expect(false, "Failed to create date for \(testCase.days) days")
				continue
			}
			#expect(date.relativeFormattedAsPast == testCase.expected)
		}
	}
	
	@Test("Future months should format correctly")
	func testFutureMonths() {
		let testCases = [
			(days: 30, expected: "in 1 month"),
			(days: 60, expected: "in 2 months"),
			(days: 90, expected: "in 3 months")
		]
		
		for testCase in testCases {
			guard let date = calendar.date(byAdding: .day, value: testCase.days, to: now) else {
				#expect(false, "Failed to create date for \(testCase.days) days")
				continue
			}
			#expect(date.relativeFormattedAsFuture == testCase.expected)
		}
	}
	
	// MARK: - Years Tests

	@Test("Past years should format correctly")
	func testPastYears() {
		let testCases = [
			(days: -365, expected: "1 year ago"),
			(days: -730, expected: "2 years ago"),
			(days: -1095, expected: "3 years ago")
		]
		
		for testCase in testCases {
			guard let date = calendar.date(byAdding: .day, value: testCase.days, to: now) else {
				#expect(false, "Failed to create date for \(testCase.days) days")
				continue
			}
			#expect(date.relativeFormattedAsPast == testCase.expected)
		}
	}
	
	@Test("Future years should format correctly")
	func testFutureYears() {
		let testCases = [
			(days: 365, expected: "in 1 year"),
			(days: 730, expected: "in 2 years")
		]
		
		for testCase in testCases {
			guard let date = calendar.date(byAdding: .day, value: testCase.days, to: now) else {
				#expect(false, "Failed to create date for \(testCase.days) days")
				continue
			}
			#expect(date.relativeFormattedAsFuture == testCase.expected)
		}
	}
	
	// MARK: - Singular vs Plural Tests

	@Test("Singular forms should not have 's' suffix")
	func testSingularForms() {
		let singularTests = [
			(calendar.date(byAdding: .day, value: -7, to: now), "1 week ago"),
			(calendar.date(byAdding: .day, value: -30, to: now), "1 month ago"),
			(calendar.date(byAdding: .day, value: -365, to: now), "1 year ago"),
			(calendar.date(byAdding: .day, value: 7, to: now), "in 1 week"),
			(calendar.date(byAdding: .day, value: 30, to: now), "in 1 month"),
			(calendar.date(byAdding: .day, value: 365, to: now), "in 1 year")
		]
		
		for (date, expected) in singularTests {
			guard let testDate = date else {
				#expect(false, "Failed to create test date")
				continue
			}
			let isPast = testDate < now
			#expect(testDate.relativeFormatted(isPast: isPast) == expected)
		}
	}
	
	// MARK: - Convenience Methods Tests

	@Test("Convenience methods should work correctly")
	func testConvenienceMethods() {
		guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
			  let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
			#expect(false, "Failed to create test dates")
			return
		}
		
		#expect(yesterday.relativeFormattedAsPast == "yesterday")
		#expect(tomorrow.relativeFormattedAsFuture == "tomorrow")
	}
}
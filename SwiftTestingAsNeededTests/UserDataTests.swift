//
//  UserDataTests.swift
//  SwiftTestingAsNeededTests
//
//  Created by Dan Hart on 7/1/24.
//

import Testing
import Foundation
import SwiftDate
@testable import AsNeeded

struct UserDataTests {
    struct TestCriteria: Equatable, Hashable {
        let startDate: Date
        let refillDate: Date
        let days: Double
    }
    
    @Test("Days Until Next Refill Date Calculation", arguments: [
        TestCriteria(
            startDate: Date(year: 9999, month: 10, day: 7, hour: 10, minute: 10),
            refillDate: Date(year: 9999, month: 10, day: 21, hour: 10, minute: 10),
            days: 14.0),
        TestCriteria(
            startDate: Date(year: 9999, month: 10, day: 7, hour: 10, minute: 10),
            refillDate: Date(year: 9999, month: 10, day: 14, hour: 10, minute: 10),
            days: 7.0),
        TestCriteria(
            startDate: Date(year: 9999, month: 10, day: 7, hour: 10, minute: 10),
            refillDate: Date(year: 9999, month: 10, day: 7, hour: 10, minute: 10),
            days: 0.0),
        TestCriteria(
            startDate: Date(year: 9999, month: 10, day: 7, hour: 10, minute: 10),
            refillDate: Date(year: 9999, month: 10, day: 6, hour: 10, minute: 10),
            days: -1.0),
        TestCriteria(
            startDate: Date(year: 9999, month: 10, day: 7, hour: 10, minute: 10),
            refillDate: Date(year: 9999, month: 10, day: 1, hour: 10, minute: 10),
            days: -6.0),
        TestCriteria(
            startDate: Date(year: 9999, month: 10, day: 7, hour: 10, minute: 10),
            refillDate: Date(year: 9999, month: 10, day: 31, hour: 10, minute: 10),
            days: 24.0),
        TestCriteria(
            startDate: Date(year: 2024, month: 7, day: 1, hour: 18, minute: 32),
            refillDate: Date(year: 2024, month: 7, day: 8, hour: 0, minute: 32),
            days: 7),
    ])
    func nextRefillCalculaion(from criteria: TestCriteria) {
        let userData = UserData()
        userData.nextRefillDate = criteria.refillDate
        let daysUntilNextRefillDate = userData.calculateDaysRemainingUntilNextRefillDate(from: criteria.startDate)
        #expect(daysUntilNextRefillDate == criteria.days)
    }
}

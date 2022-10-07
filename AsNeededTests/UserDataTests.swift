//
//  UserDataTests.swift
//  AsNeededTests
//
//  Created by Dan Hart on 10/7/22.
//

import XCTest
@testable import AsNeeded

final class UserDataTests: XCTestCase {
    func testDaysUntilNextRefillDateCalculation() {
        let userData = UserData()
        userData.nextRefillDate = Date(year: 2022, month: 10, day: 21, hour: 10, minute: 10)
        let exampleDate = Date(year: 2022, month: 10, day: 7, hour: 10, minute: 10)
        let daysUntilNextRefillDate = userData.calculateDaysRemainingUntilNextRefillDate(from: exampleDate)
        XCTAssertEqual(daysUntilNextRefillDate, 14.0)
    }
}

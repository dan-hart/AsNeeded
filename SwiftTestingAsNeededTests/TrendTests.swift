//
//  TrendTests.swift
//  SwiftTestingAsNeededTests
//
//  Created by Dan Hart on 7/1/24.
//

import Testing
@testable import AsNeeded

@Suite("Testing Trend Analysis")
struct TrendTests {
    @Test("Stable Trends", arguments: [
        [],
        [1],
        [1, 1, 1, 1],
    ])
    func stable(numbers: [Double]) {
        let trend = TrendAnalyzer.trend(numbers: numbers)
        #expect(trend == .stable)
    }
    
    @Test("Downward Trends", arguments: [
        [5, 4, 3, 2, 1],
        [110, 120, 115, 108, 100, 101],
    ])
    func down(numbers: [Double]) {
        let trend = TrendAnalyzer.trend(numbers: numbers)
        #expect(trend == .down)
    }
    
    @Test("Upward Trends", arguments: [
        [1, 3, 2, 5, 4],
        [110, 100, 90, 115, 118],
    ])
    func up(numbers: [Double]) {
        let trend = TrendAnalyzer.trend(numbers: numbers)
        #expect(trend == .up)
    }
}

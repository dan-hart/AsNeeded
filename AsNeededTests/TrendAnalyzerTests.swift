//
//  TrendAnalyzerTests.swift
//  AsNeededTests
//
//  Created by Dan Hart on 7/20/23.
//

import XCTest
@testable import AsNeeded

final class TrendAnalyzerTests: XCTestCase {
    func testTrendEmptyArray() {
        let numbers = [Double]()
        let trend = TrendAnalyzer.trend(numbers: numbers)
        XCTAssertEqual(trend, .stable)
    }
    
    func testTrendOneNumberArray() {
        let numbers: [Double] = [1]
        let trend = TrendAnalyzer.trend(numbers: numbers)
        XCTAssertEqual(trend, .stable)
    }
    
    func testTrendAllSameNumberArray() {
        let numbers: [Double]  = [1, 1, 1, 1, 1]
        let trend = TrendAnalyzer.trend(numbers: numbers)
        XCTAssertEqual(trend, .stable)
    }
    
    func testTrendReversedArray() {
        let numbers: [Double]  = [5, 4, 3, 2, 1]
        let trend = TrendAnalyzer.trend(numbers: numbers)
        XCTAssertEqual(trend, .down)
    }
    
    func testTrendRandomArray() {
        let numbers: [Double]  = [1, 3, 2, 5, 4]
        let trend = TrendAnalyzer.trend(numbers: numbers)
        XCTAssertEqual(trend, .up)
    }
}

//
//  AsNeededTests.swift
//  AsNeededTests
//
//  Created by Dan Hart on 8/14/25.
//

@testable import AsNeeded
import Testing

@Suite(.tags(.smoke, .unit))
struct AsNeededTests {
    @Test("quick test example")
    func quickTestExample() {
        let sum = 2 + 2
        #expect(sum == 4)
    }
}

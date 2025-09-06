//
//  AsNeededTests.swift
//  AsNeededTests
//
//  Created by Dan Hart on 8/14/25.
//

import Testing
@testable import AsNeeded

@Suite
@Tag(.smoke) @Tag(.unit)
struct AsNeededTests {
	@Test("quick test example")
	func quickTestExample() {
		let sum = 2 + 2
		#expect(sum == 4)
	}
}

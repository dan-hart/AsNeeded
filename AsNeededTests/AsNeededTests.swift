//
//  AsNeededTests.swift
//  AsNeededTests
//
//  Created by AsNeeded Team on 8/14/25.
//

import Testing
@testable import AsNeeded

struct AsNeededTests {
	@Test("quick test example")
	func quickTestExample() {
		let sum = 2 + 2
		#expect(sum == 4)
	}
}

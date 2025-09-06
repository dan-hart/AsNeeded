//
//  DoubleFormattingTests.swift
//  AsNeededTests
//
//  Tests for Double formatting extension
//

import Testing
@testable import AsNeeded

@Suite(.tags(.formatter, .utility, .unit))
struct DoubleFormattingTests {
	
	@Test("Whole numbers should not show decimals")
	func testWholeNumbers() {
		#expect(1.0.formattedAmount == "1")
		#expect(10.0.formattedAmount == "10")
		#expect(100.0.formattedAmount == "100")
		#expect(0.0.formattedAmount == "0")
	}
	
	@Test("Should round to max 2 decimal places")
	func testDecimalRounding() {
		#expect(1.234567.formattedAmount == "1.23")
		#expect(1.235.formattedAmount == "1.24") // Rounds up
		#expect(1.999.formattedAmount == "2") // Rounds to whole number
		#expect(0.125.formattedAmount == "0.13") // Rounds up
	}
	
	@Test("Should remove trailing zeros")
	func testTrailingZeros() {
		#expect(1.5.formattedAmount == "1.5")
		#expect(1.50.formattedAmount == "1.5")
		#expect(1.10.formattedAmount == "1.1")
		#expect(2.00.formattedAmount == "2") // Becomes whole number
	}
	
	@Test("Should handle small decimals correctly")
	func testSmallDecimals() {
		#expect(0.1.formattedAmount == "0.1")
		#expect(0.01.formattedAmount == "0.01")
		#expect(0.001.formattedAmount == "0") // Rounds to 0
		#expect(0.005.formattedAmount == "0.01") // Rounds up
	}
	
	@Test("Should handle negative numbers")
	func testNegativeNumbers() {
		#expect((-1.0).formattedAmount == "-1")
		#expect((-1.5).formattedAmount == "-1.5")
		#expect((-1.234).formattedAmount == "-1.23")
		#expect((-0.005).formattedAmount == "-0.01")
	}
	
	@Test("Should handle edge cases")
	func testEdgeCases() {
		#expect(0.99999.formattedAmount == "1") // Rounds to 1
		#expect(1.004.formattedAmount == "1") // Rounds down
		#expect(1.005.formattedAmount == "1") // Banker's rounding - rounds to even
		#expect(1.025.formattedAmount == "1.02") // Banker's rounding - rounds to even
		#expect(1.126.formattedAmount == "1.13") // Rounds up
		#expect(999.999.formattedAmount == "1000") // Large number rounding
	}
}
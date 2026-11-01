//
//  DoubleFormattingTests.swift
//  AsNeededTests
//
//  Tests for Double formatting extension
//

@testable import AsNeeded
import ANModelKit
import Foundation
import Testing

@Suite(.tags(.formatter, .utility, .unit))
struct DoubleFormattingTests {
	private let locale = Locale(identifier: "en_US")
    @Test("Whole numbers should not show decimals")
    func wholeNumbers() {
        #expect(1.0.formattedAmount(locale: locale) == "1")
        #expect(10.0.formattedAmount(locale: locale) == "10")
        #expect(100.0.formattedAmount(locale: locale) == "100")
        #expect(0.0.formattedAmount(locale: locale) == "0")
    }

    @Test("Should round to max 2 decimal places")
    func decimalRounding() {
        #expect(1.234567.formattedAmount(locale: locale) == "1.23")
        #expect(1.235.formattedAmount(locale: locale) == "1.24") // Rounds up
        #expect(1.999.formattedAmount(locale: locale) == "2") // Rounds to whole number
        #expect(0.125.formattedAmount(locale: locale) == "0.13") // Rounds up
    }

    @Test("Should remove trailing zeros")
    func trailingZeros() {
        #expect(1.5.formattedAmount(locale: locale) == "1.5")
        #expect(1.50.formattedAmount(locale: locale) == "1.5")
        #expect(1.10.formattedAmount(locale: locale) == "1.1")
        #expect(2.00.formattedAmount(locale: locale) == "2") // Becomes whole number
    }

    @Test("Should handle small decimals correctly")
    func smallDecimals() {
        #expect(0.1.formattedAmount(locale: locale) == "0.1")
        #expect(0.01.formattedAmount(locale: locale) == "0.01")
        #expect(0.001.formattedAmount(locale: locale) == "0") // Rounds to 0
        #expect(0.005.formattedAmount(locale: locale) == "0.01") // Rounds up
    }

    @Test("Should handle negative numbers")
    func negativeNumbers() {
        #expect((-1.0).formattedAmount(locale: locale) == "-1")
        #expect((-1.5).formattedAmount(locale: locale) == "-1.5")
        #expect((-1.234).formattedAmount(locale: locale) == "-1.23")
        #expect((-0.005).formattedAmount(locale: locale) == "-0.01")
    }

    @Test("Should handle edge cases")
    func edgeCases() {
        #expect(0.99999.formattedAmount(locale: locale) == "1") // Rounds to 1
        #expect(1.004.formattedAmount(locale: locale) == "1") // Rounds down
        #expect(1.005.formattedAmount(locale: locale) == "1") // Banker's rounding - rounds to even
        #expect(1.025.formattedAmount(locale: locale) == "1.02") // Banker's rounding - rounds to even
        #expect(1.126.formattedAmount(locale: locale) == "1.13") // Rounds up
        #expect(999.999.formattedAmount(locale: locale) == "1000") // Large number rounding
    }

	@Test("Dose amounts use the requested decimal separator without grouping")
	func localizedDecimalAmounts() {
		#expect(1234.5.formattedAmount(locale: Locale(identifier: "de_DE")) == "1234,5")
		#expect(0.125.formattedAmount(locale: Locale(identifier: "fr_FR")) == "0,13")
		#expect((-0.005).formattedAmount(locale: Locale(identifier: "es_ES")) == "-0,01")
	}

	@Test("Localized decimal input validates the entire draft and retains fractional doses")
	func localizedDecimalInput() {
		#expect(DoseAmountInput.value(from: "١٫٢٥", locale: Locale(identifier: "ar_EG")) == 1.25)
		#expect(DoseAmountInput.value(from: "0,25", locale: Locale(identifier: "fr_FR")) == 0.25)
		#expect(DoseAmountInput.value(from: "1,5", locale: Locale(identifier: "de_DE")) == 1.5)
		#expect(DoseAmountInput.value(from: "0.25", locale: Locale(identifier: "en_US")) == 0.25)
		#expect(DoseAmountInput.value(from: "1e30", locale: Locale(identifier: "en_US")) == 1e30)
		for invalid in ["1,000", "1 000", "1abc", "NaN", "inf", "1.2.3", "1e", "1e999", "--1"] {
			#expect(DoseAmountInput.value(from: invalid, locale: Locale(identifier: "en_US")) == nil)
		}
		#expect(DoseAmountInput.value(from: "1.234,56", locale: Locale(identifier: "de_DE")) == nil)
	}

	@Test("Localized edit text round-trips stored fractional and extreme finite values")
	func editableAmountRoundTrip() {
		for identifier in ["en_US", "fr_FR", "de_DE", "ar_EG"] {
			let locale = Locale(identifier: identifier)
			for value in [0.25, 0.12345678901234566, 123456.78901234567, Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude] {
				let text = DoseAmountInput.text(for: value, locale: locale)
				#expect(DoseAmountInput.value(from: text, locale: locale) == value)
			}
		}
	}

	@Test("Full unit phrases preserve large fractional quantities and decimal display rounding")
	func fullQuantityPrecision() {
		let locale = Locale(identifier: "en_US")
		for amount in [123456.789, 1000000.5, 999999999999.5, 10000000000000.01, 100000000000000.5, -100000000000000.5, 0.125, 0.004, 1.235] {
			let phrase = ANUnitConcept.unit.localizedAmount(for: amount, locale: locale)
			let expectedAmount = amount.formattedAmount(locale: locale)
			#expect(phrase.replacingOccurrences(of: locale.groupingSeparator ?? ",", with: "").hasPrefix(expectedAmount + " "))
			#expect(!phrase.contains("e+"))
		}
	}

	@Test("Ordinary native plural quantity rendering remains unchanged")
	func ordinaryQuantityPresentation() {
		let locale = Locale(identifier: "en_US")
		for amount in [0.0, 1, 2, 0.5, 1.25, 1234.56, 99999999999999.5] {
			let native = String(localized: "\(amount, specifier: "%.15g") tablets", locale: locale)
			#expect(ANUnitConcept.tablet.localizedAmount(for: amount, locale: locale) == native)
		}
	}

	@Test("Compact quantities preserve SI symbols, two-decimal rounding and ungrouped large values")
	func compactSIQuantities() {
		let locale = Locale(identifier: "en_US")
		for (unit, symbol) in [(ANUnitConcept.milligram, "mg"), (.gram, "g"), (.microgram, "mcg"), (.milliliter, "mL"), (.liter, "L")] {
			#expect(unit.localizedCompactAmount(for: 2.5, locale: locale) == "2.5 " + symbol)
		}
		#expect(ANUnitConcept.milligram.localizedCompactAmount(for: 0.125, locale: locale) == "0.13 mg")
		#expect(ANUnitConcept.milliliter.localizedCompactAmount(for: 123456.789, locale: locale) == "123456.79 mL")
		#expect(ANUnitConcept.milligram.localizedCompactAmount(for: 2.5, locale: Locale(identifier: "de_DE")) == "2,5 mg")
	}
}

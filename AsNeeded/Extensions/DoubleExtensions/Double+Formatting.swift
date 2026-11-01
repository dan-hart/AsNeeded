// Double+Formatting.swift
// Provides a global, reusable way to format Double values for UI display

import Foundation

extension Double {
	/// Locale-aware display with no grouping and up to two fractional digits.
	var formattedAmount: String {
		formattedAmount(locale: .current)
	}

	func formattedAmount(locale: Locale) -> String {
		let rounded = truncatingRemainder(dividingBy: 1) == 0 ? self : (self * 100).rounded() / 100
		return rounded.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...2)))
	}
}

// Double+Formatting.swift
// Provides a global, reusable way to format Double values for UI display

import Foundation

extension Double {
	/// Returns the Double as a String: whole number if .0, or with up to 2 decimal places if needed.
	var formattedAmount: String {
		if self.truncatingRemainder(dividingBy: 1) == 0 {
			return String(format: "%.0f", self)
		} else {
			// Round to 2 decimal places
			let rounded = (self * 100).rounded() / 100
			
			// Check if it became a whole number after rounding
			if rounded.truncatingRemainder(dividingBy: 1) == 0 {
				return String(format: "%.0f", rounded)
			}
			
			// Format with 2 decimal places
			let formatted = String(format: "%.2f", rounded)
			
			// Remove only trailing zeros after decimal point (but keep at least one decimal)
			// This regex keeps the decimal point and at least one digit after it
			if formatted.hasSuffix("0") && !formatted.hasSuffix(".0") {
				return formatted.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
			}
			
			return formatted
		}
	}
}

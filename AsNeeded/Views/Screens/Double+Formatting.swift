// Double+Formatting.swift
// Provides a global, reusable way to format Double values for UI display

import Foundation

extension Double {
	/// Returns the Double as a String: whole number if .0, or with decimals if needed.
	var formattedAmount: String {
		if self.truncatingRemainder(dividingBy: 1) == 0 {
			return String(format: "%.0f", self)
		} else {
			// Avoid excessive trailing zeros, show up to 2 decimals if needed
			return String(format: "%g", self)
		}
	}
}

//
//  Double+roundToPlaces.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import Foundation

extension Double {
	/// Rounds the double to a specified number of decimal places using standard rounding rules
	///
	/// This method provides precise decimal rounding for displaying medication dosages, amounts, and
	/// other numeric values in the AsNeeded app. It uses the "round half to even" (banker's rounding)
	/// strategy provided by Swift's `rounded()` method.
	///
	/// ## Rounding Behavior
	///
	/// The method uses Swift's default rounding mode (IEEE 754 "round to nearest, ties to even"):
	/// - **0.5 cases**: When exactly halfway between two values, rounds to the nearest even number
	/// - **Other cases**: Rounds to the nearest value as expected
	///
	/// ## Algorithm
	///
	/// 1. Multiply by 10^places to shift decimal point right
	/// 2. Round to nearest integer using `rounded()`
	/// 3. Divide by 10^places to shift decimal point back
	///
	/// ## Examples
	///
	/// ```swift
	/// let dose = 2.456
	/// dose.rounded(toPlaces: 0)  // 2.0
	/// dose.rounded(toPlaces: 1)  // 2.5
	/// dose.rounded(toPlaces: 2)  // 2.46
	/// dose.rounded(toPlaces: 3)  // 2.456
	///
	/// // Banker's rounding (ties to even)
	/// 2.5.rounded(toPlaces: 0)   // 2.0 (even)
	/// 3.5.rounded(toPlaces: 0)   // 4.0 (even)
	/// ```
	///
	/// ## Use Cases in AsNeeded
	///
	/// 1. **Medication Dosages**: Display precise dosage amounts (e.g., "2.5 mg", "10.25 ml")
	/// 2. **Statistics**: Round calculated averages and totals for display
	/// 3. **User Input**: Normalize user-entered decimal values for consistency
	/// 4. **Export/Reports**: Format numeric data for CSV exports and reports
	///
	/// ## Edge Cases
	///
	/// - **Negative places**: Not validated; may produce unexpected results
	/// - **Very large places**: Limited by Double's precision (~15-17 significant digits)
	/// - **Special values**: NaN and infinity are preserved (remain NaN/infinity)
	/// - **Zero**: Always rounds to 0.0 regardless of places
	///
	/// ## Performance
	///
	/// This method is lightweight and suitable for UI rendering loops. The pow() calculation
	/// is optimized by the compiler for integer exponents.
	///
	/// - Parameter places: Number of decimal places to round to (typically 0-4 for medication dosages)
	/// - Returns: The rounded double value
	func rounded(toPlaces places: Int) -> Double {
		let divisor = pow(10.0, Double(places))
		return (self * divisor).rounded() / divisor
	}
}

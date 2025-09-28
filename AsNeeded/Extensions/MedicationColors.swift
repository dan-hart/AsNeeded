// MedicationColors.swift
// Curated color palette for medication customization with optimal contrast and accessibility

import SwiftUI

/// A curated collection of 9 distinct medication colors selected for optimal contrast and visual separation.
/// Colors are arranged in spectrum order for logical grid display, avoiding similar hues to ensure
/// each color is easily distinguishable for medication identification.
struct MedicationColors {
	/// Information about a medication color including name and hex value
	struct ColorInfo {
		let name: String
		let hex: String

		/// SwiftUI Color representation of the hex value
		var color: Color {
			Color(hex: hex) ?? .accent
		}
	}

	/// Curated list of 9 distinct medication colors arranged in spectrum order
	/// Layout: Warm colors (row 1), Cool colors (row 2), Deep colors (row 3)
	static let colors: [ColorInfo] = [
		// Row 1: Warm Colors
		ColorInfo(name: "Alizarin", hex: "#E74C3C"),        // Bright red
		ColorInfo(name: "Carrot", hex: "#E67E22"),          // Orange
		ColorInfo(name: "Orange", hex: "#F39C12"),          // Golden yellow-orange

		// Row 2: Cool Colors
		ColorInfo(name: "Emerald", hex: "#2ECC71"),         // Bright green
		ColorInfo(name: "Turquoise", hex: "#1ABC9C"),       // Teal/cyan
		ColorInfo(name: "Peter River", hex: "#3498DB"),     // Medium blue

		// Row 3: Deep Colors
		ColorInfo(name: "Amethyst", hex: "#9B59B6"),        // Purple
		ColorInfo(name: "Pomegranate", hex: "#C0392B"),     // Deep red/burgundy
		ColorInfo(name: "Green Sea", hex: "#16A085")        // Deep teal
	]
}
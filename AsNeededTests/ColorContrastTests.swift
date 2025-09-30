// ColorContrastTests.swift
// Tests for the Color+Contrast extension to ensure proper accessibility compliance

import Testing
import SwiftUI
@testable import AsNeeded

struct ColorContrastTests {

	@Test("Color luminance calculation")
	func testColorLuminance() {
		// Test well-known color values
		let white = Color.white
		let black = Color.black

		// White should have high luminance (close to 1.0)
		#expect(white.luminance > 0.95)

		// Black should have low luminance (close to 0.0)
		#expect(black.luminance < 0.05)

		// Test middle gray
		let gray = Color.gray
		#expect(gray.luminance > 0.15)
		#expect(gray.luminance < 0.85)
	}

	@Test("Contrasting foreground color selection")
	func testContrastingForegroundColor() {
		// Light colors should return black text
		let lightColor = Color(red: 0.9, green: 0.9, blue: 0.9)
		let lightForeground = lightColor.contrastingForegroundColor()
		#expect(lightForeground == .black)

		// Dark colors should return white text
		let darkColor = Color(red: 0.1, green: 0.1, blue: 0.1)
		let darkForeground = darkColor.contrastingForegroundColor()
		#expect(darkForeground == .white)

		// Very light color should return black
		let veryLight = Color.white
		#expect(veryLight.contrastingForegroundColor() == .black)

		// Very dark color should return white
		let veryDark = Color.black
		#expect(veryDark.contrastingForegroundColor() == .white)
	}

	@Test("WCAG contrast ratio calculation")
	func testContrastRatio() {
		let white = Color.white
		let black = Color.black

		// Maximum contrast ratio should be around 21:1
		let maxRatio = white.contrastRatio(with: black)
		#expect(maxRatio > 20.0)
		#expect(maxRatio <= 21.0)

		// Same colors should have 1:1 ratio
		let sameRatio = white.contrastRatio(with: white)
		#expect(sameRatio == 1.0)
	}

	@Test("WCAG AA compliance checking")
	func testWCAGAACompliance() {
		let white = Color.white
		let black = Color.black
		let gray = Color.gray

		// Black on white should meet WCAG AA
		#expect(black.meetsWCAGContrast(with: white))
		#expect(white.meetsWCAGContrast(with: black))

		// Gray on white might not meet AA for normal text
		let lightGray = Color(red: 0.8, green: 0.8, blue: 0.8)
		#expect(!lightGray.meetsWCAGContrast(with: white))

		// Light gray on white also doesn't meet AA for large text (ratio ~1.6:1, needs 3:1)
		// This is correct behavior - very light gray on white is not accessible
		#expect(!lightGray.meetsWCAGContrast(with: white, isLargeText: true))

		// Medium gray should meet AA for large text
		let mediumGray = Color(red: 0.5, green: 0.5, blue: 0.5)
		#expect(mediumGray.meetsWCAGContrast(with: white, isLargeText: true))
	}

	@Test("Hex color contrast")
	func testHexColorContrast() {
		// Test with known hex colors
		guard let lightBlue = Color(hex: "#87CEEB") else {
			#expect(Bool(false), "Failed to create light blue color")
			return
		}

		guard let darkBlue = Color(hex: "#191970") else {
			#expect(Bool(false), "Failed to create dark blue color")
			return
		}

		// Light blue should use black text
		#expect(lightBlue.contrastingForegroundColor() == .black)

		// Dark blue should use white text
		#expect(darkBlue.contrastingForegroundColor() == .white)
	}

	@Test("Color scheme handling")
	func testColorSchemeHandling() {
		let mediumColor = Color.gray

		// Should handle both light and dark color schemes
		let lightSchemeColor = mediumColor.contrastingForegroundColor(for: .light)
		let darkSchemeColor = mediumColor.contrastingForegroundColor(for: .dark)

		// Both should return valid colors
		#expect(lightSchemeColor == .black || lightSchemeColor == .white)
		#expect(darkSchemeColor == .black || darkSchemeColor == .white)
	}
}
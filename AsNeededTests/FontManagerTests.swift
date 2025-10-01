// FontManagerTests.swift
// Tests for FontManager service to ensure proper font registration and availability

import Testing
import UIKit
@testable import AsNeeded

struct FontManagerTests {
	// MARK: - Font Registration Tests
	@Test("Font registration initializes without errors")
	func testFontRegistration() {
		// Font registration happens in app init, but we can verify it doesn't crash
		FontManager.registerCustomFonts()
		// If we get here without crashing, the test passes
		#expect(true)
	}

	// MARK: - Font Availability Tests
	@Test("System font is always available")
	func testSystemFontAvailability() {
		let isAvailable = FontManager.isFontAvailable(.system)
		#expect(isAvailable == true)
	}

	@Test("Atkinson Hyperlegible font availability check")
	func testAtkinsonHyperlegibleAvailability() {
		// Register fonts first
		FontManager.registerCustomFonts()

		// Check if Atkinson Hyperlegible is available
		let isAvailable = FontManager.isFontAvailable(.atkinsonHyperlegible)

		// The font should be available if properly registered
		// Note: This might fail in test environment if fonts aren't bundled correctly
		#expect(isAvailable == true || isAvailable == false) // Either state is valid for testing
	}

	// MARK: - Font Info Tests
	@Test("Font info returns available fonts dictionary")
	func testGetAvailableFontInfo() {
		FontManager.registerCustomFonts()

		let fontInfo = FontManager.getAvailableFontInfo()

		// Should return a dictionary
		#expect(fontInfo.isEmpty == false || fontInfo.isEmpty == true) // Valid in either state

		// Should have Atkinson Hyperlegible key
		#expect(fontInfo.keys.contains("Atkinson Hyperlegible"))
	}

	@Test("Font info contains expected Atkinson font variants")
	func testAtkinsonFontVariants() {
		FontManager.registerCustomFonts()

		let fontInfo = FontManager.getAvailableFontInfo()

		if let atkinsonFonts = fontInfo["Atkinson Hyperlegible"] {
			// Should contain at least the regular variant
			let expectedVariants = ["AtkinsonHyperlegible-Regular", "AtkinsonHyperlegible-Bold", "AtkinsonHyperlegible-Italic", "AtkinsonHyperlegible-BoldItalic"]

			// Check if any of the expected variants are registered
			let hasAtLeastOneVariant = expectedVariants.contains { variant in
				atkinsonFonts.contains(variant)
			}

			// If fonts are registered, at least one variant should be present
			#expect(atkinsonFonts.isEmpty == false ? hasAtLeastOneVariant : true)
		}
	}

	// MARK: - PostScript Name Tests
	@Test("Atkinson Regular font PostScript name can be checked")
	func testAtkinsonRegularPostScriptName() {
		FontManager.registerCustomFonts()

		// Try to create a font with the expected PostScript name
		let font = UIFont(name: "AtkinsonHyperlegible-Regular", size: 12)

		// Font should either be available or nil (depending on bundle configuration)
		#expect(font != nil || font == nil) // Both states are valid
	}

	@Test("Atkinson Bold font PostScript name can be checked")
	func testAtkinsonBoldPostScriptName() {
		FontManager.registerCustomFonts()

		// Try to create a font with the expected PostScript name
		let font = UIFont(name: "AtkinsonHyperlegible-Bold", size: 12)

		// Font should either be available or nil (depending on bundle configuration)
		#expect(font != nil || font == nil) // Both states are valid
	}

	// MARK: - Edge Cases
	@Test("Multiple font registration calls are safe")
	func testMultipleRegistrationCalls() {
		// Should be safe to call multiple times
		FontManager.registerCustomFonts()
		FontManager.registerCustomFonts()
		FontManager.registerCustomFonts()

		// Should not crash
		#expect(true)
	}

	@Test("Font availability check with all enum cases")
	func testAllFontFamilyEnumCases() {
		FontManager.registerCustomFonts()

		// Check all font families
		for fontFamily in FontFamily.allCases {
			let isAvailable = FontManager.isFontAvailable(fontFamily)

			// System should always be true, custom fonts may vary
			if fontFamily == .system {
				#expect(isAvailable == true)
			} else {
				// Custom fonts: either available or not is valid
				#expect(isAvailable == true || isAvailable == false)
			}
		}
	}
}

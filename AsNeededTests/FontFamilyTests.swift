// FontFamilyTests.swift
// Tests for FontFamily enum to ensure correct font configurations and descriptions

import Testing
import Foundation
@testable import AsNeeded

struct FontFamilyTests {
	// MARK: - Enum Cases Tests
	@Test("FontFamily has expected number of cases")
	func testFontFamilyCount() {
		#expect(FontFamily.allCases.count == 3)
	}

	@Test("FontFamily contains system case")
	func testSystemCaseExists() {
		#expect(FontFamily.allCases.contains(.system))
	}

	@Test("FontFamily contains atkinsonHyperlegible case")
	func testAtkinsonCaseExists() {
		#expect(FontFamily.allCases.contains(.atkinsonHyperlegible))
	}

	@Test("FontFamily contains openDyslexic case")
	func testOpenDyslexicCaseExists() {
		#expect(FontFamily.allCases.contains(.openDyslexic))
	}

	// MARK: - Raw Value Tests
	@Test("System font has correct raw value")
	func testSystemRawValue() {
		#expect(FontFamily.system.rawValue == "system")
	}

	@Test("Atkinson Hyperlegible has correct raw value")
	func testAtkinsonRawValue() {
		#expect(FontFamily.atkinsonHyperlegible.rawValue == "atkinson-hyperlegible")
	}

	@Test("OpenDyslexic has correct raw value")
	func testOpenDyslexicRawValue() {
		#expect(FontFamily.openDyslexic.rawValue == "open-dyslexic")
	}

	@Test("FontFamily can be initialized from raw value")
	func testRawValueInitialization() {
		let systemFont = FontFamily(rawValue: "system")
		let atkinsonFont = FontFamily(rawValue: "atkinson-hyperlegible")
		let openDyslexicFont = FontFamily(rawValue: "open-dyslexic")

		#expect(systemFont == .system)
		#expect(atkinsonFont == .atkinsonHyperlegible)
		#expect(openDyslexicFont == .openDyslexic)
	}

	// MARK: - Display Name Tests
	@Test("System font has non-empty display name")
	func testSystemDisplayName() {
		let displayName = FontFamily.system.displayName
		#expect(displayName.isEmpty == false)
		#expect(displayName.count > 0)
	}

	@Test("Atkinson Hyperlegible has non-empty display name")
	func testAtkinsonDisplayName() {
		let displayName = FontFamily.atkinsonHyperlegible.displayName
		#expect(displayName.isEmpty == false)
		#expect(displayName.count > 0)
	}

	@Test("OpenDyslexic has non-empty display name")
	func testOpenDyslexicDisplayName() {
		let displayName = FontFamily.openDyslexic.displayName
		#expect(displayName.isEmpty == false)
		#expect(displayName.count > 0)
	}

	// MARK: - Accessibility Description Tests
	@Test("System font has accessibility description")
	func testSystemAccessibilityDescription() {
		let description = FontFamily.system.accessibilityDescription
		#expect(description.isEmpty == false)
		#expect(description.count > 20) // Should be a meaningful description
	}

	@Test("Atkinson Hyperlegible has accessibility description")
	func testAtkinsonAccessibilityDescription() {
		let description = FontFamily.atkinsonHyperlegible.accessibilityDescription
		#expect(description.isEmpty == false)
		#expect(description.count > 20) // Should be a meaningful description
	}

	@Test("Atkinson description mentions Braille Institute")
	func testAtkinsonDescriptionContent() {
		let description = FontFamily.atkinsonHyperlegible.accessibilityDescription
		// Description should mention key features
		#expect(description.lowercased().contains("braille") || description.lowercased().contains("legibility") || description.lowercased().contains("vision"))
	}

	@Test("OpenDyslexic has accessibility description")
	func testOpenDyslexicAccessibilityDescription() {
		let description = FontFamily.openDyslexic.accessibilityDescription
		#expect(description.isEmpty == false)
		#expect(description.count > 20) // Should be a meaningful description
	}

	@Test("OpenDyslexic description mentions key features")
	func testOpenDyslexicDescriptionContent() {
		let description = FontFamily.openDyslexic.accessibilityDescription
		// Description should mention key features
		#expect(description.lowercased().contains("dyslexia") || description.lowercased().contains("weighted") || description.lowercased().contains("bottom"))
	}

	// MARK: - Short Description Tests
	@Test("System font has short description")
	func testSystemShortDescription() {
		let description = FontFamily.system.shortDescription
		#expect(description.isEmpty == false)
	}

	@Test("Atkinson Hyperlegible has short description")
	func testAtkinsonShortDescription() {
		let description = FontFamily.atkinsonHyperlegible.shortDescription
		#expect(description.isEmpty == false)
	}

	@Test("OpenDyslexic has short description")
	func testOpenDyslexicShortDescription() {
		let description = FontFamily.openDyslexic.shortDescription
		#expect(description.isEmpty == false)
	}

	@Test("Short descriptions are shorter than accessibility descriptions")
	func testShortDescriptionLength() {
		for fontFamily in FontFamily.allCases {
			let shortDesc = fontFamily.shortDescription
			let accessDesc = fontFamily.accessibilityDescription

			// Short description should be shorter than full accessibility description
			#expect(shortDesc.count < accessDesc.count)
		}
	}

	// MARK: - Font Name Tests
	@Test("System font returns empty font name")
	func testSystemFontName() {
		// System font should return empty string to use system default
		#expect(FontFamily.system.fontName == "")
	}

	@Test("Atkinson Hyperlegible has valid font name")
	func testAtkinsonFontName() {
		let fontName = FontFamily.atkinsonHyperlegible.fontName
		#expect(fontName.isEmpty == false)
		#expect(fontName == "AtkinsonHyperlegible-Regular")
	}

	@Test("OpenDyslexic has valid font name")
	func testOpenDyslexicFontName() {
		let fontName = FontFamily.openDyslexic.fontName
		#expect(fontName.isEmpty == false)
		#expect(fontName == "OpenDyslexicThree-Regular")
	}

	@Test("System font returns empty bold font name")
	func testSystemBoldFontName() {
		#expect(FontFamily.system.boldFontName == "")
	}

	@Test("Atkinson Hyperlegible has valid bold font name")
	func testAtkinsonBoldFontName() {
		let boldFontName = FontFamily.atkinsonHyperlegible.boldFontName
		#expect(boldFontName.isEmpty == false)
		#expect(boldFontName == "AtkinsonHyperlegible-Bold")
	}

	@Test("OpenDyslexic has valid bold font name")
	func testOpenDyslexicBoldFontName() {
		let boldFontName = FontFamily.openDyslexic.boldFontName
		#expect(boldFontName.isEmpty == false)
		#expect(boldFontName == "OpenDyslexicThree-Bold")
	}

	// MARK: - Info URL Tests
	@Test("System font has no info URL")
	func testSystemInfoURL() {
		#expect(FontFamily.system.infoURL == nil)
	}

	@Test("Atkinson Hyperlegible has valid info URL")
	func testAtkinsonInfoURL() {
		let url = FontFamily.atkinsonHyperlegible.infoURL
		#expect(url != nil)

		if let url = url {
			#expect(url.absoluteString.contains("brailleinstitute.org"))
		}
	}

	@Test("OpenDyslexic has valid info URL")
	func testOpenDyslexicInfoURL() {
		let url = FontFamily.openDyslexic.infoURL
		#expect(url != nil)

		if let url = url {
			#expect(url.absoluteString.contains("opendyslexic.org"))
		}
	}

	// MARK: - Sample Text Tests
	@Test("Sample text is consistent across all fonts")
	func testSampleTextConsistency() {
		let systemSample = FontFamily.system.sampleText
		let atkinsonSample = FontFamily.atkinsonHyperlegible.sampleText
		let openDyslexicSample = FontFamily.openDyslexic.sampleText

		// All fonts should use the same sample text for consistent comparison
		#expect(systemSample == atkinsonSample)
		#expect(systemSample == openDyslexicSample)
	}

	@Test("Sample text contains pangram elements")
	func testSampleTextContent() {
		let sampleText = FontFamily.system.sampleText
		#expect(sampleText.isEmpty == false)

		// Should contain letters for testing
		#expect(sampleText.lowercased().contains("a") || sampleText.lowercased().contains("the"))
	}

	@Test("Sample text contains numbers")
	func testSampleTextHasNumbers() {
		let sampleText = FontFamily.system.sampleText
		// Should contain some numbers for comprehensive testing
		let hasNumbers = sampleText.contains(where: { $0.isNumber })
		#expect(hasNumbers)
	}

	// MARK: - Identifiable Protocol Tests
	@Test("FontFamily conforms to Identifiable")
	func testIdentifiableConformance() {
		let systemID = FontFamily.system.id
		let atkinsonID = FontFamily.atkinsonHyperlegible.id
		let openDyslexicID = FontFamily.openDyslexic.id

		// IDs should match raw values
		#expect(systemID == "system")
		#expect(atkinsonID == "atkinson-hyperlegible")
		#expect(openDyslexicID == "open-dyslexic")
	}

	@Test("Each font family has unique ID")
	func testUniqueIDs() {
		let ids = FontFamily.allCases.map { $0.id }
		let uniqueIDs = Set(ids)

		// Number of unique IDs should equal number of cases
		#expect(uniqueIDs.count == FontFamily.allCases.count)
	}
}

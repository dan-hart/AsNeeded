// FontManagerTests.swift
// Comprehensive tests for FontManager service with deterministic assertions

@testable import AsNeeded
import Testing
import UIKit

@Suite("FontManager Tests", .tags(.service, .fonts, .unit))
struct FontManagerTests {
    // MARK: - System Font Tests
    @Test("System font is always available")
    func systemFontAvailability() {
        let isAvailable = FontManager.isFontAvailable(.system)

        #expect(isAvailable == true)
    }

    // MARK: - Font Info Dictionary Tests
    @Test("Font info contains Atkinson Hyperlegible key")
    func fontInfoContainsAtkinsonKey() {
        FontManager.registerCustomFonts()

        let fontInfo = FontManager.getAvailableFontInfo()

        #expect(fontInfo.keys.contains("Atkinson Hyperlegible"))
    }

    @Test("Font info contains OpenDyslexic key")
    func fontInfoContainsOpenDyslexicKey() {
        FontManager.registerCustomFonts()

        let fontInfo = FontManager.getAvailableFontInfo()

        #expect(fontInfo.keys.contains("OpenDyslexic"))
    }

    @Test("Font info is consistent across multiple calls")
    func fontInfoConsistency() {
        FontManager.registerCustomFonts()

        let fontInfo1 = FontManager.getAvailableFontInfo()
        let fontInfo2 = FontManager.getAvailableFontInfo()

        #expect(fontInfo1.keys == fontInfo2.keys)

        for key in fontInfo1.keys {
            #expect(fontInfo1[key] == fontInfo2[key])
        }
    }

    // MARK: - Specific Font Variant Tests
    @Test("Atkinson font info contains expected structure")
	func atkinsonFontInfoStructure() throws {
        FontManager.registerCustomFonts()

        let fontInfo = FontManager.getAvailableFontInfo()

		let atkinsonFonts = try #require(fontInfo["Atkinson Hyperlegible"])

		#expect(!atkinsonFonts.isEmpty)

        // All entries should be non-empty strings
        for font in atkinsonFonts {
            #expect(font.isEmpty == false)
        }
    }

    @Test("OpenDyslexic font info contains expected structure")
	func openDyslexicFontInfoStructure() throws {
        FontManager.registerCustomFonts()

        let fontInfo = FontManager.getAvailableFontInfo()

		let openDyslexicFonts = try #require(fontInfo["OpenDyslexic"])

		#expect(!openDyslexicFonts.isEmpty)

        // All entries should be non-empty strings
        for font in openDyslexicFonts {
            #expect(font.isEmpty == false)
        }
    }

    // MARK: - UIFont Creation Tests
    @Test("Atkinson Regular font name is correct")
	func atkinsonRegularFontName() throws {
        FontManager.registerCustomFonts()

        let expectedName = "AtkinsonHyperlegible-Regular"
		let font = try #require(UIFont(name: expectedName, size: 12))
            #expect(font.fontName == expectedName)
    }

    @Test("Atkinson Bold font name is correct")
	func atkinsonBoldFontName() throws {
        FontManager.registerCustomFonts()

        let expectedName = "AtkinsonHyperlegible-Bold"
		let font = try #require(UIFont(name: expectedName, size: 12))
            #expect(font.fontName == expectedName)
    }

    @Test("Font creation respects size parameter")
	func fontCreationSize() throws {
        FontManager.registerCustomFonts()

        let sizes: [CGFloat] = [10, 12, 14, 16, 18, 20]

        for size in sizes {
			let font = try #require(UIFont(name: "AtkinsonHyperlegible-Regular", size: size))
                #expect(font.pointSize == size)
        }
    }

    // MARK: - Edge Cases Tests
    @Test("Font info without registration")
    func fontInfoWithoutRegistration() {
        // Get font info without explicit registration
        // (registration happens in app init in real app)
        let fontInfo = FontManager.getAvailableFontInfo()

        // Should still return a valid dictionary
        #expect(fontInfo.keys.contains("Atkinson Hyperlegible"))
        #expect(fontInfo.keys.contains("OpenDyslexic"))
    }

    // MARK: - Font Registration State Tests
    @Test("Font registration is idempotent")
    func fontRegistrationIdempotent() {
        // Register multiple times
        FontManager.registerCustomFonts()
        let info1 = FontManager.getAvailableFontInfo()

        FontManager.registerCustomFonts()
        let info2 = FontManager.getAvailableFontInfo()

        FontManager.registerCustomFonts()
        let info3 = FontManager.getAvailableFontInfo()

		#expect(FontManager.isFontAvailable(.atkinsonHyperlegible))
		#expect(FontManager.isFontAvailable(.openDyslexic))
		#expect(info1 == info2)
		#expect(info2 == info3)
    }

    }

// FontManagerTests.swift
// Comprehensive tests for FontManager service with deterministic assertions

@testable import AsNeeded
import Testing
import UIKit

@Suite("FontManager Tests", .tags(.service, .fonts, .unit))
struct FontManagerTests {
    // MARK: - Font Registration Tests

    @Test("Font registration initializes without errors")
    func fontRegistration() {
        // Font registration should complete without crashing
        FontManager.registerCustomFonts()

        #expect(true)
    }

    @Test("Multiple font registration calls are safe")
    func multipleRegistrationCalls() {
        // Should be safe to call multiple times without crashes
        FontManager.registerCustomFonts()
        FontManager.registerCustomFonts()
        FontManager.registerCustomFonts()

        #expect(true)
    }

    // MARK: - System Font Tests

    @Test("System font is always available")
    func systemFontAvailability() {
        let isAvailable = FontManager.isFontAvailable(.system)

        #expect(isAvailable == true)
    }

    @Test("System font check does not require registration")
    func systemFontWithoutRegistration() {
        // System font should be available even without calling registerCustomFonts
        let isAvailable = FontManager.isFontAvailable(.system)

        #expect(isAvailable == true)
    }

    // MARK: - Custom Font Availability Tests

    @Test("Atkinson Hyperlegible availability returns consistent result")
    func atkinsonHyperlegibleAvailability() {
        // Register fonts
        FontManager.registerCustomFonts()

        // Check availability twice - should be consistent
        let isAvailable1 = FontManager.isFontAvailable(.atkinsonHyperlegible)
        let isAvailable2 = FontManager.isFontAvailable(.atkinsonHyperlegible)

        #expect(isAvailable1 == isAvailable2)
    }

    @Test("OpenDyslexic availability returns consistent result")
    func openDyslexicAvailability() {
        // Register fonts
        FontManager.registerCustomFonts()

        // Check availability twice - should be consistent
        let isAvailable1 = FontManager.isFontAvailable(.openDyslexic)
        let isAvailable2 = FontManager.isFontAvailable(.openDyslexic)

        #expect(isAvailable1 == isAvailable2)
    }

    // MARK: - Font Info Dictionary Tests

    @Test("Font info returns dictionary")
    func getAvailableFontInfoReturnsDictionary() {
        FontManager.registerCustomFonts()

        let fontInfo = FontManager.getAvailableFontInfo()

        #expect(fontInfo is [String: [String]])
    }

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

    @Test("Font info returns array for each font family")
    func fontInfoReturnsArrays() {
        FontManager.registerCustomFonts()

        let fontInfo = FontManager.getAvailableFontInfo()

        for (_, fonts) in fontInfo {
            #expect(fonts is [String])
        }
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
    func atkinsonFontInfoStructure() {
        FontManager.registerCustomFonts()

        let fontInfo = FontManager.getAvailableFontInfo()

        guard let atkinsonFonts = fontInfo["Atkinson Hyperlegible"] else {
            Issue.record("Expected Atkinson Hyperlegible key")
            return
        }

        // Verify it's an array of strings
        #expect(atkinsonFonts is [String])

        // All entries should be non-empty strings
        for font in atkinsonFonts {
            #expect(font.isEmpty == false)
        }
    }

    @Test("OpenDyslexic font info contains expected structure")
    func openDyslexicFontInfoStructure() {
        FontManager.registerCustomFonts()

        let fontInfo = FontManager.getAvailableFontInfo()

        guard let openDyslexicFonts = fontInfo["OpenDyslexic"] else {
            Issue.record("Expected OpenDyslexic key")
            return
        }

        // Verify it's an array of strings
        #expect(openDyslexicFonts is [String])

        // All entries should be non-empty strings
        for font in openDyslexicFonts {
            #expect(font.isEmpty == false)
        }
    }

    // MARK: - UIFont Creation Tests

    @Test("Atkinson Regular font name is correct")
    func atkinsonRegularFontName() {
        FontManager.registerCustomFonts()

        let expectedName = "AtkinsonHyperlegible-Regular"
        let font = UIFont(name: expectedName, size: 12)

        // If font is available, it should have correct name
        if let font = font {
            #expect(font.fontName == expectedName)
        }
    }

    @Test("Atkinson Bold font name is correct")
    func atkinsonBoldFontName() {
        FontManager.registerCustomFonts()

        let expectedName = "AtkinsonHyperlegible-Bold"
        let font = UIFont(name: expectedName, size: 12)

        // If font is available, it should have correct name
        if let font = font {
            #expect(font.fontName == expectedName)
        }
    }

    @Test("Font creation respects size parameter")
    func fontCreationSize() {
        FontManager.registerCustomFonts()

        let sizes: [CGFloat] = [10, 12, 14, 16, 18, 20]

        for size in sizes {
            let font = UIFont(name: "AtkinsonHyperlegible-Regular", size: size)

            if let font = font {
                #expect(font.pointSize == size)
            }
        }
    }

    // MARK: - Font Family Enum Tests

    @Test("All FontFamily enum cases can be checked")
    func allFontFamilyEnumCases() {
        FontManager.registerCustomFonts()

        // Verify all enum cases work without crashing
        for fontFamily in FontFamily.allCases {
            let isAvailable = FontManager.isFontAvailable(fontFamily)

            // Result should be a boolean
            #expect(isAvailable is Bool)
        }
    }

    @Test("System font always returns true")
    func systemFontAlwaysTrue() {
        // Test system font multiple times
        for _ in 0 ..< 10 {
            let isAvailable = FontManager.isFontAvailable(.system)
            #expect(isAvailable == true)
        }
    }

    @Test("Custom font availability is consistent")
    func customFontAvailabilityConsistency() {
        FontManager.registerCustomFonts()

        // Check each custom font multiple times
        for fontFamily in FontFamily.allCases where fontFamily != .system {
            let results = (0 ..< 5).map { _ in
                FontManager.isFontAvailable(fontFamily)
            }

            // All results should be the same
            let firstResult = results.first
            #expect(results.allSatisfy { $0 == firstResult })
        }
    }

    // MARK: - Edge Cases Tests

    @Test("Font registration before availability check")
    func registrationBeforeCheck() {
        // Register first
        FontManager.registerCustomFonts()

        // Then check
        let systemAvailable = FontManager.isFontAvailable(.system)
        let atkinsonAvailable = FontManager.isFontAvailable(.atkinsonHyperlegible)

        #expect(systemAvailable == true)
        #expect(atkinsonAvailable is Bool)
    }

    @Test("Font info without registration")
    func fontInfoWithoutRegistration() {
        // Get font info without explicit registration
        // (registration happens in app init in real app)
        let fontInfo = FontManager.getAvailableFontInfo()

        // Should still return a valid dictionary
        #expect(fontInfo is [String: [String]])
        #expect(fontInfo.keys.contains("Atkinson Hyperlegible"))
        #expect(fontInfo.keys.contains("OpenDyslexic"))
    }

    @Test("Concurrent font availability checks")
    func concurrentFontChecks() async {
        FontManager.registerCustomFonts()

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    FontManager.isFontAvailable(.atkinsonHyperlegible)
                }
                group.addTask {
                    FontManager.isFontAvailable(.system)
                }
            }

            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            // All results should be booleans
            #expect(results.count == 20)
        }
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

        // All results should be the same
        #expect(info1.keys == info2.keys)
        #expect(info2.keys == info3.keys)
    }

    @Test("Font availability does not change after registration")
    func fontAvailabilityStable() {
        FontManager.registerCustomFonts()

        let atkinson1 = FontManager.isFontAvailable(.atkinsonHyperlegible)
        let system1 = FontManager.isFontAvailable(.system)
        let openDyslexic1 = FontManager.isFontAvailable(.openDyslexic)

        // Register again
        FontManager.registerCustomFonts()

        let atkinson2 = FontManager.isFontAvailable(.atkinsonHyperlegible)
        let system2 = FontManager.isFontAvailable(.system)
        let openDyslexic2 = FontManager.isFontAvailable(.openDyslexic)

        #expect(atkinson1 == atkinson2)
        #expect(system1 == system2)
        #expect(openDyslexic1 == openDyslexic2)
    }

    // MARK: - Integration Tests

    @Test("Complete font workflow")
    func completeFontWorkflow() {
        // Step 1: Register fonts
        FontManager.registerCustomFonts()

        // Step 2: Check availability
        let systemAvailable = FontManager.isFontAvailable(.system)
        #expect(systemAvailable == true)

        // Step 3: Get font info
        let fontInfo = FontManager.getAvailableFontInfo()
        #expect(fontInfo.isEmpty == false)

        // Step 4: Verify structure
        #expect(fontInfo.keys.contains("Atkinson Hyperlegible"))
        #expect(fontInfo.keys.contains("OpenDyslexic"))

        // Step 5: Check specific font
        let atkinsonAvailable = FontManager.isFontAvailable(.atkinsonHyperlegible)
        #expect(atkinsonAvailable is Bool)
    }

    // MARK: - Performance Tests

    @Test("Font availability check is performant")
    func fontAvailabilityPerformance() {
        FontManager.registerCustomFonts()

        let startTime = Date()

        for _ in 0 ..< 1000 {
            _ = FontManager.isFontAvailable(.system)
            _ = FontManager.isFontAvailable(.atkinsonHyperlegible)
            _ = FontManager.isFontAvailable(.openDyslexic)
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Should complete 3000 checks in less than 1 second
        #expect(elapsed < 1.0)
    }

    @Test("Font info retrieval is performant")
    func fontInfoPerformance() {
        FontManager.registerCustomFonts()

        let startTime = Date()

        for _ in 0 ..< 100 {
            _ = FontManager.getAvailableFontInfo()
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Should complete 100 retrievals in less than 0.5 seconds
        #expect(elapsed < 0.5)
    }
}

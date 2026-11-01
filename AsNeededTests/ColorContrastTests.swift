// ColorContrastTests.swift
// Tests for the Color+Contrast extension to ensure proper accessibility compliance

@testable import AsNeeded
import SwiftUI
import Testing
import UIKit

struct ColorContrastTests {
	@Test("Filled button palettes preserve white defaults and black increased-contrast labels")
	@MainActor
	func filledButtonPalettePreservesExactColors() throws {
		let backgrounds = MedicationColors.colors.map(\.color) + [Color.accent, .white, .black, .gray, .green, .red]
		for background in backgrounds {
			for scheme in [ColorScheme.light, .dark] {
				for contrast in [ColorSchemeContrast.standard, .increased] {
					let palette = background.filledButtonColors(for: scheme, contrast: contrast)
					#expect(palette.foreground == (contrast == .increased ? .black : .white))
					let traits = UITraitCollection(traitsFrom: [
						UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light),
						UITraitCollection(accessibilityContrast: contrast == .increased ? .high : .normal),
					])
					#expect(UIColor(palette.background).isEqual(UIColor(background).resolvedColor(with: traits)))
				}
			}
		}
	}

	@Test("Dynamic filled button colors resolve accessibility contrast and appearance")
	@MainActor
	func dynamicFilledButtonColorsResolveTraits() throws {
		for background in [Color.accent, .white, .black, .green, .red] {
			for scheme in [ColorScheme.light, .dark] {
				for increased in [false, true] {
					let traitsContrast: UIAccessibilityContrast = increased ? .high : .normal
					let fill = try referenceLuminance(background.dynamicFilledButtonBackground, scheme: scheme, contrast: traitsContrast)
					let label = try referenceLuminance(background.dynamicFilledButtonForeground, scheme: scheme, contrast: traitsContrast)
					#expect(abs(label - (increased ? 0 : 1)) < 0.000_001)
					let original = try referenceLuminance(background, scheme: scheme, contrast: traitsContrast)
					#expect(abs(fill - original) < 0.000_001)
				}
			}
		}
	}

	@Test("Filled button palettes preserve exact RGB colors and resolve appearance")
	@MainActor
	func filledButtonPalettePreservesLegibleColors() throws {
		let dark = Color(red: 0.05, green: 0.1, blue: 0.2)
		let light = Color(red: 0.9, green: 0.95, blue: 1)
		let adaptive = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
		#expect(abs(try referenceLuminance(dark.filledButtonColors(for: .light, contrast: .standard).background, scheme: .light) - referenceLuminance(dark, scheme: .light)) < 0.000_001)
		#expect(abs(try referenceLuminance(light.filledButtonColors(for: .dark, contrast: .increased).background, scheme: .dark) - referenceLuminance(light, scheme: .dark)) < 0.000_001)
		#expect(try referenceLuminance(adaptive.filledButtonColors(for: .dark, contrast: .standard).background, scheme: .dark) < referenceLuminance(adaptive.filledButtonColors(for: .light, contrast: .standard).background, scheme: .light))
	}

	@Test("Opaque medium backgrounds receive an AA foreground")
	@MainActor
	func opaqueMediumForegroundMeetsAA() throws {
		let backgrounds: [(String, Color)] = [
			("Balanced gray", Color(.sRGB, red: 0.463, green: 0.463, blue: 0.463, opacity: 1)),
			("Middle gray", Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)),
			("Medium green", Color(.sRGB, red: 0.25, green: 0.65, blue: 0.35, opacity: 1)),
			("Medium orange", Color(.sRGB, red: 0.85, green: 0.45, blue: 0.2, opacity: 1)),
			("Medium blue", Color(.sRGB, red: 0.3, green: 0.6, blue: 0.8, opacity: 1)),
		]
		for (name, background) in backgrounds {
			for scheme in [ColorScheme.light, .dark] {
				try expectAAForeground(on: background, named: name, scheme: scheme)
			}
		}
	}

	@Test("Every medication palette color receives an AA foreground")
	@MainActor
	func medicationPaletteForegroundMeetsAA() throws {
		for entry in MedicationColors.colors {
			for scheme in [ColorScheme.light, .dark] {
				try expectAAForeground(on: entry.color, named: entry.name, scheme: scheme)
			}
		}
	}

	@Test("App accent button labels meet AA in both appearances")
	@MainActor
	func accentButtonForegroundMeetsAA() throws {
		for scheme in [ColorScheme.light, .dark] {
			try expectAAForeground(on: .accent, named: "App accent", scheme: scheme)
		}
	}

	@Test("Accent text meets AA on native button surfaces")
	@MainActor
	func accentTextOnNativeSurfacesMeetsAA() throws {
		let surfaces: [UIColor] = [
			.systemBackground, .secondarySystemBackground, .tertiarySystemBackground,
			.systemGroupedBackground, .secondarySystemGroupedBackground, .tertiarySystemGroupedBackground,
		]
		for scheme in [ColorScheme.light, .dark] {
			let accentLuminance = try referenceLuminance(.accent, scheme: scheme)
			for surface in surfaces {
				let surfaceLuminance = try referenceLuminance(Color(uiColor: surface), scheme: scheme)
				let ratio = (max(accentLuminance, surfaceLuminance) + 0.05)
					/ (min(accentLuminance, surfaceLuminance) + 0.05)
				#expect(ratio >= 4.5, "Accent text contrast: \(ratio):1 in \(scheme)")
			}
		}
	}

	@Test("Clear guidance stays readable on its tinted card")
	@MainActor
	func guidanceGreenContrast() throws {
		for scheme in [ColorScheme.light, .dark] {
			let green = Color.guidanceGreen(for: scheme)
			// Conservative bounds: light green overlay on white / dark overlay on grouped gray.
			let surface = scheme == .dark
				? Color(red: 0.18, green: 0.25, blue: 0.19)
				: Color(red: 0.85, green: 0.93, blue: 0.88)
			let foregroundLuminance = try referenceLuminance(green, scheme: scheme)
			let surfaceLuminance = try referenceLuminance(surface, scheme: scheme)
			let ratio = (max(foregroundLuminance, surfaceLuminance) + 0.05)
				/ (min(foregroundLuminance, surfaceLuminance) + 0.05)
			#expect(ratio >= 4.5)
		}
	}

	@Test("Adaptive backgrounds use the requested appearance for contrast")
	@MainActor
	func adaptiveForegroundUsesRequestedScheme() throws {
		let background = Color(uiColor: UIColor { traits in
			traits.userInterfaceStyle == .dark
				? UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
				: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
		})
		for scheme in [ColorScheme.light, .dark] {
			try expectAAForeground(on: background, named: "Adaptive background", scheme: scheme)
		}
	}

	// This independent calculation checks opaque color values, not rendered UI contrast.
	@MainActor
	private func expectAAForeground(on background: Color, named name: String, scheme: ColorScheme) throws {
		let foreground = background.contrastingForegroundColor(for: scheme)
		#expect(foreground == .black || foreground == .white)
		let backgroundLuminance = try referenceLuminance(background, scheme: scheme)
		let foregroundLuminance = try referenceLuminance(foreground, scheme: scheme)
		let ratio = (max(backgroundLuminance, foregroundLuminance) + 0.05)
			/ (min(backgroundLuminance, foregroundLuminance) + 0.05)
		#expect(ratio >= 4.5, "\(name), \(String(describing: scheme)): foreground contrast is \(ratio):1")
		let bestRatio = max((backgroundLuminance + 0.05) / 0.05, 1.05 / (backgroundLuminance + 0.05))
		#expect(abs(ratio - bestRatio) < 0.000_001, "\(name): expected the higher black/white contrast ratio")
	}

	@MainActor
	private func referenceLuminance(_ color: Color, scheme: ColorScheme, contrast: UIAccessibilityContrast = .normal) throws -> Double {
		let traits = UITraitCollection(traitsFrom: [
			UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light),
			UITraitCollection(accessibilityContrast: contrast),
		])
		let resolved = UIColor(color).resolvedColor(with: traits)
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		try #require(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
		try #require(abs(alpha - 1) < 0.000_001, "Contrast fixtures must be opaque")
		let linear = [red, green, blue].map { component in
			let value = Double(component)
			return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
		}
		return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
	}

    @Test("Color luminance calculation")
    func colorLuminance() {
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
    func wCAGAACompliance() {
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
    func hexColorContrast() {
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
    func colorSchemeHandling() {
        let mediumColor = Color.gray

        // Should handle both light and dark color schemes
        let lightSchemeColor = mediumColor.contrastingForegroundColor(for: .light)
        let darkSchemeColor = mediumColor.contrastingForegroundColor(for: .dark)

        // Both should return valid colors
        #expect(lightSchemeColor == .black || lightSchemeColor == .white)
        #expect(darkSchemeColor == .black || darkSchemeColor == .white)
    }
}

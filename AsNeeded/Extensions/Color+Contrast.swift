// Color+Contrast.swift
// Extension to provide WCAG-compliant color contrast utilities for accessibility

import SwiftUI

extension Color {
	/// Semantic success tint that stays legible on the guidance card in either appearance.
	static func guidanceGreen(for colorScheme: ColorScheme) -> Color {
		colorScheme == .dark
			? Color(red: 0.38, green: 0.84, blue: 0.48)
			: Color(red: 0.0, green: 0.42, blue: 0.2)
	}


    /// Calculates the relative luminance of a color according to WCAG standards
    /// - Returns: Luminance value between 0 (darkest) and 1 (lightest)
    var luminance: Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 0.5 // Fallback to medium luminance
        }

        // Convert to linear RGB
        let linearRed = gamma(Double(red))
        let linearGreen = gamma(Double(green))
        let linearBlue = gamma(Double(blue))

        // WCAG luminance formula
        return 0.2126 * linearRed + 0.7152 * linearGreen + 0.0722 * linearBlue
    }

    /// Returns black or white for maximum contrast against the resolved opaque background.
    /// - Parameter colorScheme: Current color scheme (light/dark)
    /// - Returns: Whichever of black and white has the greater WCAG contrast ratio.
    /// Translucent backgrounds need compositing against their actual surface before comparison.
    func contrastingForegroundColor(for colorScheme: ColorScheme = .light) -> Color {
		let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
		let resolved = UIColor(self).resolvedColor(with: traits)
		let backgroundLuminance = Color(uiColor: resolved).luminance
		let blackContrast = (backgroundLuminance + 0.05) / 0.05
		let whiteContrast = 1.05 / (backgroundLuminance + 0.05)
		return blackContrast >= whiteContrast ? .black : .white
    }

    /// Returns the optimal foreground color with opacity for secondary text
    /// - Parameter colorScheme: Current color scheme (light/dark)
    /// - Returns: Contrasting color with appropriate opacity
    func contrastingSecondaryColor(for colorScheme: ColorScheme = .light) -> Color {
        return contrastingForegroundColor(for: colorScheme).opacity(0.8)
    }

    /// Calculates the contrast ratio between this color and another
    /// - Parameter other: The other color to compare against
    /// - Returns: Contrast ratio (1:1 to 21:1)
    func contrastRatio(with other: Color) -> Double {
        let luminance1 = luminance
        let luminance2 = other.luminance

        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)

        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Checks if this color meets WCAG AA contrast requirements with another color
    /// - Parameters:
    ///   - other: The other color to compare against
    ///   - isLargeText: Whether the text is considered large (18pt+ or 14pt+ bold)
    /// - Returns: True if contrast meets WCAG AA standards
    func meetsWCAGContrast(with other: Color, isLargeText: Bool = false) -> Bool {
        let ratio = contrastRatio(with: other)
        let requiredRatio = isLargeText ? 3.0 : 4.5
        return ratio >= requiredRatio
    }

    /// Checks if this color meets WCAG AAA contrast requirements with another color
    /// - Parameters:
    ///   - other: The other color to compare against
    ///   - isLargeText: Whether the text is considered large (18pt+ or 14pt+ bold)
    /// - Returns: True if contrast meets WCAG AAA standards
    func meetsWCAGAAAContrast(with other: Color, isLargeText: Bool = false) -> Bool {
        let ratio = contrastRatio(with: other)
        let requiredRatio = isLargeText ? 4.5 : 7.0
        return ratio >= requiredRatio
    }
}

// MARK: - Private Helpers

private func gamma(_ value: Double) -> Double {
    if value <= 0.04045 {
        return value / 12.92
    } else {
        return pow((value + 0.055) / 1.055, 2.4)
    }
}

// MARK: - View Extension for Easy Access

extension View {
    /// Applies the optimal foreground color for the given background color
    /// - Parameters:
    ///   - backgroundColor: The background color to contrast against
    ///   - colorScheme: Current color scheme
    /// - Returns: View with contrasting foreground style applied
    func contrastingForeground(
        against backgroundColor: Color,
        in colorScheme: ColorScheme? = nil
    ) -> some View {
		modifier(ContrastingForegroundModifier(background: backgroundColor, preferredScheme: colorScheme))
    }

    /// Applies the optimal secondary foreground color for the given background color
    /// - Parameters:
    ///   - backgroundColor: The background color to contrast against
    ///   - colorScheme: Current color scheme
    /// - Returns: View with contrasting secondary foreground style applied
    func contrastingSecondaryForeground(
        against backgroundColor: Color,
        in colorScheme: ColorScheme = .light
    ) -> some View {
        foregroundStyle(backgroundColor.contrastingSecondaryColor(for: colorScheme))
    }
}

// MARK: - Appearance-aware Foreground
private struct ContrastingForegroundModifier: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme
	let background: Color
	let preferredScheme: ColorScheme?

	func body(content: Content) -> some View {
		let foreground = background.contrastingForegroundColor(for: preferredScheme ?? colorScheme)
		content
			.foregroundStyle(foreground)
			.tint(foreground)
	}
}

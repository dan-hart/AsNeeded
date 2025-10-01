import Foundation

/// Enumeration of available font families in the app
/// Provides accessibility-focused font options for users with different visual needs
enum FontFamily: String, CaseIterable, Identifiable {
	case system = "system"
	case atkinsonHyperlegible = "atkinson-hyperlegible"

	var id: String { rawValue }

	/// Human-readable display name for the font family
	var displayName: String {
		switch self {
		case .system:
			return String(localized: "System Font")
		case .atkinsonHyperlegible:
			return String(localized: "Atkinson Hyperlegible")
		}
	}

	/// Accessibility description explaining the font's purpose and benefits
	var accessibilityDescription: String {
		switch self {
		case .system:
			return String(localized: "Default system font that adapts to your device's settings and accessibility preferences")
		case .atkinsonHyperlegible:
			return String(localized: "Designed by the Braille Institute for greater legibility and readability for low vision readers. Features letterform distinction to increase character recognition.")
		}
	}

	/// Brief description for settings UI
	var shortDescription: String {
		switch self {
		case .system:
			return String(localized: "Default iOS font with system accessibility support")
		case .atkinsonHyperlegible:
			return String(localized: "Enhanced legibility for low vision readers")
		}
	}

	/// The PostScript name of the font for SwiftUI Font usage
	var fontName: String {
		switch self {
		case .system:
			return "" // Use system default
		case .atkinsonHyperlegible:
			return "AtkinsonHyperlegible-Regular"
		}
	}

	/// The PostScript name of the bold variant
	var boldFontName: String {
		switch self {
		case .system:
			return "" // Use system default
		case .atkinsonHyperlegible:
			return "AtkinsonHyperlegible-Bold"
		}
	}

	/// External link for more information about the font
	var infoURL: URL? {
		switch self {
		case .system:
			return nil
		case .atkinsonHyperlegible:
			return URL(string: "https://brailleinstitute.org/freefont")
		}
	}

	/// Sample text to demonstrate the font in the settings UI
	var sampleText: String {
		return "The quick brown fox jumps over the lazy dog. 0123456789"
	}
}
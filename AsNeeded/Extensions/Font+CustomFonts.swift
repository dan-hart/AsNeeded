import SwiftUI

// MARK: - Custom Font Extension
extension Font {
	/// Create a custom font that respects Dynamic Type while using the specified font family
	/// - Parameters:
	///   - family: The FontFamily to use
	///   - style: The semantic text style (maintains Dynamic Type support)
	///   - weight: Optional font weight (only applied to system font)
	/// - Returns: A Font configured with the specified family and style
	static func customFont(_ family: FontFamily, style: TextStyle, weight: Weight? = nil) -> Font {
		switch family {
		case .system:
			// Use system font with optional weight
			if let weight = weight {
				return .system(style, design: .default, weight: weight)
			} else {
				return .system(style, design: .default)
			}

		case .atkinsonHyperlegible:
			return createCustomFont(
				fontName: family.fontName,
				boldFontName: family.boldFontName,
				style: style,
				weight: weight
			)
		}
	}

	/// Create a custom font with fallback to system font if custom font is unavailable
	private static func createCustomFont(
		fontName: String,
		boldFontName: String,
		style: TextStyle,
		weight: Weight?
	) -> Font {
		// Determine the appropriate font name based on weight
		let selectedFontName: String
		if let weight = weight, isBoldWeight(weight) {
			selectedFontName = boldFontName
		} else {
			selectedFontName = fontName
		}

		// Get the base size for the text style to maintain Dynamic Type scaling
		let baseSize = UIFont.preferredFont(forTextStyle: style.uiFontTextStyle).pointSize

		// Try to create custom font, fallback to system font if unavailable
		if UIFont(name: selectedFontName, size: baseSize) != nil {
			return .custom(selectedFontName, size: baseSize, relativeTo: style)
		} else {
			// Fallback to system font with weight if custom font is not available
			if let weight = weight {
				return .system(style, design: .default, weight: weight)
			} else {
				return .system(style, design: .default)
			}
		}
	}

	/// Check if a font weight is considered bold (semibold or heavier)
	private static func isBoldWeight(_ weight: Weight) -> Bool {
		switch weight {
		case .semibold, .bold, .heavy, .black:
			return true
		default:
			return false
		}
	}
}

// MARK: - TextStyle to UIFont.TextStyle Mapping
private extension Font.TextStyle {
	/// Convert SwiftUI TextStyle to UIKit UIFont.TextStyle for Dynamic Type support
	var uiFontTextStyle: UIFont.TextStyle {
		switch self {
		case .largeTitle:
			return .largeTitle
		case .title:
			return .title1
		case .title2:
			return .title2
		case .title3:
			return .title3
		case .headline:
			return .headline
		case .body:
			return .body
		case .callout:
			return .callout
		case .subheadline:
			return .subheadline
		case .footnote:
			return .footnote
		case .caption:
			return .caption1
		case .caption2:
			return .caption2
		@unknown default:
			return .body
		}
	}
}

// MARK: - Environment Font Family
/// Environment key for the selected font family
private struct FontFamilyKey: EnvironmentKey {
	static let defaultValue: FontFamily = .system
}

extension EnvironmentValues {
	/// The currently selected font family from app preferences
	var fontFamily: FontFamily {
		get { self[FontFamilyKey.self] }
		set { self[FontFamilyKey.self] = newValue }
	}
}

// MARK: - View Extension for Font Family Environment
extension View {
	/// Apply the selected font family to the view hierarchy
	/// - Parameter fontFamily: The FontFamily to use throughout the view hierarchy
	/// - Returns: A view with the font family applied to the environment
	func fontFamily(_ fontFamily: FontFamily) -> some View {
		environment(\.fontFamily, fontFamily)
	}
}

// MARK: - Convenience Font Modifiers
extension View {
	/// Apply a font style using the current environment font family
	/// - Parameters:
	///   - style: The semantic text style
	///   - weight: Optional font weight
	/// - Returns: A view with the font applied
	func font(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
		modifier(CustomFontModifier(style: style, weight: weight))
	}
}

/// View modifier that applies custom fonts based on environment font family
private struct CustomFontModifier: ViewModifier {
	@Environment(\.fontFamily) private var fontFamily
	let style: Font.TextStyle
	let weight: Font.Weight?

	func body(content: Content) -> some View {
		content.font(.customFont(fontFamily, style: style, weight: weight))
	}
}
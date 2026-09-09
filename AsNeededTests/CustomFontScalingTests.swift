import Testing
import SwiftUI
import UIKit
@testable import AsNeeded

/// Verifies that custom accessibility fonts scale with Dynamic Type at the same rate as the system font.
///
/// Background: `Font.custom(_:size:relativeTo:)` and `UIFontMetrics.scaledFont(for:)` both scale a
/// *base* size for the current content size category. Feeding them a size that was already read
/// from `UIFont.preferredFont(forTextStyle:)` for the current category scales twice, so custom
/// fonts grew far faster than the system font at accessibility sizes.
@Suite("Custom Font Scaling Tests")
struct CustomFontScalingTests {
	private static let styles: [(String, UIFont.TextStyle)] = [
		("largeTitle", .largeTitle), ("title1", .title1), ("title2", .title2), ("title3", .title3),
		("headline", .headline), ("body", .body), ("callout", .callout), ("subheadline", .subheadline),
		("footnote", .footnote), ("caption1", .caption1), ("caption2", .caption2),
	]

	private static func traits(_ category: UIContentSizeCategory) -> UITraitCollection {
		UITraitCollection(preferredContentSizeCategory: category)
	}

	private static func systemSize(_ style: UIFont.TextStyle, at category: UIContentSizeCategory) -> CGFloat {
		UIFont.preferredFont(forTextStyle: style, compatibleWith: traits(category)).pointSize
	}

	/// The size the previous implementation produced: base size read at the *current* category, scaled again.
	private static func doubleScaledSize(_ style: UIFont.TextStyle, fontName: String, at category: UIContentSizeCategory) -> CGFloat {
		let base = systemSize(style, at: category)
		guard let font = UIFont(name: fontName, size: base) else { return .nan }
		return UIFontMetrics(forTextStyle: style).scaledFont(for: font, compatibleWith: traits(category)).pointSize
	}

	private static func fixedSize(_ style: UIFont.TextStyle, fontName: String, at category: UIContentSizeCategory) -> CGFloat {
		let base = UIFont.dynamicTypeBaseSize(for: style)
		guard let font = UIFont(name: fontName, size: base) else { return .nan }
		return UIFontMetrics(forTextStyle: style).scaledFont(for: font, compatibleWith: traits(category)).pointSize
	}

	@Test("Atkinson Hyperlegible matches system point size at every Dynamic Type category")
	func atkinsonMatchesSystemAcrossCategories() throws {
		FontManager.registerCustomFonts()
		let fontName = FontFamily.atkinsonHyperlegible.fontName
		try #require(UIFont(name: fontName, size: 17) != nil, "Atkinson Hyperlegible must be registered")

		let categories: [UIContentSizeCategory] = [
			.extraSmall, .large, .extraExtraExtraLarge, .accessibilityMedium, .accessibilityLarge,
			.accessibilityExtraExtraExtraLarge,
		]
		for category in categories {
			for (name, style) in Self.styles {
				let system = Self.systemSize(style, at: category)
				let custom = Self.fixedSize(style, fontName: fontName, at: category)
				// UIFontMetrics applies its own per-style curve, which sits within ~15% of the system table at
				// accessibility sizes. The bug this guards against produced 1.5x to 2.8x the system size.
				let tolerance = max(1.5, system * 0.15)
				#expect(abs(system - custom) <= tolerance, "\(name) at \(category.rawValue): system \(system) vs custom \(custom)")
			}
		}
	}

	@Test("Base size table equals Apple's default (Large) sizes")
	func baseSizesMatchLargeCategory() {
		for (name, style) in Self.styles {
			let expected = Self.systemSize(style, at: .large)
			#expect(UIFont.dynamicTypeBaseSize(for: style) == expected, "\(name): \(UIFont.dynamicTypeBaseSize(for: style)) vs \(expected)")
		}
	}

	/// Height of a single-line SwiftUI `Text` laid out with the given font at the given Dynamic Type size.
	@MainActor
	private static func renderedHeight(_ font: Font, at size: DynamicTypeSize) -> CGFloat {
		let view = Text("Hg").font(font).fixedSize().environment(\.dynamicTypeSize, size)
		let controller = UIHostingController(rootView: view)
		return controller.sizeThatFits(in: CGSize(width: 1000, height: 1000)).height
	}

	@Test("SwiftUI relativeTo scaling matches the system text style size", arguments: [FontFamily.atkinsonHyperlegible, .openDyslexic])
	@MainActor
	func swiftUIRelativeScalingMatchesSystem(family: FontFamily) throws {
		FontManager.registerCustomFonts()
		let fontName = family.fontName
		try #require(UIFont(name: fontName, size: 17) != nil)
		let cases: [(String, DynamicTypeSize, UIContentSizeCategory)] = [
			("L", .large, .large), ("xxxL", .xxxLarge, .extraExtraExtraLarge),
			("AX1", .accessibility1, .accessibilityMedium), ("AX3", .accessibility3, .accessibilityExtraLarge),
			("AX5", .accessibility5, .accessibilityExtraExtraExtraLarge),
		]
		let checks: [(String, Font.TextStyle, UIFont.TextStyle)] = [
			("largeTitle", .largeTitle, .largeTitle), ("body", .body, .body), ("footnote", .footnote, .footnote),
			("caption2", .caption2, .caption2),
		]
		for (label, dynamicSize, category) in cases {
			for (name, style, uiStyle) in checks {
				let systemPoints = Self.systemSize(uiStyle, at: category)
				let relative = Font.custom(fontName, size: UIFont.dynamicTypeBaseSize(for: uiStyle), relativeTo: style)
				let reference = Font.custom(fontName, fixedSize: systemPoints)
				let relativeHeight = Self.renderedHeight(relative, at: dynamicSize)
				let referenceHeight = Self.renderedHeight(reference, at: dynamicSize)
				let impliedPoints = systemPoints * relativeHeight / referenceHeight
				#expect(abs(impliedPoints - systemPoints) <= max(1.5, systemPoints * 0.15), "\(family.rawValue) \(name) at \(label): system \(systemPoints) vs SwiftUI \(impliedPoints)")
			}
		}
	}
}

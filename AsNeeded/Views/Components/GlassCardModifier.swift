import SwiftUI
import SFSafeSymbols

/// A SwiftUI view modifier that applies a glass morphism card appearance
///
/// Features:
/// - Material background with blur effect
/// - Gradient border that adapts to light/dark mode
/// - Customizable corner radius and padding
/// - Subtle drop shadow for depth
/// - Responsive to color scheme changes
///
/// **Appearance:**
/// - Semi-transparent material background
/// - Smooth rounded corners with configurable radius
/// - Gradient border (more opaque in light mode, subtle in dark mode)
/// - Soft shadow underneath for visual depth
/// - Consistent padding around content
///
/// **Use Cases:**
/// - Form sections and input groups
/// - Content cards in lists or grids
/// - Settings panels and configuration sections
/// - Modal content areas
/// - Dashboard widgets and summary cards
/// - Any content requiring subtle visual separation
struct GlassCardModifier: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	let cornerRadius: CGFloat
	let padding: CGFloat
	let shadowRadius: CGFloat
	let shadowY: CGFloat

	init(
		cornerRadius: CGFloat = 20,
		padding: CGFloat = 20,
		shadowRadius: CGFloat = 10,
		shadowY: CGFloat = 5
	) {
		self.cornerRadius = cornerRadius
		self.padding = padding
		self.shadowRadius = shadowRadius
		self.shadowY = shadowY
	}

	func body(content: Content) -> some View {
		content
			.padding(padding)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius)
					.fill(.regularMaterial)
					.shadow(color: Color.black.opacity(0.1), radius: shadowRadius, y: shadowY)
					.overlay(
						RoundedRectangle(cornerRadius: cornerRadius)
							.strokeBorder(
								LinearGradient(
									colors: [
										.white.opacity(colorScheme == .dark ? 0.2 : 0.5),
										.white.opacity(0.1)
									],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								),
								lineWidth: 1
							)
					)
			)
	}
}

extension View {
	/// Applies a glass card appearance with material background and gradient border
	func glassCard(
		cornerRadius: CGFloat = 20,
		padding: CGFloat = 20,
		shadowRadius: CGFloat = 10,
		shadowY: CGFloat = 5
	) -> some View {
		modifier(GlassCardModifier(
			cornerRadius: cornerRadius,
			padding: padding,
			shadowRadius: shadowRadius,
			shadowY: shadowY
		))
	}
}

#if DEBUG
#Preview {
	@Previewable @Environment(\.fontFamily) var fontFamily

	VStack(spacing: 20) {
		Text("Default Glass Card")
			.font(.customFont(fontFamily, style: .headline))
			.glassCard()

		VStack {
			Text("Custom Glass Card")
				.font(.customFont(fontFamily, style: .headline))
			Text("With custom parameters")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
		}
		.glassCard(cornerRadius: 12, padding: 16)

		HStack {
			Image(systemSymbol: .starFill)
				.foregroundStyle(.yellow)
			Text("Compact Card")
				.font(.customFont(fontFamily, style: .body))
		}
		.glassCard(cornerRadius: 8, padding: 12, shadowRadius: 5, shadowY: 2)
	}
	.padding()
	.background(.ultraThinMaterial)
}
#endif
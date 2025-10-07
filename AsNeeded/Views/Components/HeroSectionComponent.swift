import SwiftUI
import SFSafeSymbols

/// A visually striking hero section component with a glass morphism design
///
/// Features:
/// - Animated glass icon with gradient background and border
/// - Dynamic title and subtitle text with gradient styling
/// - Responsive to editing vs. creation mode
/// - Built-in accessibility support with header traits
///
/// **Appearance:**
/// - Large circular glass icon with animated gradient backdrop
/// - Bold title text with gradient foreground
/// - Descriptive subtitle in secondary color
/// - Generous vertical padding for visual impact
///
/// **Use Cases:**
/// - Edit/Create medication screens
/// - Onboarding flows with prominent call-to-action
/// - Settings or profile creation screens
/// - Any screen requiring a visually impactful header section
/// - Forms with distinctive branding sections
struct HeroSectionComponent: View {
	let isEditing: Bool
	let icon: SFSymbol
	let title: String
	let subtitle: String

	@ScaledMetric private var iconSize: CGFloat = 100
	@ScaledMetric private var iconBlurSize: CGFloat = 120
	@ScaledMetric private var verticalPadding: CGFloat = 30
	@ScaledMetric private var iconSpacing: CGFloat = 20

	init(
		isEditing: Bool,
		icon: SFSymbol? = nil,
		title: String? = nil,
		subtitle: String? = nil
	) {
		self.isEditing = isEditing
		self.icon = icon ?? (isEditing ? .pills : .pillsFill)
		self.title = title ?? (isEditing ? "Edit Medication" : "Add New Medication")
		self.subtitle = subtitle ?? (isEditing ? "Update medication details" : "Set up a new medication to track")
	}

	var body: some View {
		VStack(spacing: iconSpacing) {
			// Animated icon with liquid glass effect
			ZStack {
				// Animated gradient background
				Circle()
					.fill(
						LinearGradient(
							colors: [
								.accent.opacity(0.3),
								.accent.opacity(0.1)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.frame(width: iconBlurSize, height: iconBlurSize)
					.blur(radius: 20)

				// Glass circle
				Circle()
					.fill(.ultraThinMaterial)
					.frame(width: iconSize, height: iconSize)
					.overlay(
						Circle()
							.strokeBorder(
								LinearGradient(
									colors: [
										.white.opacity(0.6),
										.white.opacity(0.2)
									],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								),
								lineWidth: 1
							)
					)

				// Icon
				Image(systemSymbol: icon)
					.font(.largeTitle.weight(.medium))
					.foregroundStyle(
						LinearGradient(
							colors: [.accent, .accent.opacity(0.7)],
							startPoint: .top,
							endPoint: .bottom
						)
					)
					.accessibilityHidden(true)
			}

			Text(title)
				.font(.largeTitle)
				.fontWeight(.bold)
				.foregroundStyle(
					LinearGradient(
						colors: [.primary, .primary.opacity(0.8)],
						startPoint: .leading,
						endPoint: .trailing
					)
				)
				.accessibilityAddTraits(.isHeader)

			Text(subtitle)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.padding(.vertical, verticalPadding)
		.accessibilityElement(children: .combine)
	}
}

#if DEBUG
#Preview("Add Medication") {
	HeroSectionComponent(isEditing: false)
		.padding()
}

#Preview("Edit Medication") {
	HeroSectionComponent(isEditing: true)
		.padding()
}

#Preview("Custom") {
	HeroSectionComponent(
		isEditing: false,
		icon: .heartFill,
		title: "Custom Title",
		subtitle: "Custom subtitle text here"
	)
	.padding()
}
#endif
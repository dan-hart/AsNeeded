import SwiftUI
import SFSafeSymbols

/// A reusable component for linking users to the TestFlight beta program
///
/// **Appearance:**
/// - Rounded card with glass material background
/// - Airplane icon in gradient blue background (TestFlight brand association)
/// - Title "Join TestFlight Beta" with subtitle describing early access
/// - External link arrow indicator on the right
/// - Follows app's design system with proper spacing and accessibility
///
/// **Features:**
/// - Fully localized in all supported languages
/// - VoiceOver accessible with descriptive labels and hints
/// - Opens TestFlight join link in default browser
/// - Consistent design with other link buttons in the app
///
/// **Use Cases:**
/// - Feedback/support screens to invite user testing
/// - About page to show beta access option
/// - Thank you view after purchases to offer more ways to contribute
/// - Settings screens related to app updates
///
/// **Example:**
/// ```swift
/// TestFlightAccessComponent()
/// ```
struct TestFlightAccessComponent: View {
	@ScaledMetric private var elementSpacing: CGFloat = 12
	@ScaledMetric private var textSpacing: CGFloat = 2
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var cornerRadius10: CGFloat = 10
	@ScaledMetric private var iconSize40: CGFloat = 40
	@Environment(\.openURL) private var openURL
	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		Button(action: openTestFlight) {
			HStack(spacing: elementSpacing) {
				Image(systemSymbol: .airplaneCircleFill)
					.font(.title2)
					.foregroundColor(.white)
					.frame(width: iconSize40, height: iconSize40)
					.background(
						LinearGradient(
							colors: [.blue, .cyan],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.cornerRadius(cornerRadius10)

				VStack(alignment: .leading, spacing: textSpacing) {
					Text(String(localized: "Join TestFlight Beta"))
						.font(.customFont(fontFamily, style: .callout, weight: .semibold))
						.foregroundColor(.primary)

					Text(String(localized: "Get early access to new features and updates"))
						.font(.customFont(fontFamily, style: .caption))
						.foregroundColor(.secondary)
				}

				Spacer()

				Image(systemSymbol: .arrowUpRight)
					.font(.caption)
					.foregroundColor(.secondary)
			}
			.padding(cardPadding)
			.background(.regularMaterial)
			.cornerRadius(cornerRadius12)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(String(localized: "Join TestFlight Beta"))
		.accessibilityHint(String(localized: "Join TestFlight to test new features before release"))
	}

	private func openTestFlight() {
		if let url = AppURLs.testFlightBeta {
			openURL(url)
		}
	}
}

#if DEBUG
#Preview {
	VStack(spacing: 16) {
		TestFlightAccessComponent()

		TestFlightAccessComponent()
	}
	.padding()
}
#endif

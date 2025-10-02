import SwiftUI
import SFSafeSymbols

#if DEBUG
struct SettingsDebugSectionView: View {
	@StateObject private var featureToggleManager = FeatureToggleManager.shared
	@State private var showThankYouView = false
	@State private var showWelcomeView = false
	@State private var showFontTestView = false
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5
	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Debug")
				.font(.customFont(fontFamily, style: .title2))
				.fontWeight(.semibold)

			// Feature Toggles Section
			VStack(alignment: .leading, spacing: 8) {
				Text("Feature Toggles")
					.font(.customFont(fontFamily, style: .headline))
					.padding(.top, 8)

				HStack {
					Image(systemSymbol: .textBubble)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Quick Note Phrases")
							.font(.customFont(fontFamily, style: .body))
							.fontWeight(.medium)
						Text("Show phrase suggestions when adding notes")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
					}

					Spacer()

					Toggle("", isOn: $featureToggleManager.quickPhrasesEnabled)
						.labelsHidden()
				}
				.padding(padding)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: cornerRadius)
						.stroke(Color(.systemGray4), lineWidth: borderWidth)
				)
				.cornerRadius(cornerRadius)
			}

			Button {
				showThankYouView = true
			} label: {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .heartFill)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Test Thank You View")
							.font(.customFont(fontFamily, style: .body))
							.fontWeight(.medium)
						Text("Preview the thank you screen")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
					}

					Spacer()

					Image(systemSymbol: .chevronRight)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(padding)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: cornerRadius)
						.stroke(Color(.systemGray4), lineWidth: borderWidth)
				)
				.cornerRadius(cornerRadius)
			}
			.buttonStyle(.plain)
			.sheet(isPresented: $showThankYouView) {
				ThankYouView(purchaseType: .tip(amount: "$4.99"))
					.environmentObject(FeedbackService.shared)
			}

			Button {
				showWelcomeView = true
			} label: {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .handWave)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Test Welcome View")
							.font(.customFont(fontFamily, style: .body))
							.fontWeight(.medium)
						Text("Preview the welcome screen")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
					}

					Spacer()

					Image(systemSymbol: .chevronRight)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(padding)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: cornerRadius)
						.stroke(Color(.systemGray4), lineWidth: borderWidth)
				)
				.cornerRadius(cornerRadius)
			}
			.buttonStyle(.plain)
			.sheet(isPresented: $showWelcomeView) {
				WelcomeView()
			}

			NavigationLink {
				FontTestView()
			} label: {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .textformat)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Test Custom Fonts")
							.font(.customFont(fontFamily, style: .body))
							.fontWeight(.medium)
						Text("Check font loading and availability")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
					}

					Spacer()

					Image(systemSymbol: .chevronRight)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(padding)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: cornerRadius)
						.stroke(Color(.systemGray4), lineWidth: borderWidth)
				)
				.cornerRadius(cornerRadius)
			}
			.buttonStyle(.plain)
		}
	}
}

#Preview {
	SettingsDebugSectionView()
}
#endif
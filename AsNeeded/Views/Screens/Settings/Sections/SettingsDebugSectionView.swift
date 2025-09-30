import SwiftUI
import SFSafeSymbols

#if DEBUG
struct SettingsDebugSectionView: View {
	@State private var showThankYouView = false
	@State private var showWelcomeView = false
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Debug")
				.font(.title2)
				.fontWeight(.semibold)

			Button {
				showThankYouView = true
			} label: {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .heartFill)
						.font(.system(.callout, design: .default, weight: .medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Test Thank You View")
							.font(.body)
							.fontWeight(.medium)
						Text("Preview the thank you screen")
							.font(.caption)
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
						.font(.system(.callout, design: .default, weight: .medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Test Welcome View")
							.font(.body)
							.fontWeight(.medium)
						Text("Preview the welcome screen")
							.font(.caption)
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
		}
	}
}

#Preview {
	SettingsDebugSectionView()
}
#endif
import SwiftUI
import SFSafeSymbols

#if DEBUG
struct SettingsDebugSectionView: View {
	@State private var showThankYouView = false
	@State private var showWelcomeView = false
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Debug")
				.font(.title2)
				.fontWeight(.semibold)

			Button {
				showThankYouView = true
			} label: {
				HStack(spacing: 12) {
					Image(systemSymbol: .heartFill)
						.font(.system(.callout, design: .default, weight: .medium))
						.frame(width: 24, height: 24)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: 2) {
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
				.padding(16)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: 12)
						.stroke(Color(.systemGray4), lineWidth: 0.5)
				)
				.cornerRadius(12)
			}
			.buttonStyle(.plain)
			.sheet(isPresented: $showThankYouView) {
				ThankYouView(purchaseType: .tip(amount: "$4.99"))
					.environmentObject(FeedbackService.shared)
			}

			Button {
				showWelcomeView = true
			} label: {
				HStack(spacing: 12) {
					Image(systemSymbol: .handWave)
						.font(.system(.callout, design: .default, weight: .medium))
						.frame(width: 24, height: 24)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: 2) {
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
				.padding(16)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: 12)
						.stroke(Color(.systemGray4), lineWidth: 0.5)
				)
				.cornerRadius(12)
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
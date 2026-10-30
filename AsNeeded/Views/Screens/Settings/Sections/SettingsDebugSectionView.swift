import SwiftUI
import SFSafeSymbols

struct SettingsDebugSectionView: View {
	@State private var showThankYouView = false
	@State private var showWelcomeView = false
	private let itemSpacing: CGFloat = 16
	private let headerSpacing: CGFloat = 12
	@Environment(\.fontFamily) private var fontFamily

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Debug")
				.font(.customFont(fontFamily, style: .title2))
				.fontWeight(.semibold)
				.accessibilityAddTraits(.isHeader)

			Button {
				showThankYouView = true
			} label: {
				SettingsNavigationRowLabel(
					title: String(localized: "Test Thank You View"),
					subtitle: String(localized: "Preview the thank you screen"),
					icon: .heartFill,
					iconColor: .accent
				)
			}
			.buttonStyle(.plain)
			.sheet(isPresented: $showThankYouView) {
				ThankYouView(purchaseType: .tip(amount: "$4.99"))
					.environmentObject(FeedbackService.shared)
			}

			Button {
				showWelcomeView = true
			} label: {
				SettingsNavigationRowLabel(
					title: String(localized: "Test Welcome View"),
					subtitle: String(localized: "Preview the welcome screen"),
					icon: .handWave,
					iconColor: .accent
				)
			}
			.buttonStyle(.plain)
			.sheet(isPresented: $showWelcomeView) {
				WelcomeView()
			}

			NavigationLink {
				FontTestView()
			} label: {
				SettingsNavigationRowLabel(
					title: String(localized: "Test Custom Fonts"),
					subtitle: String(localized: "Check font loading and availability"),
					icon: .textformat,
					iconColor: .accent
				)
			}
			.buttonStyle(.plain)
		}
	}
}

#Preview {
	SettingsDebugSectionView()
}

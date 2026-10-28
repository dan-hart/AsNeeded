import SwiftUI
import SFSafeSymbols

struct SettingsAboutSectionView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let itemSpacing: CGFloat = 16
	private let headerSpacing: CGFloat = 12

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("About")
				.font(.customFont(fontFamily, style: .title2))
				.fontWeight(.semibold)
				.accessibilityAddTraits(.isHeader)

			NavigationLink {
				AboutView()
			} label: {
				SettingsNavigationRowLabel(
					title: "About This App",
					subtitle: "Version, build, and overview",
					icon: .infoCircle,
					iconColor: .accent
				)
			}
			.buttonStyle(.plain)
		}
	}
}

#if DEBUG
#Preview { SettingsAboutSectionView() }
#endif


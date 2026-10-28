import SwiftUI
import SFSafeSymbols

struct SettingsSupportSectionView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let itemSpacing: CGFloat = 16
	private let headerSpacing: CGFloat = 12

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Support")
				.font(.customFont(fontFamily, style: .title2))
				.fontWeight(.semibold)
				.accessibilityAddTraits(.isHeader)

			NavigationLink {
				SupportView()
			} label: {
				SettingsNavigationRowLabel(
					title: "Support As Needed",
					subtitle: "Tips, donations, and ways to help",
					icon: .heart,
					iconColor: .red
				)
			}
			.buttonStyle(.plain)
		}
	}
}

#if DEBUG
#Preview { 
	SettingsSupportSectionView() 
}
#endif

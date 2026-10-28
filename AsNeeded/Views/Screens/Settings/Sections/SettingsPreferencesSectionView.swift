import SwiftUI
import SFSafeSymbols

struct SettingsPreferencesSectionView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let itemSpacing: CGFloat = 16
	private let headerSpacing: CGFloat = 12

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Preferences")
				.font(.customFont(fontFamily, style: .title2))
				.fontWeight(.semibold)
				.accessibilityAddTraits(.isHeader)

			NavigationLink {
				AppPreferencesView()
			} label: {
				SettingsNavigationRowLabel(
					title: "App Preferences",
					subtitle: "Notifications, haptics, and app behavior",
					icon: .gearshape,
					iconColor: .accent
				)
			}
			.buttonStyle(.plain)
		}
	}
}

#Preview {
	SettingsPreferencesSectionView()
		.padding()
}

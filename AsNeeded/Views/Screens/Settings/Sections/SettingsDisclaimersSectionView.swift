import SwiftUI
import SFSafeSymbols

struct SettingsDisclaimersSectionView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let itemSpacing: CGFloat = 16
	private let headerSpacing: CGFloat = 12

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Disclaimers")
				.font(.customFont(fontFamily, style: .title2))
				.fontWeight(.semibold)
				.accessibilityAddTraits(.isHeader)

			VStack(spacing: headerSpacing) {
				// Medical Disclaimer
				NavigationLink {
					MedicalDisclaimerDetailView()
				} label: {
					SettingsNavigationRowLabel(
						title: "Medical Disclaimer",
						subtitle: "Important medical advice information",
						icon: .exclamationmarkTriangle,
						iconColor: .yellow
					)
				}
				.buttonStyle(.plain)

				// NIH/NLM Data Attribution
				NavigationLink {
					NIHDisclaimerDetailView()
				} label: {
					SettingsNavigationRowLabel(
						title: "Medical Data Sources",
						subtitle: "NIH/NLM RxNorm database citations",
						icon: .buildingColumns,
						iconColor: .accent
					)
				}
				.buttonStyle(.plain)
			}
		}
	}
}

#if DEBUG
#Preview {
	NavigationView {
		SettingsDisclaimersSectionView()
			.padding()
	}
}
#endif

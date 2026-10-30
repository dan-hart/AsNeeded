import SwiftUI
import SFSafeSymbols

struct SettingsFeedbackSectionView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let itemSpacing: CGFloat = 16
	private let headerSpacing: CGFloat = 12

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Feedback")
				.font(.customFont(fontFamily, style: .title2))
				.fontWeight(.semibold)
				.accessibilityAddTraits(.isHeader)

			NavigationLink {
				FeedbackView()
			} label: {
				SettingsNavigationRowLabel(
					title: String(localized: "Send Feedback"),
					subtitle: String(localized: "Report bugs, request features, or share ideas"),
					icon: .bubbleLeftAndBubbleRight,
					iconColor: .accent
				)
			}
			.buttonStyle(.plain)
		}
	}
}

#if DEBUG
#Preview { 
	SettingsFeedbackSectionView() 
}
#endif

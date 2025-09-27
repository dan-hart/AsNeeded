import SwiftUI
import SFSafeSymbols

struct SettingsFeedbackSectionView: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Feedback")
				.font(.title2)
				.fontWeight(.semibold)

			NavigationLink {
				FeedbackView()
			} label: {
				HStack(spacing: 12) {
					Image(systemSymbol: .bubbleLeftAndBubbleRight)
						.font(.system(.callout, design: .default, weight: .medium))
						.frame(width: 24, height: 24)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: 2) {
						Text("Send Feedback")
							.font(.body)
							.fontWeight(.medium)
						Text("Report bugs, request features, or share ideas")
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
		}
	}
}

#if DEBUG
#Preview { 
	SettingsFeedbackSectionView() 
}
#endif
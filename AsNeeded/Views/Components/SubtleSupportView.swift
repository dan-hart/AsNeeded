import SwiftUI
import SFSafeSymbols

struct SubtleSupportView: View {
	let message: String
	@AppStorage("hideSupportBanners") private var hideSupportBanners = false
	@ScaledMetric private var contentSpacing: CGFloat = 8
	@ScaledMetric private var dividerHeight: CGFloat = 20
	@ScaledMetric private var verticalPadding: CGFloat = 8
	@ScaledMetric private var horizontalPadding: CGFloat = 12
	@ScaledMetric private var cornerRadius: CGFloat = 8

	init(message: String = "If As Needed is helpful, consider supporting development") {
		self.message = message
	}

	var body: some View {
		if !hideSupportBanners {
			HStack(spacing: contentSpacing) {
				NavigationLink {
					SupportView()
				} label: {
					HStack(spacing: contentSpacing) {
						Image(systemSymbol: .heart)
							.font(.caption.weight(.medium))
							.foregroundColor(.red.opacity(0.6))

						Text(message)
							.font(.footnote)
							.foregroundColor(.secondary)

						Spacer()

						Image(systemSymbol: .chevronRight)
							.font(.caption2)
							.foregroundColor(.secondary.opacity(0.6))
					}
				}
				.buttonStyle(.plain)

				Divider()
					.frame(height: dividerHeight)

				Button {
					hideSupportBanners = true
				} label: {
					Text("Hide")
						.font(.caption2)
						.foregroundColor(.secondary)
				}
				.buttonStyle(.plain)
			}
			.padding(.vertical, verticalPadding)
			.padding(.horizontal, horizontalPadding)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius)
					.fill(Color(.tertiarySystemBackground))
					.opacity(0.5)
			)
		}
	}
}

#if DEBUG
#Preview {
	VStack(spacing: 16) {
		SubtleSupportView()
		SubtleSupportView(message: "Enjoying the app? Help keep it free and open source")
	}
	.padding()
}
#endif
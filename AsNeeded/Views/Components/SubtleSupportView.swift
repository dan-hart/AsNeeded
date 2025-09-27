import SwiftUI
import SFSafeSymbols

struct SubtleSupportView: View {
	let message: String
	@AppStorage("hideSupportBanners") private var hideSupportBanners = false
	
	init(message: String = "If As Needed is helpful, consider supporting development") {
		self.message = message
	}
	
	var body: some View {
		if !hideSupportBanners {
			HStack(spacing: 8) {
				NavigationLink {
					SupportView()
				} label: {
					HStack(spacing: 8) {
						Image(systemSymbol: .heart)
							.font(.system(.caption, design: .default, weight: .medium))
							.foregroundColor(.red.opacity(0.6))
						
						Text(message)
							.font(.footnote)
							.foregroundColor(.secondary)
						
						Spacer()
						
						Image(systemSymbol: .chevronRight)
							.font(.system(.caption2, design: .default))
							.foregroundColor(.secondary.opacity(0.6))
					}
				}
				.buttonStyle(.plain)
				
				Divider()
					.frame(height: 20)
				
				Button {
					hideSupportBanners = true
				} label: {
					Text("Hide")
						.font(.caption2)
						.foregroundColor(.secondary)
				}
				.buttonStyle(.plain)
			}
			.padding(.vertical, 8)
			.padding(.horizontal, 12)
			.background(
				RoundedRectangle(cornerRadius: 8)
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
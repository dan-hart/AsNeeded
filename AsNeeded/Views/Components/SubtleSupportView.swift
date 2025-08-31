import SwiftUI
import SFSafeSymbols

struct SubtleSupportView: View {
	let message: String
	
	init(message: String = "If As Needed is helpful, consider supporting development") {
		self.message = message
	}
	
	var body: some View {
		NavigationLink {
			SupportView()
		} label: {
			HStack(spacing: 8) {
				Image(systemSymbol: .heart)
					.font(.system(size: 12, weight: .medium))
					.foregroundColor(.red.opacity(0.6))
				
				Text(message)
					.font(.footnote)
					.foregroundColor(.secondary)
				
				Spacer()
				
				Image(systemSymbol: .chevronRight)
					.font(.system(size: 10))
					.foregroundColor(.secondary.opacity(0.6))
			}
			.padding(.vertical, 8)
			.padding(.horizontal, 12)
			.background(
				RoundedRectangle(cornerRadius: 8)
					.fill(Color(.tertiarySystemBackground))
					.opacity(0.5)
			)
		}
		.buttonStyle(.plain)
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
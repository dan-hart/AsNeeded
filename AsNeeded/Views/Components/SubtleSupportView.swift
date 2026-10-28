import SwiftUI

struct SubtleSupportView: View {
	let message: String

	init(message: String = "If As Needed is helpful, consider supporting development") {
		self.message = message
	}

	var body: some View {
		SupportSuggestionView(message: message)
	}
}

#if DEBUG
	#Preview {
		NavigationStack {
			VStack(spacing: 16) {
				SubtleSupportView()
				SubtleSupportView(message: "Enjoying the app? Help keep it free and open source")
			}
			.padding()
		}
	}
#endif

import SwiftUI

struct SubtleSupportView: View {
	let message: String
	let onSupportTapped: () -> Void

	init(message: String = String(localized: "If As Needed is helpful, consider supporting development"), onSupportTapped: @escaping () -> Void) {
		self.message = message
		self.onSupportTapped = onSupportTapped
	}

	var body: some View {
		SupportSuggestionView(message: message, onSupportTapped: onSupportTapped)
	}
}

#if DEBUG
	#Preview {
		NavigationStack {
			VStack(spacing: 16) {
				SubtleSupportView(onSupportTapped: {})
				SubtleSupportView(message: "Enjoying the app? Help keep it free and open source", onSupportTapped: {})
			}
			.padding()
		}
	}
#endif

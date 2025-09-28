import SwiftUI

private struct ContentSizePreferenceKey: PreferenceKey {
	static let defaultValue: CGSize = .zero
	static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
		value = nextValue()
	}
}

extension View {
	/// Applies dynamic sheet presentation detents based on content size
	/// - Returns: `.medium` if content fits comfortably, `.large` if content needs more space
	func dynamicDetent() -> some View {
		modifier(DynamicDetentModifier())
	}
}

private struct DynamicDetentModifier: ViewModifier {
	@State private var contentHeight: CGFloat = 0
	@State private var screenHeight: CGFloat = 0

	func body(content: Content) -> some View {
		content
			.background(
				GeometryReader { geometry in
					Color.clear
						.preference(key: ContentSizePreferenceKey.self, value: geometry.size)
				}
			)
			.onPreferenceChange(ContentSizePreferenceKey.self) { size in
				contentHeight = size.height
			}
			.onAppear {
				// Get actual screen height from current window
				if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
				   let window = windowScene.windows.first {
					screenHeight = window.bounds.height
				}
			}
			.presentationDetents(dynamicDetents)
			.presentationDragIndicator(.visible)
	}

	private var dynamicDetents: Set<PresentationDetent> {
		guard screenHeight > 0, contentHeight > 0 else {
			// Default fallback when measurements aren't ready
			return [.medium, .large]
		}

		// Calculate realistic medium detent space
		// iPhone screens: ~850-950pt tall, medium detent ~50% = 425-475pt
		// Minus safe areas (~100pt) and navigation (~50pt) = ~275-325pt usable
		let estimatedMediumSpace: CGFloat = screenHeight * 0.35

		// If content is significantly larger than medium space, default to large
		// Otherwise provide both options
		if contentHeight > estimatedMediumSpace * 1.3 {
			return [.large] // Content too large for comfortable medium detent
		} else {
			return [.medium, .large] // Content fits reasonably in medium
		}
	}
}
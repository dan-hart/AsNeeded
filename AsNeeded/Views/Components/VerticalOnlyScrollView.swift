// VerticalOnlyScrollView.swift
// A vertical scroll view whose content can never grow wider than the viewport.

import SwiftUI

/// A vertical `ScrollView` that pins its content to the container's width.
///
/// A plain vertical `ScrollView` still pans sideways when a child's ideal width is wider than the screen,
/// which happens with long single-line text, wide custom fonts, or large Dynamic Type sizes. Sizing the
/// content to the container instead makes text wrap and removes the sideways scroll and rubber-banding.
///
/// **Features:**
/// - Content width equals the scroll container's width, so nothing can scroll horizontally
/// - Accepts the same content closure and trailing modifiers as `ScrollView`
///
/// **Use Cases:**
/// - Every screen under the Settings tab, Support and the disclaimer pages
struct VerticalOnlyScrollView<Content: View>: View {
	var showsIndicators = true
	@ViewBuilder let content: () -> Content

	var body: some View {
		ScrollView(.vertical, showsIndicators: showsIndicators) {
			content()
				.frame(maxWidth: .infinity)
				.containerRelativeFrame(.horizontal)
		}
	}
}

#if DEBUG
	#Preview {
		VerticalOnlyScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Text("A very long single line of text that would otherwise make a vertical scroll view pan sideways on a narrow phone.")
					.font(.title2)
				Text("It wraps instead.")
			}
			.padding()
		}
	}
#endif

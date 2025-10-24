import SFSafeSymbols
import SwiftUI
import UIKit

/// A text view that can be copied to clipboard via tap or long-press context menu
///
/// Features:
/// - Tap gesture to copy text immediately to clipboard
/// - Long-press context menu with "Copy" option
/// - Haptic feedback on copy action
/// - Completion handler for parent view notifications (e.g., showing toast)
/// - Full accessibility support with proper labels and hints
///
/// **Appearance:**
/// - Maintains original text styling from parent
/// - Visual feedback on tap (subtle scale animation)
/// - Context menu with SF Symbol icon
///
/// **Use Cases:**
/// - Copyable medication clinical names
/// - Copyable reference numbers or IDs
/// - Any text that users might need to copy
/// - Medical record displays
/// - Technical information that needs to be shared
struct CopyableText: View {
	let text: String
	let font: Font
	let weight: Font.Weight?
	let color: Color
	var onCopied: (() -> Void)?

	@Environment(\.fontFamily) private var fontFamily
	@State private var isPressed = false
	private let hapticsManager = HapticsManager.shared

	init(
		_ text: String,
		font: Font,
		weight: Font.Weight? = nil,
		color: Color = .secondary,
		onCopied: (() -> Void)? = nil
	) {
		self.text = text
		self.font = font
		self.weight = weight
		self.color = color
		self.onCopied = onCopied
	}

	var body: some View {
		Text(text)
			.font(font)
			.fontWeight(weight)
			.foregroundStyle(color)
			.noTruncate()
			.scaleEffect(isPressed ? 0.98 : 1.0)
			.animation(.easeInOut(duration: 0.1), value: isPressed)
			.contentShape(Rectangle())
			.onTapGesture {
				copyToClipboard()
			}
			.contextMenu {
				Button {
					copyToClipboard()
				} label: {
					Label("Copy", systemSymbol: .docOnDoc)
				}
			}
			.accessibilityLabel("\(text)")
			.accessibilityHint("Tap to copy clinical name to clipboard")
			.accessibilityAddTraits(.isButton)
	}

	// MARK: - Private Methods

	private func copyToClipboard() {
		withAnimation(.easeInOut(duration: 0.1)) {
			isPressed = true
		}

		UIPasteboard.general.string = text
		hapticsManager.mediumImpact()
		onCopied?()

		Task { @MainActor in
			try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
			withAnimation(.easeInOut(duration: 0.1)) {
				isPressed = false
			}
		}
	}
}

#if DEBUG
	#Preview("Copyable Text") {
		VStack(spacing: 20) {
			VStack(alignment: .leading, spacing: 8) {
				Text("Display Name")
					.font(.headline)
					.fontWeight(.bold)

				CopyableText(
					"Albuterol Sulfate HFA",
					font: .caption,
					color: .secondary
				) {
					print("Clinical name copied!")
				}
			}

			Divider()

			VStack(alignment: .leading, spacing: 8) {
				Text("Long Clinical Name")
					.font(.headline)
					.fontWeight(.bold)

				CopyableText(
					"Acetaminophen and Hydrocodone Bitartrate Extended-Release",
					font: .caption,
					color: .secondary
				) {
					print("Long clinical name copied!")
				}
			}
		}
		.padding()
	}
#endif

import SFSafeSymbols
import SwiftUI
import UIKit

/// A text view that can be copied to clipboard via a long press.
///
/// Features:
/// - Long press to copy, with a separate optional tap action
/// - Inline "Copied to Clipboard!" confirmation message
/// - Haptic feedback on copy action
/// - Completion handler for parent view notifications
/// - Full accessibility support with proper labels and hints
///
/// **Appearance:**
/// - Maintains original text styling from parent
/// - Visual feedback on tap (subtle scale animation)
/// - Text temporarily changes to "Copied to Clipboard!" with accent color for 2.5 seconds
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
	var onTap: (() -> Void)?
	var onCopied: (() -> Void)?

	@Environment(\.fontFamily) private var fontFamily
	@State private var isPressed = false
	@State private var showCopiedMessage = false
	private let hapticsManager = HapticsManager.shared

	init(
		_ text: String,
		font: Font,
		weight: Font.Weight? = nil,
		color: Color = .secondary,
		onTap: (() -> Void)? = nil,
		onCopied: (() -> Void)? = nil
	) {
		self.text = text
		self.font = font
		self.weight = weight
		self.color = color
		self.onTap = onTap
		self.onCopied = onCopied
	}

	var body: some View {
		Text(showCopiedMessage ? "Copied to Clipboard!" : text)
			.font(font)
			.fontWeight(weight)
			.foregroundStyle(showCopiedMessage ? .accent : color)
			.noTruncate()
			.demoNameRedacted()
			.scaleEffect(isPressed ? 0.98 : 1.0)
			.animation(.easeInOut(duration: 0.1), value: isPressed)
			.animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCopiedMessage)
			.contentShape(Rectangle())
			.gesture(
				LongPressGesture(minimumDuration: 0.5)
					.exclusively(before: TapGesture())
					.onEnded { result in
						switch result {
						case .first(true): copyToClipboard()
						case .second: onTap?()
						default: break
						}
					}
			)
			.accessibilityLabel("\(showCopiedMessage ? "Copied to Clipboard" : text)")
			.accessibilityHint(onTap == nil ? "Activate to copy name to clipboard" : "Activate to view medication details. Use Copy name to copy to clipboard")
			.accessibilityAddTraits(.isButton)
			.accessibilityAction { Self.activate(onTap: onTap, copy: copyToClipboard) }
			.accessibilityAction(named: "Copy name") { copyToClipboard() }
	}

	/// Assistive activation must always perform the control's primary action.
	static func activate(onTap: (() -> Void)?, copy: () -> Void) {
		if let onTap {
			onTap()
		} else {
			copy()
		}
	}

	// MARK: - Private Methods

	private func copyToClipboard() {
		withAnimation(.easeInOut(duration: 0.1)) {
			isPressed = true
		}

		UIPasteboard.general.string = text
		hapticsManager.mediumImpact()
		onCopied?()

		// Show "Copied to Clipboard!" message
		withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
			showCopiedMessage = true
		}

		Task { @MainActor in
			try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
			withAnimation(.easeInOut(duration: 0.1)) {
				isPressed = false
			}

			// Hide message after 2.5 seconds
			try? await Task.sleep(nanoseconds: 2_500_000_000)
			withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
				showCopiedMessage = false
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

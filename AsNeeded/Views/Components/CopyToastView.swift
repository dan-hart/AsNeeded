import SFSafeSymbols
import SwiftUI

/// A compact toast notification for copy confirmation
///
/// **Appearance:**
/// - Compact top-aligned toast with glass morphism
/// - Checkmark success indicator
/// - Clear "Copied" message
/// - Manual dismiss button
/// - Auto-dismiss after 2.5 seconds
///
/// **Use Cases:**
/// - Copy action confirmations
/// - Clinical name copy feedback
/// - Non-intrusive success messages
/// - Clipboard operation feedback
struct CopyToastView: View {
	let message: String
	let isVisible: Bool
	let onDismiss: () -> Void

	@Environment(\.fontFamily) private var fontFamily
	@ScaledMetric private var toastPadding: CGFloat = 16
	@ScaledMetric private var contentSpacing: CGFloat = 12
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var dismissButtonSize: CGFloat = 28
	@ScaledMetric private var toastCornerRadius: CGFloat = 16
	@ScaledMetric private var topPadding: CGFloat = 60

	var body: some View {
		if isVisible {
			VStack {
				HStack(spacing: contentSpacing) {
					// Success checkmark
					Image(systemSymbol: .checkmarkCircleFill)
						.font(.customFont(fontFamily, style: .title3))
						.foregroundStyle(.accent)
						.symbolEffect(.bounce, value: isVisible)

					// Message content
					VStack(alignment: .leading, spacing: 2) {
						Text("Copied")
							.font(.customFont(fontFamily, style: .caption, weight: .semibold))
							.foregroundStyle(.secondary)

						Text(message)
							.font(.customFont(fontFamily, style: .subheadline, weight: .bold))
							.foregroundStyle(.primary)
							.lineLimit(2)
					}

					Spacer(minLength: 8)

					// Dismiss button
					Button(action: onDismiss) {
						Image(systemSymbol: .xmark)
							.font(.customFont(fontFamily, style: .caption, weight: .semibold))
							.foregroundStyle(.secondary)
							.frame(width: dismissButtonSize, height: dismissButtonSize)
							.contentShape(Circle())
					}
					.buttonStyle(.plain)
					.accessibilityLabel("Dismiss")
				}
				.padding(toastPadding)
				.background(
					RoundedRectangle(cornerRadius: toastCornerRadius, style: .continuous)
						.fill(.regularMaterial)
						.shadow(color: .black.opacity(0.1), radius: 12, y: 4)
						.overlay(
							RoundedRectangle(cornerRadius: toastCornerRadius, style: .continuous)
								.strokeBorder(
									LinearGradient(
										colors: [.white.opacity(0.5), .clear],
										startPoint: .topLeading,
										endPoint: .bottomTrailing
									),
									lineWidth: 0.5
								)
						)
				)
				.padding(.horizontal, toastPadding)
				.padding(.top, topPadding)

				Spacer()
			}
			.transition(.move(edge: .top).combined(with: .opacity))
			.animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
			.zIndex(10000)
			.ignoresSafeArea()
		}
	}
}

#if DEBUG
	#Preview("Copy Toast") {
		ZStack {
			Color(.systemGroupedBackground)
				.ignoresSafeArea()

			CopyToastView(
				message: "Clinical name copied",
				isVisible: true,
				onDismiss: {}
			)
		}
	}

	#Preview("Copy Toast - Long Text") {
		ZStack {
			Color(.systemGroupedBackground)
				.ignoresSafeArea()

			CopyToastView(
				message: "Acetaminophen and Hydrocodone Bitartrate",
				isVisible: true,
				onDismiss: {}
			)
		}
	}
#endif

import SwiftUI
import SFSafeSymbols

/// A compact toast notification for quick dose logging confirmation
///
/// **Appearance:**
/// - Compact top-aligned toast with glass morphism
/// - Checkmark success indicator
/// - Medication-themed color accent
/// - Manual dismiss button
/// - Auto-dismiss after 3 seconds
///
/// **Use Cases:**
/// - Quick action confirmations
/// - Medication dose logging feedback
/// - Non-intrusive success messages
struct QuickLogToastView: View {
	let medicationName: String
	let doseAmount: Double
	let doseUnit: String
	let accentColor: Color
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
						.font(.system(size: iconSize))
						.foregroundStyle(accentColor)
						.symbolEffect(.bounce, value: isVisible)

					// Message content
					VStack(alignment: .leading, spacing: 4) {
						Text("Logged")
							.font(.customFont(fontFamily, style: .caption, weight: .semibold))
							.foregroundStyle(.secondary)

						Text(formattedDose)
							.font(.customFont(fontFamily, style: .subheadline, weight: .bold))
							.foregroundStyle(.primary)
							.lineLimit(1)

						Text(medicationName)
							.font(.customFont(fontFamily, style: .caption, weight: .medium))
							.foregroundStyle(.secondary)
							.lineLimit(1)
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
			.zIndex(1000)
		}
	}

	// MARK: - Helper Methods
	private var formattedDose: String {
		let amountStr = doseAmount.formattedAmount
		return "\(amountStr) \(doseUnit)"
	}
}

#if DEBUG
#Preview("Quick Log Toast") {
	ZStack {
		Color(.systemGroupedBackground)
			.ignoresSafeArea()

		QuickLogToastView(
			medicationName: "Lisinopril",
			doseAmount: 2,
			doseUnit: "tablets",
			accentColor: .blue,
			isVisible: true,
			onDismiss: {}
		)
	}
}

#Preview("Quick Log Toast - Decimal Dose") {
	ZStack {
		Color(.systemGroupedBackground)
			.ignoresSafeArea()

		QuickLogToastView(
			medicationName: "Albuterol Inhaler",
			doseAmount: 1.5,
			doseUnit: "puffs",
			accentColor: .purple,
			isVisible: true,
			onDismiss: {}
		)
	}
}
#endif

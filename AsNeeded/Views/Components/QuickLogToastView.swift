import SFSafeSymbols
import SwiftUI

/// A compact toast notification for quick dose logging confirmation
///
/// **Appearance:**
/// - Compact top-aligned toast with glass morphism
/// - Checkmark success indicator
/// - Medication-themed color accent
/// - Manual dismiss button
/// - Scrollable details with persistent dismiss and undo controls
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
	var feedback: QuickLogFeedbackService.Feedback?
	let onDismiss: () -> Void
	var onUndo: (() -> Void)?

	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	private let toastPadding: CGFloat = 16
	private let contentSpacing: CGFloat = 12
	@ScaledMetric private var iconSize: CGFloat = 24
	private let dismissButtonSize: CGFloat = 44
	private let toastCornerRadius: CGFloat = 16
	private let topPadding: CGFloat = 60

	var body: some View {
		if isVisible {
			GeometryReader { geometry in
				let topInset = min(topPadding, geometry.size.height * 0.1)
				VStack {
					VStack(alignment: .leading, spacing: contentSpacing) {
						HStack(alignment: .top, spacing: contentSpacing) {
							Image(systemSymbol: toneIcon)
								.font(.customFont(fontFamily, style: .title3))
								.foregroundStyle(toneColor)
								.accessibilityHidden(true)

							Spacer(minLength: 8)

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

						ViewThatFits(in: .vertical) {
							messageContent
							ScrollView {
								messageContent
							}
							.scrollBounceBehavior(.basedOnSize)
						}
						.frame(maxHeight: max(32, (geometry.size.height - topInset) * 0.5 - 100))

						if feedback?.undoEventID != nil, let onUndo {
							Button {
								onUndo()
							} label: {
								Label("Undo log", systemSymbol: .arrowCounterclockwise)
									.font(.customFont(fontFamily, style: .caption, weight: .semibold))
									.foregroundStyle(toneColor.dynamicFilledButtonForeground)
									.frame(maxWidth: .infinity)
									.padding(.vertical, 8)
									.frame(minHeight: 44)
									.background(
										RoundedRectangle(cornerRadius: 10, style: .continuous)
											.fill(toneColor.dynamicFilledButtonBackground)
									)
							}
							.buttonStyle(.plain)
							.accessibilityHint("Removes the dose event and restores the medication quantity")
						}
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
					.padding(.top, topInset)

					Spacer()
				}
			}
			.transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
			.animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
			.zIndex(1000)
			.accessibilityElement(children: .contain)
		}
	}

	// MARK: - Helper Methods

	private var messageContent: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(titleText)
				.font(.customFont(fontFamily, style: .caption, weight: .semibold))
				.foregroundStyle(toneColor)
			Text(messageText)
				.font(.customFont(fontFamily, style: .subheadline, weight: .bold))
				.foregroundStyle(.primary)
				.noTruncate()
			Text(detailText)
				.font(.customFont(fontFamily, style: .caption, weight: .medium))
				.foregroundStyle(.secondary)
				.noTruncate()
			if let nextWindowText = feedback?.nextWindowText {
				Text(nextWindowText)
					.font(.customFont(fontFamily, style: .caption, weight: .semibold))
					.foregroundStyle(toneColor)
					.noTruncate()
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .combine)
	}

	private var formattedDose: String {
		let amountStr = doseAmount.formattedAmount
		return "\(amountStr) \(doseUnit)"
	}

	private var titleText: String {
		feedback?.title ?? "Logged"
	}

	private var messageText: String {
		feedback?.message ?? formattedDose
	}

	private var detailText: String {
		if let feedback {
			return feedback.detail
		}

		return medicationName
	}

	private var toneColor: Color {
		guard let feedback else { return accentColor }

		switch feedback.tone {
		case .success:
			return accentColor
		case .caution:
			return .orange
		case .warning:
			return .red
		}
	}

	private var toneIcon: SFSymbol {
		guard let feedback else { return .checkmarkCircleFill }

		switch feedback.tone {
		case .success:
			return .checkmarkCircleFill
		case .caution:
			return .exclamationmarkTriangleFill
		case .warning:
			return .exclamationmarkTriangleFill
		}
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

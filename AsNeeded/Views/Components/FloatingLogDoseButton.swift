import ANModelKit
import SFSafeSymbols
import SwiftUI
import TipKit

/// The same chooser and context-specific quick-log action on each logging tab.
struct FloatingLogDoseButton: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	let quickLogMedication: ANMedicationConcept?
	var tint: Color = .accent
	let scrollState: FloatingLogDoseScrollState
	let onChoose: () -> Void
	let onQuickLog: (() async -> Bool)?
	var onSuccess: () -> Void = {}
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.colorSchemeContrast) private var contrast
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isPressed = false
	@State private var isLongPressing = false
	@State private var holdProgress: Double = 0
	@ScaledMetric(relativeTo: .headline) private var iconButtonSize: CGFloat = 58

	var body: some View {
		let isCollapsed = scrollState.isCollapsed
		let palette = tint.filledButtonColors(for: colorScheme, contrast: contrast)
		Button(action: choose) {
			FloatingLogDoseLabel(expansion: isCollapsed ? 0 : 1, minimumSize: iconButtonSize)
			.font(.customFont(fontFamily, style: .headline, weight: .semibold))
			.foregroundStyle(palette.foreground)
			.clipShape(Capsule())
			.background(palette.background, in: Capsule())
			.contentShape([.interaction, .accessibility], Capsule())
			.doseLogHoldRing(Capsule(), color: palette.foreground,
				isHolding: isPressed && onQuickLog != nil, progress: holdProgress)
			.shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
			.animation(reduceMotion ? nil : .smooth(duration: 0.3), value: isCollapsed)
		}
		.buttonStyle(.plain)
		.scaleEffect(reduceMotion ? 1 : (isPressed || isLongPressing ? 0.95 : 1))
		.doseLogPressGesture(isPressed: $isPressed, isLongPressing: $isLongPressing,
			holdProgress: $holdProgress, onTap: choose, onQuickLog: onQuickLog,
			onQuickLogSuccess: succeeded, onHoldWithoutQuickLog: choose)
		.accessibilityLabel("Log dose")
		.accessibilityHint(quickLogMedication.map { String(localized: "Choose a medication, or hold to log the default dose for \($0.demoDisplayName)") } ?? String(localized: "Choose a medication to record a dose"))
		.accessibilityActions {
			if let medication = quickLogMedication, let onQuickLog {
				Button("Quick log default dose for \(medication.demoDisplayName)") {
					Task { if await onQuickLog() { succeeded() } }
				}
			}
		}
		.popoverTip(AppTips.isConfigured ? LogDoseTip() : nil)
		// Replacing the target cancels an unfinished hold through the gesture's onDisappear.
		.id(quickLogMedication?.id)
		.padding(.trailing, 20)
		.padding(.bottom, 16)
	}

	private func choose() {
		AppTips.didOpenDosePicker()
		onChoose()
	}

	private func succeeded() {
		AppTips.didQuickLog()
		onSuccess()
	}
}

/// Drive the capsule and its label from the same animation value.
private struct FloatingLogDoseLabel: View, Animatable {
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	nonisolated var expansion: CGFloat
	let minimumSize: CGFloat

	nonisolated var animatableData: CGFloat {
		get { expansion }
		set { expansion = newValue }
	}

	var body: some View {
		let progress = min(1, max(0, expansion))
		// Fade while there is room for the full label.
		let fadeStart: CGFloat = 0.8
		FloatingLogDoseLabelLayout(expansion: progress, minimumSize: minimumSize) {
			Image(systemSymbol: .plusCircleFill)
			Text("Log Dose")
				.lineLimit(1)
				.fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
				.opacity(max(0, (progress - fadeStart) / (1 - fadeStart)))
		}
	}
}

private struct FloatingLogDoseLabelLayout: Layout {
	let expansion: CGFloat
	let minimumSize: CGFloat
	private let horizontalPadding: CGFloat = 28
	private let verticalPadding: CGFloat = 18
	private let spacing: CGFloat = 8

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		let (icon, title) = sizes(for: proposal, subviews: subviews)
		let height = max(minimumSize, max(icon.height, title.height) + 2 * verticalPadding)
		let width = max(height, icon.width + spacing + title.width + 2 * horizontalPadding)
		return CGSize(width: height + (width - height) * expansion, height: height)
	}

	func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
		let (icon, title) = sizes(for: proposal, subviews: subviews)
		let compactInset = (bounds.height - icon.width) / 2
		let iconX = bounds.minX + compactInset + (horizontalPadding - compactInset) * expansion
		subviews[0].place(at: CGPoint(x: iconX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(icon))
		subviews[1].place(at: CGPoint(x: iconX + icon.width + spacing, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(title))
	}

	private func sizes(for proposal: ProposedViewSize, subviews: Subviews) -> (icon: CGSize, title: CGSize) {
		let icon = subviews[0].sizeThatFits(.unspecified)
		let labelWidth = proposal.width.flatMap { availableWidth -> CGFloat? in
			let remainingWidth = availableWidth - icon.width - spacing - 2 * horizontalPadding
			// Keep the title at its ideal size for a layout probe of the compact button.
			return remainingWidth >= minimumSize ? remainingWidth : nil
		}
		let title = subviews[1].sizeThatFits(ProposedViewSize(width: labelWidth, height: nil))
		return (icon, title)
	}
}

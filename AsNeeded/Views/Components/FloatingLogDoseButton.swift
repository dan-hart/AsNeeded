import ANModelKit
import SFSafeSymbols
import SwiftUI
import TipKit

/// The same chooser and context-specific quick-log action on each logging tab.
struct FloatingLogDoseButton: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	let quickLogMedication: ANMedicationConcept?
	var tint: Color = .accent
	var isCollapsed = false
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
		let palette = tint.filledButtonColors(for: colorScheme, contrast: contrast)
		Button(action: choose) {
			HStack(spacing: 8) {
				Image(systemSymbol: .plusCircleFill)
				if !isCollapsed {
					Text("Log Dose")
						.transition(.opacity)
				}
			}
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.foregroundStyle(palette.foreground)
				.padding(.horizontal, isCollapsed ? 0 : 28)
				.padding(.vertical, isCollapsed ? 0 : 18)
				.frame(width: isCollapsed ? iconButtonSize : nil, height: isCollapsed ? iconButtonSize : nil)
				.background(palette.background, in: Capsule())
				.doseLogHoldRing(Capsule(), color: palette.foreground,
					isHolding: isPressed && onQuickLog != nil, progress: holdProgress)
				.shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
				.animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isCollapsed)
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

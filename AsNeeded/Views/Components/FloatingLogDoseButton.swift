import ANModelKit
import SFSafeSymbols
import SwiftUI
import TipKit

/// The same chooser and context-specific quick-log action on each logging tab.
struct FloatingLogDoseButton: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	let quickLogMedication: ANMedicationConcept?
	var tint: Color = .accent
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

	var body: some View {
		let palette = tint.filledButtonColors(for: colorScheme, contrast: contrast)
		Button(action: choose) {
			Label("Log Dose", systemSymbol: .plusCircleFill)
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.foregroundStyle(palette.foreground)
				.padding(.horizontal, 28)
				.padding(.vertical, 18)
				.background(palette.background, in: Capsule())
				.overlay {
					Capsule().trim(from: 0, to: holdProgress)
						.stroke(palette.foreground, lineWidth: 3)
						.padding(2).allowsHitTesting(false).accessibilityHidden(true)
				}
				.shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
		}
		.buttonStyle(.plain)
		.scaleEffect(reduceMotion ? 1 : (isPressed || isLongPressing ? 0.95 : 1))
		.doseLogPressGesture(isPressed: $isPressed, isLongPressing: $isLongPressing,
			holdProgress: $holdProgress, onTap: choose, onQuickLog: onQuickLog ?? {
				choose()
				return false
			},
			onQuickLogSuccess: succeeded)
		.accessibilityLabel("Log dose")
		.accessibilityHint(quickLogMedication.map { "Choose a medication, or hold to log the default dose for \($0.demoDisplayName)" } ?? "Choose a medication to record a dose")
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

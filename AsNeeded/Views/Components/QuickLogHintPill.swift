// QuickLogHintPill.swift
// The "Hold to log …" hint shown next to Log Dose controls, and the modifier that decides when to show it.

import SFSafeSymbols
import SwiftUI

/// Small neutral pill that names the dose a hold will log, placed next to a Log Dose control.
///
/// **Features:**
/// - Material capsule so it never competes with the medication-colored control beside it
/// - Hand icon bounces a few times on appearance to draw the eye; still under Reduce Motion
/// - Slides in from the control's edge; fades only under Reduce Motion
/// - Hidden from VoiceOver, because every Log Dose control already describes the hold in its hint
///
/// **Use Cases:**
/// - Above the floating Log Dose button on the History tab
/// - Above the first row's LOG button on the Medication tab
struct QuickLogHintPill: View {
	let text: String

	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var bounceTrigger = 0

	@ScaledMetric private var iconSpacing: CGFloat = 6
	@ScaledMetric private var paddingH: CGFloat = 12
	@ScaledMetric private var paddingV: CGFloat = 8

	var body: some View {
		HStack(spacing: iconSpacing) {
			icon
			Text(text)
		}
		.font(.customFont(fontFamily, style: .caption, weight: .medium))
		.foregroundStyle(.primary)
		.padding(.horizontal, paddingH)
		.padding(.vertical, paddingV)
		.background(.regularMaterial, in: Capsule())
		.accessibilityHidden(true)
		.transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
		.onAppear {
			bounceTrigger += 1
		}
	}

	@ViewBuilder
	private var icon: some View {
		if reduceMotion {
			Image(systemSymbol: .handTapFill)
		} else {
			Image(systemSymbol: .handTapFill)
				.symbolEffect(.bounce, options: .repeat(3), value: bounceTrigger)
		}
	}
}

/// Shows a quick log hint for one appearance of a control when `QuickLogHintPolicy` allows, after a short
/// pause so it reads as a nudge rather than part of the layout. Runs from `.task`, so leaving the screen
/// during the pause cancels it; the policy is rechecked after the pause so a quick log in the meantime is
/// respected, and an impression only counts once the hint is actually shown.
struct QuickLogHintPresenter: ViewModifier {
	@Binding var isPresented: Bool

	@AppStorage(UserDefaultsKeys.hasDiscoveredQuickLog) private var hasDiscoveredQuickLog = false
	@AppStorage(UserDefaultsKeys.quickLogHintImpressions) private var impressions = 0
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	func body(content: Content) -> some View {
		content
			.task {
				await presentIfAllowed()
			}
			.onDisappear {
				isPresented = false
			}
	}

	private func presentIfAllowed() async {
		guard QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: hasDiscoveredQuickLog, impressions: impressions) else {
			return
		}

		do {
			try await Task.sleep(for: .milliseconds(600))
		} catch {
			return
		}

		guard QuickLogHintPolicy.shouldShow(hasDiscoveredQuickLog: hasDiscoveredQuickLog, impressions: impressions) else {
			return
		}

		impressions += 1
		withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
			isPresented = true
		}
	}
}

extension View {
	/// Presents a quick log hint through `isPresented` for this appearance when the policy allows.
	/// See `QuickLogHintPresenter`.
	func quickLogHint(isPresented: Binding<Bool>) -> some View {
		modifier(QuickLogHintPresenter(isPresented: isPresented))
	}
}

#if DEBUG
	#Preview {
		QuickLogHintPill(text: "Hold to log 1 tablet")
			.padding()
	}
#endif

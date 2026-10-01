// QuickLogHintPill.swift
// The "Hold to log …" hint shown next to Log Dose controls, and the modifier that decides when to show it.

import SFSafeSymbols
import SwiftUI

/// Small neutral pill that names the dose a hold will log, placed next to a Log Dose control.
///
/// **Features:**
/// - Material capsule so it never competes with the medication-colored control beside it
/// - Hand icon bounces a few times on appearance to draw the eye; still under Reduce Motion
/// - Dismiss button so the user can retire the hint for good without performing the hold
/// - Slides in from the control's edge; fades only under Reduce Motion
/// - Hidden from VoiceOver unless it has a close button, because every Log Dose control already describes the hold in its hint
///
/// **Use Cases:**
/// - Above the floating Log Dose button on the History tab
/// - Floating above the first row's LOG button on the Medication tab (see `QuickLogHintAnchorKey`)
struct QuickLogHintPill: View {
	let text: String
	/// Called when the user taps the pill's close button. The caller hides the pill and retires the hint.
	var onDismiss: (() -> Void)? = nil

	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var bounceTrigger = 0

	@ScaledMetric private var iconSpacing: CGFloat = 6
	@ScaledMetric private var paddingLeading: CGFloat = 12
	@ScaledMetric private var paddingV: CGFloat = 8
	@ScaledMetric private var dismissPadding: CGFloat = 8
	@ScaledMetric private var dismissTrailingInset: CGFloat = 4

	var body: some View {
		HStack(spacing: iconSpacing) {
			icon
			Text(text)

			if let onDismiss {
				Button(action: onDismiss) {
					Image(systemSymbol: .xmark)
						.font(.customFont(fontFamily, style: .caption2, weight: .bold))
						.foregroundStyle(.secondary)
						.padding(dismissPadding)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Dismiss hint")
			}
		}
		.font(.customFont(fontFamily, style: .caption, weight: .medium))
		.foregroundStyle(.primary)
		.padding(.leading, paddingLeading)
		.padding(.trailing, onDismiss == nil ? paddingLeading : dismissTrailingInset)
		.padding(.vertical, onDismiss == nil ? paddingV : 0)
		.background(.regularMaterial, in: Capsule())
		// Every Log Dose control already describes the hold to VoiceOver, so the pill is only exposed when
		// it carries the close button, which VoiceOver users need in order to retire the hint.
		.accessibilityHidden(onDismiss == nil)
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

/// Frame of the Log Dose control the hint should float above, published by a list row so the list can
/// draw the pill in its own overlay. Drawing it there keeps the pill from being clipped by the row.
struct QuickLogHintAnchorKey: PreferenceKey {
	static let defaultValue: Anchor<CGRect>? = nil

	static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
		value = nextValue() ?? value
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

	/// Floats a `QuickLogHintPill` above (or, near the top edge, below) the control that published
	/// `QuickLogHintAnchorKey`, trailing-aligned with it. Draw this on the scroll container, not the row.
	func quickLogHintOverlay(isPresented: Bool, text: String, onDismiss: @escaping () -> Void) -> some View {
		modifier(QuickLogHintOverlay(isPresented: isPresented, text: text, onDismiss: onDismiss))
	}
}

/// Positions the hint relative to the anchored control in the container's coordinate space.
struct QuickLogHintOverlay: ViewModifier {
	let isPresented: Bool
	let text: String
	let onDismiss: () -> Void

	@ScaledMetric private var spacing: CGFloat = 8
	/// Roughly the pill's height plus `spacing`. With less room than this above the control, the pill
	/// would poke out past the container's top edge, so it goes underneath instead.
	@ScaledMetric private var minimumRoomAbove: CGFloat = 36

	func body(content: Content) -> some View {
		content.overlayPreferenceValue(QuickLogHintAnchorKey.self) { anchor in
			GeometryReader { proxy in
				if isPresented, let anchor {
					let rect = proxy[anchor]
					let placeAbove = rect.minY >= minimumRoomAbove
					// Plain values for the alignment closures, which must not capture the proxy or the view.
					let trailingInset = proxy.size.width - rect.maxX
					let bottomEdgeWhenAbove = rect.minY - spacing
					let topEdgeWhenBelow = rect.maxY + spacing
					ZStack(alignment: .topTrailing) {
						Color.clear
							.allowsHitTesting(false)

						QuickLogHintPill(text: text, onDismiss: onDismiss)
							.fixedSize()
							.alignmentGuide(.trailing) { dimensions in
								dimensions[.trailing] + trailingInset
							}
							.alignmentGuide(.top) { dimensions in
								placeAbove
									? dimensions[.bottom] - bottomEdgeWhenAbove
									: dimensions[.top] - topEdgeWhenBelow
							}
					}
				}
			}
		}
	}
}

#if DEBUG
	#Preview {
		VStack(spacing: 24) {
			QuickLogHintPill(text: "Hold to log 1 tablet")
			QuickLogHintPill(text: "Hold to log 1 tablet", onDismiss: {})
		}
		.padding()
	}
#endif

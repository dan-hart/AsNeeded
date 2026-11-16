import Observation
import SwiftUI

/// Only a change in the button's presentation needs to invalidate a view.
@MainActor
@Observable
final class FloatingLogDoseScrollState {
	private(set) var isCollapsed = false
	@ObservationIgnored private var anchor: CGFloat?
	private let collapseDistance: CGFloat = 16
	private let expandDistance: CGFloat = 44

	func begin(at offset: CGFloat) {
		anchor = offset
	}

	func end() {
		anchor = nil
	}

	func reset() {
		end()
		if isCollapsed { isCollapsed = false }
	}

	func update(at offset: CGFloat) {
		guard let anchor else { return }
		let reference = isCollapsed ? max(anchor, offset) : min(anchor, offset)
		let distance = isCollapsed ? reference - offset : offset - reference
		if distance >= (isCollapsed ? expandDistance : collapseDistance) {
			self.anchor = offset
			isCollapsed.toggle()
		} else {
			self.anchor = reference
		}
	}
}

extension View {
	/// Apply directly to the vertical List or ScrollView that the button accompanies.
	func collapsesFloatingLogDose(_ scrollState: FloatingLogDoseScrollState) -> some View {
		onScrollGeometryChange(for: CGFloat.self, of: Self.floatingLogDoseOffset) { _, offset in
			scrollState.update(at: offset)
		}
		.onScrollPhaseChange { _, phase, context in
			if phase == .interacting {
				scrollState.begin(at: Self.floatingLogDoseOffset(context.geometry))
			} else {
				// A rebound after the user lifts their finger is momentum, not a reversal.
				scrollState.end()
			}
		}
		.onDisappear { scrollState.reset() }
	}

	private static func floatingLogDoseOffset(_ geometry: ScrollGeometry) -> CGFloat {
		let offset = geometry.contentOffset.y + geometry.contentInsets.top
		let range = geometry.contentSize.height + geometry.contentInsets.top
			+ geometry.contentInsets.bottom - geometry.containerSize.height
		// Ignore rubber-banding at both ends.
		return min(max(0, offset), max(0, range))
	}
}

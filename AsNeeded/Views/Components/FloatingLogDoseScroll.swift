import SwiftUI

/// Tracks deliberate scroll direction without switching the button on small reversals.
struct FloatingLogDoseScrollDirection {
	private var anchor: CGFloat?
	private let threshold: CGFloat = 16

	mutating func begin(at offset: CGFloat) {
		anchor = offset
	}

	mutating func end() {
		anchor = nil
	}

	mutating func update(at offset: CGFloat, isCollapsed: Bool) -> Bool {
		if offset == 0 {
			if anchor != nil { anchor = 0 }
			return false
		}
		guard let anchor else { return isCollapsed }
		let reference = isCollapsed ? max(anchor, offset) : min(anchor, offset)
		let distance = isCollapsed ? reference - offset : offset - reference
		if distance >= threshold {
			self.anchor = offset
			return !isCollapsed
		}
		self.anchor = reference
		return isCollapsed
	}
}

extension View {
	/// Apply directly to the vertical List or ScrollView that the button accompanies.
	func collapsesFloatingLogDose(_ isCollapsed: Binding<Bool>) -> some View {
		modifier(FloatingLogDoseScrollModifier(isCollapsed: isCollapsed))
	}
}

private struct FloatingLogDoseScrollModifier: ViewModifier {
	@Binding var isCollapsed: Bool
	@State private var direction = FloatingLogDoseScrollDirection()

	func body(content: Content) -> some View {
		content
			.onScrollGeometryChange(for: CGFloat.self, of: Self.offset) { _, offset in
				let collapsed = direction.update(at: offset, isCollapsed: isCollapsed)
				if collapsed != isCollapsed { isCollapsed = collapsed }
			}
			.onScrollPhaseChange { _, phase, context in
				switch phase {
					case .interacting:
						direction.begin(at: Self.offset(context.geometry))
					case .decelerating:
						break
					default:
						direction.end()
				}
			}
			.onDisappear { isCollapsed = false }
	}

	private static func offset(_ geometry: ScrollGeometry) -> CGFloat {
		let offset = geometry.contentOffset.y + geometry.contentInsets.top
		let range = geometry.contentSize.height + geometry.contentInsets.top
			+ geometry.contentInsets.bottom - geometry.containerSize.height
		// Ignore rubber-banding at both ends.
		return min(max(0, offset), max(0, range))
	}
}

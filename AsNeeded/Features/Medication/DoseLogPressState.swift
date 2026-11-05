import Foundation

/// Deterministic press decisions shared by every quick-log control.
struct DoseLogPressState {
	enum Phase { case idle, pressing, cancelled, triggered }
	private(set) var phase: Phase = .idle

	mutating func begin() -> Bool {
		guard phase == .idle else { return false }
		phase = .pressing
		return true
	}

	mutating func move(horizontal: Double, vertical: Double) -> Bool {
		guard phase == .pressing, abs(horizontal) > 10 || abs(vertical) > 10 else { return false }
		phase = .cancelled
		return true
	}

	mutating func reachThreshold() -> Bool {
		guard phase == .pressing else { return false }
		phase = .triggered
		return true
	}

	mutating func release() -> Bool {
		let shouldOpen = phase == .pressing
		phase = .idle
		return shouldOpen
	}

	mutating func cancel() { phase = .idle }
}

@testable import AsNeeded
import Foundation
import Observation
import Synchronization
import Testing

@MainActor
struct FloatingLogDoseScrollTests {
	@Test("Scroll direction collapses and expands only after a deliberate movement")
	func directionChanges() {
		let scrollState = FloatingLogDoseScrollState()
		scrollState.begin(at: 0)
		let offsets: [CGFloat] = [15, 16, 80, 50, 37, 36, 45]
		let states = offsets.map { offset in
			scrollState.update(at: offset)
			return scrollState.isCollapsed
		}
		#expect(states == [false, true, true, true, true, false, false])
	}

	@Test("Momentum and programmatic jumps preserve the current button size")
	func momentumAndProgrammaticJumps() {
		let scrollState = FloatingLogDoseScrollState()
		scrollState.update(at: 100)
		#expect(!scrollState.isCollapsed)
		scrollState.begin(at: 100)
		scrollState.update(at: 125)
		#expect(scrollState.isCollapsed)
		scrollState.end()
		scrollState.update(at: 50)
		#expect(scrollState.isCollapsed)
		scrollState.update(at: 0)
		#expect(scrollState.isCollapsed)
		scrollState.reset()
		#expect(!scrollState.isCollapsed)
	}

	@Test("A bottom rebound and a short upward drag keep the button compact")
	func bottomBounceAndUpwardDrag() {
		let scrollState = FloatingLogDoseScrollState()
		scrollState.begin(at: 600)
		scrollState.update(at: 825)
		#expect(scrollState.isCollapsed)
		scrollState.end()
		scrollState.update(at: 1_000)
		scrollState.update(at: 930)
		#expect(scrollState.isCollapsed)

		scrollState.begin(at: 930)
		scrollState.update(at: 907)
		#expect(scrollState.isCollapsed)
		scrollState.end()
		scrollState.begin(at: 907)
		scrollState.update(at: 863)
		#expect(!scrollState.isCollapsed)
	}

	@Test("Scroll samples only publish changes when the button changes size")
	func publishesOnlyPresentationChanges() {
		let scrollState = FloatingLogDoseScrollState()
		let changes = Mutex(0)
		withObservationTracking {
			_ = scrollState.isCollapsed
		} onChange: {
			changes.withLock { $0 += 1 }
		}
		scrollState.begin(at: 10)
		scrollState.update(at: 5)
		scrollState.update(at: 15)
		#expect(changes.withLock { $0 } == 0)
		scrollState.update(at: 25)
		#expect(changes.withLock { $0 } == 1)
	}
}

@testable import AsNeeded
import Foundation
import Testing

struct FloatingLogDoseScrollTests {
	@Test("Scroll direction collapses and expands only after a deliberate movement")
	func directionChanges() {
		var direction = FloatingLogDoseScrollDirection()
		direction.begin(at: 0)
		var isCollapsed = false
		let offsets: [CGFloat] = [15, 16, 36, 21, 20, 25]
		let states = offsets.map { offset in
			isCollapsed = direction.update(at: offset, isCollapsed: isCollapsed)
			return isCollapsed
		}
		#expect(states == [false, true, true, true, false, false])
	}

	@Test("Programmatic jumps preserve the button state except when returning to the top")
	func programmaticJumps() {
		var direction = FloatingLogDoseScrollDirection()
		let whileIdle = direction.update(at: 100, isCollapsed: false)
		#expect(!whileIdle)
		direction.begin(at: 100)
		let whileDragging = direction.update(at: 125, isCollapsed: false)
		#expect(whileDragging)
		direction.end()
		let afterJump = direction.update(at: 50, isCollapsed: true)
		#expect(afterJump)
		let atTop = direction.update(at: 0, isCollapsed: true)
		#expect(!atTop)
	}
}

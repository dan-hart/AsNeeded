@testable import AsNeeded
import Testing

@Suite("Shared dose press decisions")
struct DoseLogPressStateTests {
	@Test("Short press opens the dose form once")
	func tap() {
		var state = DoseLogPressState()
		let started = state.begin()
		#expect(started)
		let repeatBeginIgnored = !state.begin()
		#expect(repeatBeginIgnored)
		let opensForm = state.release()
		#expect(opensForm)
		let duplicateReleaseIgnored = !state.release()
		#expect(duplicateReleaseIgnored)
	}

	@Test("Hold quick logs once and never opens the dose form on release")
	func hold() {
		var state = DoseLogPressState()
		let started = state.begin()
		#expect(started)
		let triggersLog = state.reachThreshold()
		#expect(triggersLog)
		let duplicateThresholdIgnored = !state.reachThreshold()
		#expect(duplicateThresholdIgnored)
		let releaseKeepsFormClosed = !state.release()
		#expect(releaseKeepsFormClosed)
		let nextPressStarts = state.begin()
		#expect(nextPressStarts)
		let nextTapOpensForm = state.release()
		#expect(nextTapOpensForm)
	}

	@Test("Moving outside the tolerance cancels both log actions until release")
	func movementCancels() {
		var state = DoseLogPressState()
		let started = state.begin()
		#expect(started)
		let boundaryMovementAllowed = !state.move(horizontal: 10, vertical: -10)
		#expect(boundaryMovementAllowed)
		let outsideMovementCancels = state.move(horizontal: 0, vertical: -10.1)
		#expect(outsideMovementCancels)
		let cancelledPressCannotRestart = !state.begin()
		#expect(cancelledPressCannotRestart)
		let cancelledHoldCannotLog = !state.reachThreshold()
		#expect(cancelledHoldCannotLog)
		let cancelledReleaseCannotOpen = !state.release()
		#expect(cancelledReleaseCannotOpen)
		let nextPressStarts = state.begin()
		#expect(nextPressStarts)
	}

	@Test("Disappearance prevents a pending hold from logging")
	func disappearanceCancels() {
		var state = DoseLogPressState()
		let started = state.begin()
		#expect(started)
		state.cancel()
		let disappearedHoldCannotLog = !state.reachThreshold()
		#expect(disappearedHoldCannotLog)
		let disappearedReleaseCannotOpen = !state.release()
		#expect(disappearedReleaseCannotOpen)
	}
}

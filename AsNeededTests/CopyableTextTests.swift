@testable import AsNeeded
import Testing

@MainActor
struct CopyableTextTests {
	@Test("VoiceOver activation copies when no navigation action exists")
	func activationWithoutNavigationCopies() {
		var copies = 0
		CopyableText.activate(onTap: nil, copy: { copies += 1 })
		#expect(copies == 1)
	}

	@Test("VoiceOver activation navigates without copying when a tap action exists")
	func activationWithNavigationDoesNotCopy() {
		var taps = 0
		var copies = 0
		CopyableText.activate(onTap: { taps += 1 }, copy: { copies += 1 })
		#expect(taps == 1)
		#expect(copies == 0)
	}
}

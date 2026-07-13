@testable import AsNeeded
import SwiftUI
import Testing

@Suite("Subtle Support Layout Style Tests", .tags(Tag.unit))
struct SubtleSupportLayoutStyleTests {
	@Test("Uses the detailed support message below 135 percent text size")
	func detailedLayout() {
		#expect(SubtleSupportLayoutStyle(dynamicTypeSize: .large) == .detailed)
		#expect(SubtleSupportLayoutStyle(dynamicTypeSize: .xxLarge) == .detailed)
	}

	@Test("Uses compact support content at and above 135 percent text size")
	func compactLayout() {
		#expect(SubtleSupportLayoutStyle(dynamicTypeSize: .xxxLarge) == .compact)
		#expect(SubtleSupportLayoutStyle(dynamicTypeSize: .accessibility1) == .compact)
	}
}

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

@Suite("Support Suggestion Layout Style Tests", .tags(Tag.unit))
struct SupportSuggestionLayoutStyleTests {
	@Test("Uses detailed support content below 135 percent text size")
	func detailedLayout() {
		#expect(SupportSuggestionLayoutStyle(dynamicTypeSize: .xxLarge) == .detailed)
	}

	@Test("Hides support content at 135 percent text size")
	func hiddenLayout() {
		#expect(SupportSuggestionLayoutStyle(dynamicTypeSize: .xxxLarge) == .hidden)
	}

	@Test("Uses compact support content at accessibility text sizes")
	func compactLayout() {
		#expect(SupportSuggestionLayoutStyle(dynamicTypeSize: .accessibility1) == .compact)
	}
}

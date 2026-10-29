@testable import AsNeeded
import Foundation
import Testing

struct SupportPromptPolicyTests {
	private let now = Date(timeIntervalSince1970: 1_800_000_000)
	private var previousDay: Date { now.addingTimeInterval(-86_400) }

	@Test("Fresh installs and early launches do not show support prompts")
	func earlyUse() {
		#expect(!SupportPromptPolicy.shouldShow(launchCount: 1, doseDates: [], at: now))
		#expect(!SupportPromptPolicy.shouldShow(launchCount: 2, doseDates: [previousDay, now, now], at: now))
	}

	@Test("Multiple doses on one day do not establish repeat use")
	func sameDay() {
		#expect(!SupportPromptPolicy.shouldShow(launchCount: 10, doseDates: [now, now, now], at: now))
	}

	@Test("Established use permits optional support prompts")
	func establishedUse() {
		#expect(SupportPromptPolicy.shouldShow(launchCount: 3, doseDates: [previousDay, now, now], at: now))
	}

	@Test("Future-dated records cannot establish use")
	func futureDates() {
		#expect(!SupportPromptPolicy.shouldShow(launchCount: 3, doseDates: [now, now, now.addingTimeInterval(86_400)], at: now))
	}
}

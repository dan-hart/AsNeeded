@testable import AsNeeded
import ANModelKit
import Foundation
import Testing

@Suite("Widget navigation routes")
struct WidgetNavigationRouteTests {
	@Test("Every widget destination round-trips without names or a write instruction")
	func roundTrip() throws {
		let id = UUID()
		for route: WidgetNavigationRoute in [.medications, .medication(id), .logDose(nil), .logDose(id), .history(id), .trends(id, days: 7)] {
			let url = try #require(route.url)
			#expect(WidgetNavigationRoute(url: url) == route)
			#expect(!url.absoluteString.contains("save"))
		}
		#expect(WidgetNavigationRoute.trends(id, days: 30).url == nil)
	}

	@Test("Malformed and ambiguous links cannot select another medication", arguments: [
		"https://medication/example", "asneeded://log/not-a-uuid", "asneeded://medication",
		"asneeded://log?medication=other", "asneeded://medications/extra",
		"asneeded://user@medications", "asneeded://medications:123", "asneeded://medications#log"
	])
	func malformed(_ text: String) throws {
		#expect(WidgetNavigationRoute(url: try #require(URL(string: text))) == nil)
	}

	@Test("Trends rejects unrecognized ranges, duplicate parameters and extra paths")
	func invalidScopes() throws {
		let id = UUID().uuidString
		for suffix in ["?days=30", "?days=7&days=7", "?days=7&extra=yes", "/extra?days=7"] {
			let url = try #require(URL(string: "asneeded://trends/\(id)\(suffix)"))
			#expect(WidgetNavigationRoute(url: url) == nil)
		}
	}
}

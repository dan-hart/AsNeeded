import Foundation
import Testing

/// Owns a unique preferences domain for an individual test and removes it afterward.
final class IsolatedTestPreferences: @unchecked Sendable {
	let name = "AsNeededTest-\(UUID().uuidString)"
	let defaults: UserDefaults

	init() throws {
		defaults = try #require(UserDefaults(suiteName: name))
	}

	deinit { defaults.removePersistentDomain(forName: name) }
}

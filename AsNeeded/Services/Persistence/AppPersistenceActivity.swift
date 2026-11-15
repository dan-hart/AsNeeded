import UIKit

@MainActor
enum AppPersistenceActivity {
	static func begin(expiration: @escaping @MainActor () -> Void) throws -> (@MainActor () -> Void) {
		let application = UIApplication.shared
		let id = application.beginBackgroundTask(withName: "Medication storage", expirationHandler: expiration)
		guard id != .invalid else { throw PersistenceTransactionError.storageUnavailable }
		return { application.endBackgroundTask(id) }
	}
}

import Foundation

/// Deduplicate stable reads while refreshing widgets after actual committed medication/history changes.
@MainActor
final class WidgetRefreshObserver {
	private var previous: MedicationPersistenceSnapshot?
	private var previousProfiles: Data?
	private let reload: () -> Void

	init(reload: @escaping () -> Void) { self.reload = reload }

	func receive(_ snapshot: MedicationPersistenceSnapshot, profileData: Data? = nil) {
		if let previous, previous.medications == snapshot.medications, previous.events == snapshot.events, previousProfiles == profileData { return }
		previous = snapshot
		previousProfiles = profileData
		reload()
	}
}

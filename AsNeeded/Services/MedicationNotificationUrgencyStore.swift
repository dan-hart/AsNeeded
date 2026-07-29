import Foundation

@MainActor
final class MedicationNotificationUrgencyStore {
	static let shared = MedicationNotificationUrgencyStore()

	private let defaults: UserDefaults
	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func preference(for medicationID: UUID) -> Bool? {
		allPreferences()?[medicationID.uuidString]
	}

	func isUrgent(for medicationID: UUID) -> Bool {
		preference(for: medicationID) ?? false
	}

	@discardableResult
	func save(_ isUrgent: Bool, for medicationID: UUID) -> Bool {
		guard var preferences = allPreferences() else {
			return false
		}

		preferences[medicationID.uuidString] = isUrgent
		return persistVerified(preferences)
	}

	@discardableResult
	func removePreference(for medicationID: UUID) -> Bool {
		guard var preferences = allPreferences() else {
			return false
		}

		preferences.removeValue(forKey: medicationID.uuidString)
		return persistVerified(preferences)
	}

	func allPreferences() -> [String: Bool]? {
		guard defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) != nil else {
			return [:]
		}

		guard let data = defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) else {
			return nil
		}

		return try? decoder.decode([String: Bool].self, from: data)
	}

	@discardableResult
	func replaceAll(with preferences: [String: Bool]) -> Bool {
		guard allPreferences() != nil else {
			return false
		}

		return persistVerified(preferences)
	}

	var migrationCompleted: Bool {
		defaults.object(
			forKey: UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted
		) as? Bool == true
	}

	@discardableResult
	func markMigrationCompleted() -> Bool {
		defaults.set(
			true,
			forKey: UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted
		)
		return migrationCompleted
	}

	static func filteredPreferences(
		_ preferences: [String: Bool],
		validMedicationIDs: some Sequence<UUID>
	) -> [String: Bool] {
		let validIDs = Set(validMedicationIDs)
		return preferences.filter { key, _ in
			guard let medicationID = UUID(uuidString: key) else {
				return false
			}
			return validIDs.contains(medicationID)
		}
	}

	private func persistVerified(_ preferences: [String: Bool]) -> Bool {
		if preferences.isEmpty {
			defaults.removeObject(forKey: UserDefaultsKeys.medicationNotificationUrgency)
			return defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) == nil
		}

		guard let data = try? encoder.encode(preferences) else {
			return false
		}

		defaults.set(data, forKey: UserDefaultsKeys.medicationNotificationUrgency)
		return allPreferences() == preferences
	}
}

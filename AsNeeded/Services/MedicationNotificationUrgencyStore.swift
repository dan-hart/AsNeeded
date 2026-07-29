import Foundation

@MainActor
final class MedicationNotificationUrgencyStore {
	static let shared = MedicationNotificationUrgencyStore()

	typealias Writer = (Data, UserDefaults, String) -> Void
	typealias Remover = (UserDefaults, String) -> Void

	private let defaults: UserDefaults
	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()
	private let writer: Writer
	private let remover: Remover

	init(
		defaults: UserDefaults = .standard,
		writer: @escaping Writer = { data, destination, key in
			destination.set(data, forKey: key)
		},
		remover: @escaping Remover = { destination, key in
			destination.removeObject(forKey: key)
		}
	) {
		self.defaults = defaults
		self.writer = writer
		self.remover = remover
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
		let validIDs = Set(validMedicationIDs.map(\.uuidString))
		var filtered: [String: Bool] = [:]

		for (key, value) in preferences.sorted(by: { $0.key < $1.key }) {
			guard let medicationID = UUID(uuidString: key) else {
				continue
			}
			let canonicalKey = medicationID.uuidString
			guard validIDs.contains(canonicalKey) else {
				continue
			}

			if key == canonicalKey || filtered[canonicalKey] == nil {
				filtered[canonicalKey] = value
			}
		}

		return filtered
	}

	private func persistVerified(_ preferences: [String: Bool]) -> Bool {
		guard allPreferences() != nil else {
			return false
		}
		let priorData = defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency)

		if preferences.isEmpty {
			remover(defaults, UserDefaultsKeys.medicationNotificationUrgency)
			guard defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) == nil else {
				_ = restorePriorData(priorData)
				return false
			}
			return true
		}

		guard let data = try? encoder.encode(preferences) else {
			return false
		}

		writer(data, defaults, UserDefaultsKeys.medicationNotificationUrgency)
		guard
			defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == data,
			allPreferences() == preferences
		else {
			_ = restorePriorData(priorData)
			return false
		}
		return true
	}

	private func restorePriorData(_ priorData: Data?) -> Bool {
		if let priorData {
			defaults.set(priorData, forKey: UserDefaultsKeys.medicationNotificationUrgency)
			return defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == priorData
		}

		defaults.removeObject(forKey: UserDefaultsKeys.medicationNotificationUrgency)
		return defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) == nil
	}
}

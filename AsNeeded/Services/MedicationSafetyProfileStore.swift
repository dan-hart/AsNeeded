import Foundation

final class MedicationSafetyProfileStore {
	@MainActor static let shared = MedicationSafetyProfileStore()

	private let defaults: UserDefaults
	private let sharedDefaults: UserDefaults?
	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()

	init(defaults: UserDefaults = .standard, mirrorToSharedDefaults: Bool? = nil) {
		self.defaults = defaults
		let shouldMirror = mirrorToSharedDefaults ?? (defaults === UserDefaults.standard)
		sharedDefaults = shouldMirror ? UserDefaults(suiteName: StorageConstants.appGroupIdentifier) : nil
	}

	func profile(for medicationID: UUID) -> MedicationSafetyProfile {
		allProfiles()[medicationID.uuidString] ?? .empty
	}

	func save(_ profile: MedicationSafetyProfile, for medicationID: UUID) {
		var profiles = allProfiles()

		if profile.isEmpty {
			profiles.removeValue(forKey: medicationID.uuidString)
		} else {
			profiles[medicationID.uuidString] = profile
		}

		persist(profiles)
	}

	func allProfiles() -> [String: MedicationSafetyProfile] {
		let data = defaults.data(forKey: UserDefaultsKeys.medicationSafetyProfiles) ??
			sharedDefaults?.data(forKey: UserDefaultsKeys.medicationSafetyProfiles)

		guard let data else {
			return [:]
		}

		guard let profiles = try? decoder.decode([String: MedicationSafetyProfile].self, from: data) else {
			return [:]
		}

		return profiles
	}

	func replaceAll(with profiles: [String: MedicationSafetyProfile]) {
		persist(profiles)
	}

	static func filteredProfiles(
		from profiles: [String: MedicationSafetyProfile],
		validMedicationIDs: some Sequence<String>
	) -> [String: MedicationSafetyProfile] {
		let validIDs = Set(validMedicationIDs)
		return profiles.filter { validIDs.contains($0.key) }
	}

	private func persist(_ profiles: [String: MedicationSafetyProfile]) {
		guard !profiles.isEmpty else {
			defaults.removeObject(forKey: UserDefaultsKeys.medicationSafetyProfiles)
			sharedDefaults?.removeObject(forKey: UserDefaultsKeys.medicationSafetyProfiles)
			return
		}

		guard let data = try? encoder.encode(profiles) else {
			return
		}

		defaults.set(data, forKey: UserDefaultsKeys.medicationSafetyProfiles)
		sharedDefaults?.set(data, forKey: UserDefaultsKeys.medicationSafetyProfiles)
	}
}

import Foundation

final class MedicationRefillProfileStore {
	@MainActor static let shared = MedicationRefillProfileStore()

	private struct LegacyMedicationProfile: Codable {
		var lowStockThreshold: Double?
	}

	private enum ActiveProfiles {
		case absent
		case invalid
		case valid([String: MedicationRefillProfile])
	}

	typealias ProfileEncoder = ([String: MedicationRefillProfile]) throws -> Data
	typealias LegacyArchiver = (Data, UserDefaults, String) -> Void

	private let defaults: UserDefaults
	private let sharedDefaults: UserDefaults?
	private let decoder = JSONDecoder()
	private let profileEncoder: ProfileEncoder
	private let legacyArchiver: LegacyArchiver

	init(
		defaults: UserDefaults = .standard,
		sharedDefaults: UserDefaults? = UserDefaults(suiteName: StorageConstants.appGroupIdentifier),
		profileEncoder: @escaping ProfileEncoder = { try JSONEncoder().encode($0) },
		legacyArchiver: @escaping LegacyArchiver = { data, destination, key in
			destination.set(data, forKey: key)
		}
	) {
		self.defaults = defaults
		self.sharedDefaults = sharedDefaults
		self.profileEncoder = profileEncoder
		self.legacyArchiver = legacyArchiver
	}

	func profile(for medicationID: UUID) -> MedicationRefillProfile {
		allProfiles()[medicationID.uuidString] ?? .empty
	}

	func save(_ profile: MedicationRefillProfile, for medicationID: UUID) {
		var profiles = allProfiles()

		if profile.isEmpty {
			profiles.removeValue(forKey: medicationID.uuidString)
		} else {
			profiles[medicationID.uuidString] = profile
		}

		persist(profiles)
	}

	func allProfiles() -> [String: MedicationRefillProfile] {
		if migrationCompleted {
			mirrorMigrationMarker()
			return resolvedActiveProfiles()
		}

		switch activeProfiles() {
		case .invalid:
			return [:]
		case let .valid(profiles):
			return migrateLegacyIfNeeded(existingProfiles: profiles)
		case .absent:
			return migrateLegacyIfNeeded(existingProfiles: nil)
		}
	}

	func replaceAll(with profiles: [String: MedicationRefillProfile]) {
		persist(profiles)
	}

	static func filteredProfiles(
		from profiles: [String: MedicationRefillProfile],
		validMedicationIDs: some Sequence<String>
	) -> [String: MedicationRefillProfile] {
		let validIDs = Set(validMedicationIDs)
		return profiles.filter { validIDs.contains($0.key) }
	}

	private var migrationCompleted: Bool {
		defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted) ||
			sharedDefaults?.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted) == true
	}

	private func mirrorMigrationMarker() {
		defaults.set(true, forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted)
		sharedDefaults?.set(true, forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted)
	}

	private func activeProfiles() -> ActiveProfiles {
		if defaults.object(forKey: UserDefaultsKeys.medicationRefillProfiles) != nil {
			guard
				let data = defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles),
				let profiles = decodeProfiles(from: data)
			else {
				return .invalid
			}

			sharedDefaults?.set(data, forKey: UserDefaultsKeys.medicationRefillProfiles)
			return .valid(profiles)
		}

		guard let sharedDefaults else {
			return .absent
		}

		guard sharedDefaults.object(forKey: UserDefaultsKeys.medicationRefillProfiles) != nil else {
			return .absent
		}

		guard
			let data = sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles),
			let profiles = decodeProfiles(from: data)
		else {
			return .invalid
		}

		defaults.set(data, forKey: UserDefaultsKeys.medicationRefillProfiles)
		return .valid(profiles)
	}

	private func resolvedActiveProfiles() -> [String: MedicationRefillProfile] {
		switch activeProfiles() {
		case let .valid(profiles):
			return profiles
		case .absent, .invalid:
			return [:]
		}
	}

	private func migrateLegacyIfNeeded(
		existingProfiles: [String: MedicationRefillProfile]?
	) -> [String: MedicationRefillProfile] {
		guard let legacyData = legacyPayload() else {
			return existingProfiles ?? [:]
		}

		guard let legacyProfiles = try? decoder.decode(
			[String: LegacyMedicationProfile].self,
			from: legacyData
		) else {
			return existingProfiles ?? [:]
		}

		let migratedProfiles = legacyProfiles.reduce(
			into: [String: MedicationRefillProfile]()
		) { result, entry in
			guard let threshold = entry.value.lowStockThreshold else {
				return
			}
			result[entry.key] = MedicationRefillProfile(lowStockThreshold: threshold)
		}

		let activeResult: [String: MedicationRefillProfile]
		if let existingProfiles {
			activeResult = existingProfiles
		} else if migratedProfiles.isEmpty {
			activeResult = [:]
		} else {
			guard persistMigratedProfiles(migratedProfiles) else {
				return [:]
			}
			activeResult = migratedProfiles
		}

		guard archiveAndVerify(legacyData) else {
			return activeResult
		}

		defaults.removeObject(forKey: UserDefaultsKeys.legacyMedicationProfiles)
		sharedDefaults?.removeObject(forKey: UserDefaultsKeys.legacyMedicationProfiles)
		mirrorMigrationMarker()
		return activeResult
	}

	private func legacyPayload() -> Data? {
		if defaults.object(forKey: UserDefaultsKeys.legacyMedicationProfiles) != nil {
			return defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles)
		}

		return sharedDefaults?.data(forKey: UserDefaultsKeys.legacyMedicationProfiles)
	}

	private func persistMigratedProfiles(_ profiles: [String: MedicationRefillProfile]) -> Bool {
		guard
			let data = try? profileEncoder(profiles),
			decodeProfiles(from: data) == profiles
		else {
			return false
		}

		defaults.set(data, forKey: UserDefaultsKeys.medicationRefillProfiles)
		sharedDefaults?.set(data, forKey: UserDefaultsKeys.medicationRefillProfiles)

		guard
			defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == data,
			decodeProfiles(from: defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles)) == profiles
		else {
			return false
		}

		if let sharedDefaults {
			guard
				sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == data,
				decodeProfiles(from: sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles)) == profiles
			else {
				return false
			}
		}

		return true
	}

	private func archiveAndVerify(_ legacyData: Data) -> Bool {
		legacyArchiver(legacyData, defaults, UserDefaultsKeys.archivedMedicationProfiles)
		guard defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == legacyData else {
			return false
		}

		if let sharedDefaults {
			legacyArchiver(legacyData, sharedDefaults, UserDefaultsKeys.archivedMedicationProfiles)
			guard sharedDefaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == legacyData else {
				return false
			}
		}

		return true
	}

	private func persist(_ profiles: [String: MedicationRefillProfile]) {
		let nonEmptyProfiles = profiles.filter { !$0.value.isEmpty }
		guard !nonEmptyProfiles.isEmpty else {
			defaults.removeObject(forKey: UserDefaultsKeys.medicationRefillProfiles)
			sharedDefaults?.removeObject(forKey: UserDefaultsKeys.medicationRefillProfiles)
			return
		}

		guard
			let data = try? profileEncoder(nonEmptyProfiles),
			decodeProfiles(from: data) == nonEmptyProfiles
		else {
			return
		}

		defaults.set(data, forKey: UserDefaultsKeys.medicationRefillProfiles)
		sharedDefaults?.set(data, forKey: UserDefaultsKeys.medicationRefillProfiles)
	}

	private func decodeProfiles(from data: Data?) -> [String: MedicationRefillProfile]? {
		guard let data else {
			return nil
		}
		return try? decoder.decode([String: MedicationRefillProfile].self, from: data)
	}
}

import Foundation

final class MedicationRefillProfileStore {
	@MainActor static let shared = MedicationRefillProfileStore()

	private struct LegacyMedicationProfile: Codable {
		var lowStockThreshold: Double?
	}

	private struct ActiveSnapshot {
		let destination: UserDefaults
		let data: Data?
	}

	private struct KeySnapshot {
		let destination: UserDefaults
		let key: String
		let value: Any?
	}

	private struct LegacyPayloads {
		let standard: Data?
		let shared: Data?
		let authoritative: Data
	}

	private enum ActiveProfiles {
		case absent
		case invalid
		case valid([String: MedicationRefillProfile], synchronized: Bool)
	}

	private enum LegacyPayloadState {
		case absent
		case invalid
		case valid(LegacyPayloads)
	}

	typealias ProfileEncoder = ([String: MedicationRefillProfile]) throws -> Data
	typealias LegacyArchiver = (Data, UserDefaults, String) -> Void
	typealias ActiveWriter = (Data, UserDefaults, String) -> Void
	typealias ActiveRemover = (UserDefaults, String) -> Void

	private let defaults: UserDefaults
	private let sharedDefaults: UserDefaults?
	private let decoder = JSONDecoder()
	private let profileEncoder: ProfileEncoder
	private let legacyArchiver: LegacyArchiver
	private let activeWriter: ActiveWriter
	private let activeRemover: ActiveRemover

	init(
		defaults: UserDefaults = .standard,
		sharedDefaults: UserDefaults? = nil,
		profileEncoder: @escaping ProfileEncoder = { try JSONEncoder().encode($0) },
		legacyArchiver: @escaping LegacyArchiver = { data, destination, key in
			destination.set(data, forKey: key)
		},
		activeWriter: @escaping ActiveWriter = { data, destination, key in
			destination.set(data, forKey: key)
		},
		activeRemover: @escaping ActiveRemover = { destination, key in
			destination.removeObject(forKey: key)
		}
	) {
		self.defaults = defaults
		self.sharedDefaults = sharedDefaults ?? (
			defaults === UserDefaults.standard ?
				UserDefaults(suiteName: StorageConstants.appGroupIdentifier) : nil
		)
		self.profileEncoder = profileEncoder
		self.legacyArchiver = legacyArchiver
		self.activeWriter = activeWriter
		self.activeRemover = activeRemover
	}

	func profile(for medicationID: UUID) -> MedicationRefillProfile {
		allProfiles()[medicationID.uuidString] ?? .empty
	}

	@discardableResult
	func save(_ profile: MedicationRefillProfile, for medicationID: UUID) -> Bool {
		guard !hasInvalidAuthoritativeActivePayload else {
			return false
		}

		var profiles = allProfiles()
		guard !hasInvalidAuthoritativeActivePayload else {
			return false
		}

		if profile.isEmpty {
			profiles.removeValue(forKey: medicationID.uuidString)
		} else {
			profiles[medicationID.uuidString] = profile
		}

		return persistVerified(profiles)
	}

	func allProfiles() -> [String: MedicationRefillProfile] {
		if migrationCompleted {
			mirrorMigrationMarker()
			return resolvedActiveProfiles()
		}

		switch activeProfiles() {
		case .invalid:
			return [:]
		case let .valid(profiles, synchronized):
			return migrateLegacyIfNeeded(
				existingProfiles: profiles,
				activePayloadVerified: synchronized
			)
		case .absent:
			return migrateLegacyIfNeeded(existingProfiles: nil, activePayloadVerified: true)
		}
	}

	@discardableResult
	func replaceAll(with profiles: [String: MedicationRefillProfile]) -> Bool {
		guard !hasInvalidAuthoritativeActivePayload else {
			return false
		}
		return persistVerified(profiles)
	}

	@discardableResult
	func resetProfiles() -> Bool {
		removeVerified(keys: [
			UserDefaultsKeys.medicationRefillProfiles,
			UserDefaultsKeys.legacyMedicationProfiles,
		])
	}

	@discardableResult
	func eraseAllProfileData() -> Bool {
		removeVerified(keys: [
			UserDefaultsKeys.medicationRefillProfiles,
			UserDefaultsKeys.legacyMedicationProfiles,
			UserDefaultsKeys.medicationProfilesMigrationCompleted,
			UserDefaultsKeys.archivedMedicationProfiles,
		])
	}

	static func filteredProfiles(
		from profiles: [String: MedicationRefillProfile],
		validMedicationIDs: some Sequence<String>
	) -> [String: MedicationRefillProfile] {
		let validIDs = Set(validMedicationIDs)
		return profiles.filter { validIDs.contains($0.key) }
	}

	private var activeDestinations: [UserDefaults] {
		guard let sharedDefaults, sharedDefaults !== defaults else {
			return [defaults]
		}
		return [defaults, sharedDefaults]
	}

	private var hasInvalidAuthoritativeActivePayload: Bool {
		if defaults.object(forKey: UserDefaultsKeys.medicationRefillProfiles) != nil {
			guard let data = defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) else {
				return true
			}
			return decodeProfiles(from: data) == nil
		}

		guard let sharedDefaults,
			sharedDefaults.object(forKey: UserDefaultsKeys.medicationRefillProfiles) != nil
		else {
			return false
		}

		guard let data = sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) else {
			return true
		}
		return decodeProfiles(from: data) == nil
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

			let synchronized = mirrorActiveDataIfNeeded(
				data,
				profiles: profiles,
				to: sharedDefaults
			)
			return .valid(profiles, synchronized: synchronized)
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

		let synchronized = mirrorActiveDataIfNeeded(data, profiles: profiles, to: defaults)
		return .valid(profiles, synchronized: synchronized)
	}

	private func mirrorActiveDataIfNeeded(
		_ data: Data,
		profiles: [String: MedicationRefillProfile],
		to destination: UserDefaults?
	) -> Bool {
		guard let destination, destination !== defaults || defaults.data(
			forKey: UserDefaultsKeys.medicationRefillProfiles
		) != data else {
			return true
		}

		if destination.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == data,
			decodeProfiles(from: data) == profiles {
			return true
		}

		let snapshot = ActiveSnapshot(
			destination: destination,
			data: destination.data(forKey: UserDefaultsKeys.medicationRefillProfiles)
		)
		activeWriter(data, destination, UserDefaultsKeys.medicationRefillProfiles)

		guard activePayload(in: destination, matches: data, profiles: profiles) else {
			_ = restoreActiveSnapshots([snapshot])
			return false
		}

		return true
	}

	private func resolvedActiveProfiles() -> [String: MedicationRefillProfile] {
		switch activeProfiles() {
		case let .valid(profiles, _):
			return profiles
		case .absent, .invalid:
			return [:]
		}
	}

	private func migrateLegacyIfNeeded(
		existingProfiles: [String: MedicationRefillProfile]?,
		activePayloadVerified: Bool
	) -> [String: MedicationRefillProfile] {
		guard activePayloadVerified else {
			return existingProfiles ?? [:]
		}

		switch legacyPayloads() {
		case .absent, .invalid:
			return existingProfiles ?? [:]
		case let .valid(payloads):
			return migrateLegacyPayloads(payloads, existingProfiles: existingProfiles)
		}
	}

	private func migrateLegacyPayloads(
		_ payloads: LegacyPayloads,
		existingProfiles: [String: MedicationRefillProfile]?
	) -> [String: MedicationRefillProfile] {
		guard let legacyProfiles = try? decoder.decode(
			[String: LegacyMedicationProfile].self,
			from: payloads.authoritative
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
			guard persistVerified(migratedProfiles) else {
				return [:]
			}
			activeResult = migratedProfiles
		}

		guard archiveAndVerify(payloads), removeLegacyAndVerify(payloads) else {
			return activeResult
		}

		mirrorMigrationMarker()
		return activeResult
	}

	private func legacyPayloads() -> LegacyPayloadState {
		let standardPresent = defaults.object(forKey: UserDefaultsKeys.legacyMedicationProfiles) != nil
		let sharedPresent = sharedDefaults?.object(forKey: UserDefaultsKeys.legacyMedicationProfiles) != nil
		guard standardPresent || sharedPresent else {
			return .absent
		}

		let standardData = defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let sharedData = sharedDefaults?.data(forKey: UserDefaultsKeys.legacyMedicationProfiles)
		guard !standardPresent || standardData != nil,
			!sharedPresent || sharedData != nil,
			let authoritative = standardPresent ? standardData : sharedData
		else {
			return .invalid
		}

		return .valid(LegacyPayloads(
			standard: standardData,
			shared: sharedData,
			authoritative: authoritative
		))
	}

	private func archiveAndVerify(_ payloads: LegacyPayloads) -> Bool {
		let standardArchive = payloads.standard ?? payloads.authoritative
		legacyArchiver(standardArchive, defaults, UserDefaultsKeys.archivedMedicationProfiles)
		guard defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == standardArchive else {
			return false
		}

		if let sharedDefaults {
			let sharedArchive = payloads.shared ?? payloads.authoritative
			legacyArchiver(sharedArchive, sharedDefaults, UserDefaultsKeys.archivedMedicationProfiles)
			guard sharedDefaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == sharedArchive else {
				return false
			}
		}

		return true
	}

	private func removeLegacyAndVerify(_ payloads: LegacyPayloads) -> Bool {
		defaults.removeObject(forKey: UserDefaultsKeys.legacyMedicationProfiles)
		sharedDefaults?.removeObject(forKey: UserDefaultsKeys.legacyMedicationProfiles)

		guard defaults.object(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil,
			sharedDefaults?.object(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil
		else {
			restoreLegacyPayloads(payloads)
			return false
		}

		return true
	}

	private func restoreLegacyPayloads(_ payloads: LegacyPayloads) {
		if let standard = payloads.standard {
			defaults.set(standard, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		} else {
			defaults.removeObject(forKey: UserDefaultsKeys.legacyMedicationProfiles)
		}

		if let sharedDefaults {
			if let shared = payloads.shared {
				sharedDefaults.set(shared, forKey: UserDefaultsKeys.legacyMedicationProfiles)
			} else {
				sharedDefaults.removeObject(forKey: UserDefaultsKeys.legacyMedicationProfiles)
			}
		}
	}

	private func persistVerified(_ profiles: [String: MedicationRefillProfile]) -> Bool {
		let nonEmptyProfiles = profiles.filter { !$0.value.isEmpty }
		let snapshots = activeDestinations.map {
			ActiveSnapshot(
				destination: $0,
				data: $0.data(forKey: UserDefaultsKeys.medicationRefillProfiles)
			)
		}

		guard !nonEmptyProfiles.isEmpty else {
			for destination in activeDestinations {
				activeRemover(destination, UserDefaultsKeys.medicationRefillProfiles)
				guard destination.object(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil else {
					_ = restoreActiveSnapshots(snapshots)
					return false
				}
			}
			return true
		}

		guard
			let data = try? profileEncoder(nonEmptyProfiles),
			decodeProfiles(from: data) == nonEmptyProfiles
		else {
			return false
		}

		for destination in activeDestinations {
			activeWriter(data, destination, UserDefaultsKeys.medicationRefillProfiles)
			guard activePayload(in: destination, matches: data, profiles: nonEmptyProfiles) else {
				_ = restoreActiveSnapshots(snapshots)
				return false
			}
		}

		return true
	}

	private func activePayload(
		in destination: UserDefaults,
		matches data: Data,
		profiles: [String: MedicationRefillProfile]
	) -> Bool {
		guard destination.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == data else {
			return false
		}
		return decodeProfiles(from: destination.data(
			forKey: UserDefaultsKeys.medicationRefillProfiles
		)) == profiles
	}

	private func restoreActiveSnapshots(_ snapshots: [ActiveSnapshot]) -> Bool {
		for snapshot in snapshots {
			if let data = snapshot.data {
				snapshot.destination.set(data, forKey: UserDefaultsKeys.medicationRefillProfiles)
			} else {
				snapshot.destination.removeObject(forKey: UserDefaultsKeys.medicationRefillProfiles)
			}
		}

		return snapshots.allSatisfy { snapshot in
			if let data = snapshot.data {
				return snapshot.destination.data(
					forKey: UserDefaultsKeys.medicationRefillProfiles
				) == data
			}
			return snapshot.destination.object(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil
		}
	}

	private func removeVerified(keys: [String]) -> Bool {
		let snapshots = activeDestinations.flatMap { destination in
			keys.map { key in
				KeySnapshot(
					destination: destination,
					key: key,
					value: destination.object(forKey: key)
				)
			}
		}

		for destination in activeDestinations {
			for key in keys {
				activeRemover(destination, key)
				guard destination.object(forKey: key) == nil else {
					_ = restoreKeySnapshots(snapshots)
					return false
				}
			}
		}

		return true
	}

	private func restoreKeySnapshots(_ snapshots: [KeySnapshot]) -> Bool {
		for snapshot in snapshots {
			if let value = snapshot.value {
				snapshot.destination.set(value, forKey: snapshot.key)
			} else {
				snapshot.destination.removeObject(forKey: snapshot.key)
			}
		}

		return snapshots.allSatisfy { snapshot in
			let restoredValue = snapshot.destination.object(forKey: snapshot.key)
			switch (snapshot.value, restoredValue) {
			case (nil, nil):
				return true
			case let (expected as NSObject, restored as NSObject):
				return expected.isEqual(restored)
			default:
				return false
			}
		}
	}

	private func decodeProfiles(from data: Data?) -> [String: MedicationRefillProfile]? {
		guard let data else {
			return nil
		}
		return try? decoder.decode([String: MedicationRefillProfile].self, from: data)
	}
}

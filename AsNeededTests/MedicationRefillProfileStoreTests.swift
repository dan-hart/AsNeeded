@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationRefillProfileStore Tests", .tags(.unit))
struct MedicationRefillProfileStoreTests {
	private enum EncodingFailure: Error {
		case intentional
	}

	private struct LegacyProfile: Codable {
		var minimumHoursBetweenDoses: Double?
		var lowStockThreshold: Double?
		var refillLeadDays: Int = 5
	}

	private func makeDefaults(_ label: String = "defaults") -> UserDefaults {
		let suiteName = "MedicationRefillProfileStoreTests.\(label).\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName) ?? .standard
		defaults.removePersistentDomain(forName: suiteName)
		return defaults
	}

	private func legacyPayload(_ profiles: [String: LegacyProfile]) throws -> Data {
		try JSONEncoder().encode(profiles)
	}

	private func activePayload(_ profiles: [String: MedicationRefillProfile]) throws -> Data {
		try JSONEncoder().encode(profiles)
	}

	@Test("Store saves only custom low-stock thresholds")
	func savesOnlyCustomThresholds() {
		let defaults = makeDefaults()
		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)
		let medicationID = UUID()

		store.save(MedicationRefillProfile(lowStockThreshold: 7), for: medicationID)

		#expect(store.profile(for: medicationID) == MedicationRefillProfile(lowStockThreshold: 7))
		#expect(store.allProfiles() == [medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 7)])
	}

	@Test("Legacy-only profiles migrate low-stock thresholds")
	func migratesLegacyOnlyProfiles() throws {
		let defaults = makeDefaults()
		let sharedDefaults = makeDefaults("shared")
		let medicationID = UUID()
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(minimumHoursBetweenDoses: 4, lowStockThreshold: 6),
		])
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)

		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: sharedDefaults)

		#expect(store.profile(for: medicationID).lowStockThreshold == 6)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == legacyData)
		#expect(defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles))
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == legacyData)
		#expect(sharedDefaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("New-only active profiles load without legacy migration")
	func loadsNewOnlyActiveProfiles() throws {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let data = try activePayload([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 8),
		])
		defaults.set(data, forKey: UserDefaultsKeys.medicationRefillProfiles)

		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)

		#expect(store.profile(for: medicationID).lowStockThreshold == 8)
		#expect(!defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("New active data wins when both active and legacy keys exist")
	func newDataWinsOverLegacyData() throws {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let activeData = try activePayload([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 9),
		])
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 3),
		])
		defaults.set(activeData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)

		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)

		#expect(store.profile(for: medicationID).lowStockThreshold == 9)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == activeData)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == legacyData)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
		#expect(defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Legacy profiles without thresholds archive without an active payload")
	func archivesLegacyProfilesWithoutThresholds() throws {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(minimumHoursBetweenDoses: 4, lowStockThreshold: nil),
		])
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)

		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)

		#expect(store.profile(for: medicationID) == .empty)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == legacyData)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
		#expect(defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Invalid legacy data remains active and unmarked")
	func leavesInvalidLegacyDataUntouched() {
		let defaults = makeDefaults()
		let invalidData = Data("not-json".utf8)
		defaults.set(invalidData, forKey: UserDefaultsKeys.legacyMedicationProfiles)

		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)

		#expect(store.allProfiles().isEmpty)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == invalidData)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == nil)
		#expect(!defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Valid standard active data wins over shared active data")
	func standardActiveDataWinsOverShared() throws {
		let defaults = makeDefaults()
		let sharedDefaults = makeDefaults("shared")
		let medicationID = UUID()
		let standardData = try activePayload([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 11),
		])
		let sharedData = try activePayload([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 4),
		])
		defaults.set(standardData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		sharedDefaults.set(sharedData, forKey: UserDefaultsKeys.medicationRefillProfiles)

		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: sharedDefaults)

		#expect(store.profile(for: medicationID).lowStockThreshold == 11)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == standardData)
	}

	@Test("Valid shared fallback mirrors into standard defaults")
	func sharedFallbackMirrorsIntoStandard() throws {
		let defaults = makeDefaults()
		let sharedDefaults = makeDefaults("shared")
		let medicationID = UUID()
		let sharedData = try activePayload([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 12),
		])
		sharedDefaults.set(sharedData, forKey: UserDefaultsKeys.medicationRefillProfiles)

		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: sharedDefaults)

		#expect(store.profile(for: medicationID).lowStockThreshold == 12)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == sharedData)
	}

	@Test("Profiles are filtered to valid medication IDs")
	func filtersInvalidMedicationIDs() {
		let validID = UUID()
		let invalidID = UUID()
		let profiles = [
			validID.uuidString: MedicationRefillProfile(lowStockThreshold: 5),
			invalidID.uuidString: MedicationRefillProfile(lowStockThreshold: 8),
		]

		let filtered = MedicationRefillProfileStore.filteredProfiles(
			from: profiles,
			validMedicationIDs: [validID.uuidString]
		)

		#expect(filtered == [validID.uuidString: MedicationRefillProfile(lowStockThreshold: 5)])
	}

	@Test("Verified profile reset rolls both domains back when shared removal fails")
	func verifiedResetRollsBackWhenSharedRemovalFails() throws {
		let defaults = makeDefaults()
		let sharedDefaults = makeDefaults("shared")
		let medicationID = UUID()
		let activeData = try activePayload([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 8),
		])
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 5),
		])
		for destination in [defaults, sharedDefaults] {
			destination.set(activeData, forKey: UserDefaultsKeys.medicationRefillProfiles)
			destination.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
			destination.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.archivedMedicationProfiles)
			destination.set(true, forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted)
		}
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			activeRemover: { destination, key in
				guard destination !== sharedDefaults else { return }
				destination.removeObject(forKey: key)
			}
		)

		#expect(!store.resetProfiles())
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == activeData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == activeData)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == legacyData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == legacyData)

		let recreatedStore = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults
		)
		#expect(recreatedStore.profile(for: medicationID).lowStockThreshold == 8)
	}

	@Test("Full profile erasure removes active migration and recovery data")
	func fullProfileErasureRemovesAllProfileData() throws {
		let defaults = makeDefaults()
		let sharedDefaults = makeDefaults("shared")
		let activeData = try activePayload([
			UUID().uuidString: MedicationRefillProfile(lowStockThreshold: 8),
		])
		for destination in [defaults, sharedDefaults] {
			destination.set(activeData, forKey: UserDefaultsKeys.medicationRefillProfiles)
			destination.set(activeData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
			destination.set(Data([1, 2, 3]), forKey: UserDefaultsKeys.archivedMedicationProfiles)
			destination.set(true, forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted)
		}
		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: sharedDefaults)

		#expect(store.eraseAllProfileData())

		for destination in [defaults, sharedDefaults] {
			#expect(destination.object(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
			#expect(destination.object(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
			#expect(destination.object(forKey: UserDefaultsKeys.archivedMedicationProfiles) == nil)
			#expect(destination.object(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted) == nil)
		}
	}

	@Test("Repeated store creation does not replay migration")
	func repeatedStoreCreationIsIdempotent() throws {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 6),
		])
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let firstStore = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)
		#expect(firstStore.profile(for: medicationID).lowStockThreshold == 6)

		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let secondStore = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)

		#expect(secondStore.profile(for: medicationID).lowStockThreshold == 6)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == legacyData)
	}

	@Test("Removing the final threshold does not resurrect legacy data")
	func removingFinalThresholdDoesNotResurrectLegacyData() throws {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 6),
		])
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)
		#expect(store.profile(for: medicationID).lowStockThreshold == 6)

		store.save(.empty, for: medicationID)
		let recreatedStore = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)

		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
		#expect(recreatedStore.profile(for: medicationID) == .empty)
		#expect(defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Active-payload verification failure leaves legacy data untouched")
	func activePayloadVerificationFailureIsNonDestructive() throws {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 6),
		])
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: nil,
			profileEncoder: { _ in Data("invalid-active-payload".utf8) }
		)

		#expect(store.allProfiles().isEmpty)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == legacyData)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == nil)
		#expect(!defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Active-payload encoding failure leaves legacy data untouched")
	func activePayloadEncodingFailureIsNonDestructive() throws {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 6),
		])
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: nil,
			profileEncoder: { _ in throw EncodingFailure.intentional }
		)

		#expect(store.allProfiles().isEmpty)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == nil)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == legacyData)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == nil)
		#expect(!defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Archive write failure leaves legacy data untouched")
	func archiveWriteFailureIsNonDestructive() throws {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 6),
		])
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: nil,
			legacyArchiver: { _, _, _ in }
		)

		#expect(store.profile(for: medicationID).lowStockThreshold == 6)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == legacyData)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == nil)
		#expect(!defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Archive verification failure leaves legacy data untouched")
	func archiveVerificationFailureIsNonDestructive() throws {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 6),
		])
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: nil,
			legacyArchiver: { _, destination, key in
				destination.set(Data("corrupt-archive".utf8), forKey: key)
			}
		)

		#expect(store.profile(for: medicationID).lowStockThreshold == 6)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == legacyData)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) != legacyData)
		#expect(!defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Active profiles do not retire legacy data when shared mirroring fails")
	func activeProfilesRequireVerifiedSharedMirroringBeforeArchival() throws {
		let defaults = makeDefaults()
		let sharedDefaults = makeDefaults("shared")
		let medicationID = UUID()
		let activeData = try activePayload([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 9),
		])
		let legacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 3),
		])
		defaults.set(activeData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		defaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		sharedDefaults.set(legacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			activeWriter: { data, destination, key in
				guard destination !== sharedDefaults else {
					return
				}
				destination.set(data, forKey: key)
			}
		)

		#expect(store.profile(for: medicationID).lowStockThreshold == 9)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == legacyData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == legacyData)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == nil)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == nil)
		#expect(!defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
		#expect(!sharedDefaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Failed shared save rolls both domains back before recreation")
	func failedSharedSaveRollsBack() throws {
		let defaults = makeDefaults()
		let sharedDefaults = makeDefaults("shared")
		let medicationID = UUID()
		let originalProfiles = [
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 5),
		]
		let originalData = try activePayload(originalProfiles)
		defaults.set(originalData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		sharedDefaults.set(originalData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			activeWriter: { data, destination, key in
				guard destination !== sharedDefaults else {
					return
				}
				destination.set(data, forKey: key)
			}
		)

		let saved = store.save(MedicationRefillProfile(lowStockThreshold: 7), for: medicationID)
		let recreated = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: sharedDefaults)

		#expect(!saved)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == originalData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == originalData)
		#expect(recreated.profile(for: medicationID).lowStockThreshold == 5)
	}

	@Test("Failed shared final removal rolls both domains back before recreation")
	func failedSharedRemovalRollsBack() throws {
		let defaults = makeDefaults()
		let sharedDefaults = makeDefaults("shared")
		let medicationID = UUID()
		let originalData = try activePayload([
			medicationID.uuidString: MedicationRefillProfile(lowStockThreshold: 5),
		])
		defaults.set(originalData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		sharedDefaults.set(originalData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			sharedDefaults: sharedDefaults,
			activeRemover: { destination, key in
				guard destination !== sharedDefaults else {
					return
				}
				destination.removeObject(forKey: key)
			}
		)

		let removed = store.save(.empty, for: medicationID)
		let recreated = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: sharedDefaults)

		#expect(!removed)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == originalData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == originalData)
		#expect(recreated.profile(for: medicationID).lowStockThreshold == 5)
	}

	@Test("Invalid active bytes refuse save and remain recoverable")
	func invalidActivePayloadRefusesSave() {
		let defaults = makeDefaults()
		let medicationID = UUID()
		let invalidData = Data("invalid-active".utf8)
		defaults.set(invalidData, forKey: UserDefaultsKeys.medicationRefillProfiles)
		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: nil)

		let saved = store.save(MedicationRefillProfile(lowStockThreshold: 7), for: medicationID)

		#expect(!saved)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationRefillProfiles) == invalidData)
		#expect(store.profile(for: medicationID) == .empty)
	}

	@Test("Divergent legacy payloads archive each domain's original bytes")
	func divergentLegacyPayloadsArchiveIndependently() throws {
		let defaults = makeDefaults()
		let sharedDefaults = makeDefaults("shared")
		let medicationID = UUID()
		let standardLegacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 6),
		])
		let sharedLegacyData = try legacyPayload([
			medicationID.uuidString: LegacyProfile(lowStockThreshold: 8),
		])
		defaults.set(standardLegacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		sharedDefaults.set(sharedLegacyData, forKey: UserDefaultsKeys.legacyMedicationProfiles)
		let store = MedicationRefillProfileStore(defaults: defaults, sharedDefaults: sharedDefaults)

		#expect(store.profile(for: medicationID).lowStockThreshold == 6)
		#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == standardLegacyData)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == sharedLegacyData)
		#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
		#expect(sharedDefaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
		#expect(defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
		#expect(sharedDefaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	}

	@Test("Custom defaults do not automatically attach the App Group")
	func customDefaultsDoNotAutomaticallyMirror() {
		let defaults = makeDefaults()
		let medicationID = UUID()
		var writeDestinations: [ObjectIdentifier] = []
		let store = MedicationRefillProfileStore(
			defaults: defaults,
			activeWriter: { data, destination, key in
				writeDestinations.append(ObjectIdentifier(destination))
				destination.set(data, forKey: key)
			}
		)

		let saved = store.save(MedicationRefillProfile(lowStockThreshold: 7), for: medicationID)

		#expect(saved)
		#expect(writeDestinations == [ObjectIdentifier(defaults)])
	}
}

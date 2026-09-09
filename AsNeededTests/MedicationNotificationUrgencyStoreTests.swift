@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationNotificationUrgencyStore Tests", .serialized, .tags(.unit))
@MainActor
struct MedicationNotificationUrgencyStoreTests {
	private struct DefaultsFixture {
		let defaults: UserDefaults
		let suiteName: String
	}

	private func makeDefaults() throws -> DefaultsFixture {
		let suiteName = "MedicationNotificationUrgencyStoreTests.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suiteName))
		defaults.removePersistentDomain(forName: suiteName)
		return DefaultsFixture(defaults: defaults, suiteName: suiteName)
	}

	@Test("Missing preference resolves to normal without creating a preference")
	func missingPreferenceResolvesToNormal() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults)
		let medicationID = UUID()

		#expect(store.preference(for: medicationID) == nil)
		#expect(!store.isUrgent(for: medicationID))
		#expect(store.preference(for: medicationID) == nil)
	}

	@Test("Explicit true and false preferences survive store recreation")
	func explicitPreferencesPersist() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let urgentMedicationID = UUID()
		let normalMedicationID = UUID()
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults)

		#expect(store.save(true, for: urgentMedicationID))
		#expect(store.save(false, for: normalMedicationID))

		let recreatedStore = MedicationNotificationUrgencyStore(defaults: fixture.defaults)
		#expect(recreatedStore.preference(for: urgentMedicationID) == true)
		#expect(recreatedStore.preference(for: normalMedicationID) == false)
		#expect(recreatedStore.isUrgent(for: urgentMedicationID))
		#expect(!recreatedStore.isUrgent(for: normalMedicationID))
	}

	@Test("Medication preferences remain isolated")
	func medicationPreferencesRemainIsolated() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults)
		let firstMedicationID = UUID()
		let secondMedicationID = UUID()

		#expect(store.save(true, for: firstMedicationID))

		#expect(store.preference(for: firstMedicationID) == true)
		#expect(store.preference(for: secondMedicationID) == nil)
	}

	@Test("Removing one preference preserves other medication preferences")
	func removingOnePreferencePreservesOthers() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults)
		let removedMedicationID = UUID()
		let retainedMedicationID = UUID()
		#expect(store.save(true, for: removedMedicationID))
		#expect(store.save(false, for: retainedMedicationID))

		#expect(store.removePreference(for: removedMedicationID))

		#expect(store.preference(for: removedMedicationID) == nil)
		#expect(store.preference(for: retainedMedicationID) == false)
	}

	@Test("Replacing all preferences preserves explicit false")
	func replaceAllPreservesExplicitFalse() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults)
		let urgentMedicationID = UUID()
		let normalMedicationID = UUID()

		#expect(store.replaceAll(with: [
			urgentMedicationID.uuidString: true,
			normalMedicationID.uuidString: false,
		]))

		#expect(store.allPreferences() == [
			urgentMedicationID.uuidString: true,
			normalMedicationID.uuidString: false,
		])
		#expect(store.preference(for: normalMedicationID) == false)
	}

	@Test("Persisting an empty dictionary removes the payload")
	func emptyDictionaryRemovesPayload() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults)
		#expect(store.save(true, for: UUID()))

		#expect(store.replaceAll(with: [:]))

		#expect(fixture.defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) == nil)
		#expect(store.allPreferences() == [:])
	}

	@Test("Invalid payload blocks mutations without changing stored data")
	func invalidPayloadBlocksMutations() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let invalidData = Data("not-json".utf8)
		fixture.defaults.set(invalidData, forKey: UserDefaultsKeys.medicationNotificationUrgency)
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults)
		let medicationID = UUID()

		#expect(store.allPreferences() == nil)
		#expect(!store.save(true, for: medicationID))
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == invalidData)
		#expect(!store.removePreference(for: medicationID))
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == invalidData)
		#expect(!store.replaceAll(with: [medicationID.uuidString: false]))
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == invalidData)
	}

	@Test("Failed write verification restores the exact prior payload")
	func failedWriteRestoresPriorPayload() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let existingMedicationID = UUID()
		let priorData = try JSONEncoder().encode([existingMedicationID.uuidString: false])
		fixture.defaults.set(priorData, forKey: UserDefaultsKeys.medicationNotificationUrgency)
		let store = MedicationNotificationUrgencyStore(
			defaults: fixture.defaults,
			writer: { data, destination, key in
				guard
					let preferences = try? JSONDecoder().decode([String: Bool].self, from: data)
				else {
					return
				}
				let encoder = JSONEncoder()
				encoder.outputFormatting = .prettyPrinted
				guard let rewrittenData = try? encoder.encode(preferences) else {
					return
				}
				destination.set(rewrittenData, forKey: key)
			}
		)

		#expect(!store.save(true, for: UUID()))
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == priorData)
	}

	@Test("Failed first write restores payload absence")
	func failedFirstWriteRestoresAbsence() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let store = MedicationNotificationUrgencyStore(
			defaults: fixture.defaults,
			writer: { _, destination, key in
				destination.set(Data("verification-failure".utf8), forKey: key)
			}
		)

		#expect(!store.save(true, for: UUID()))
		#expect(fixture.defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) == nil)
	}

	@Test("Failed removal verification restores the exact prior payload")
	func failedRemovalRestoresPriorPayload() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let medicationID = UUID()
		let priorData = try JSONEncoder().encode([medicationID.uuidString: false])
		fixture.defaults.set(priorData, forKey: UserDefaultsKeys.medicationNotificationUrgency)
		let store = MedicationNotificationUrgencyStore(
			defaults: fixture.defaults,
			remover: { destination, key in
				destination.removeObject(forKey: key)
				destination.set(Data("verification-failure".utf8), forKey: key)
			}
		)

		#expect(!store.replaceAll(with: [:]))
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == priorData)
	}

	@Test("Filtering removes unknown and malformed medication IDs")
	func filteringRemovesUnknownAndMalformedIDs() {
		let validMedicationID = UUID()
		let unknownMedicationID = UUID()
		let preferences = [
			validMedicationID.uuidString: false,
			unknownMedicationID.uuidString: true,
			"not-a-uuid": true,
		]

		let filtered = MedicationNotificationUrgencyStore.filteredPreferences(
			preferences,
			validMedicationIDs: [validMedicationID]
		)

		#expect(filtered == [validMedicationID.uuidString: false])
	}

	@Test("Filtering canonicalizes lowercase IDs for preference access")
	func filteringCanonicalizesLowercaseIDs() throws {
		let medicationID = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let filtered = MedicationNotificationUrgencyStore.filteredPreferences(
			[medicationID.uuidString.lowercased(): false],
			validMedicationIDs: [medicationID]
		)
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults)

		#expect(filtered == [medicationID.uuidString: false])
		#expect(store.replaceAll(with: filtered))
		#expect(store.preference(for: medicationID) == false)
	}

	@Test("Canonical key wins over duplicate case variants")
	func canonicalKeyWinsOverCaseVariant() throws {
		let medicationID = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
		let filtered = MedicationNotificationUrgencyStore.filteredPreferences(
			[
				medicationID.uuidString: false,
				medicationID.uuidString.lowercased(): true,
			],
			validMedicationIDs: [medicationID]
		)

		#expect(filtered == [medicationID.uuidString: false])
	}

	@Test("Migration marker is verified and independent of preference payload")
	func migrationMarkerIsIndependent() throws {
		let fixture = try makeDefaults()
		defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
		let store = MedicationNotificationUrgencyStore(defaults: fixture.defaults)
		let medicationID = UUID()

		#expect(!store.migrationCompleted)
		#expect(store.save(true, for: medicationID))
		#expect(!store.migrationCompleted)

		#expect(store.markMigrationCompleted())

		#expect(store.migrationCompleted)
		#expect(fixture.defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted) as? Bool == true)
		#expect(store.preference(for: medicationID) == true)
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) != nil)
	}
}

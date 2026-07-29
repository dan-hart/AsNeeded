@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationNotificationUrgencyStore Tests", .serialized, .tags(.unit))
@MainActor
struct MedicationNotificationUrgencyStoreTests {
	private func makeDefaults() -> UserDefaults {
		let suiteName = "MedicationNotificationUrgencyStoreTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName) ?? .standard
		defaults.removePersistentDomain(forName: suiteName)
		return defaults
	}

	@Test("Missing preference resolves to normal without creating a preference")
	func missingPreferenceResolvesToNormal() {
		let store = MedicationNotificationUrgencyStore(defaults: makeDefaults())
		let medicationID = UUID()

		#expect(store.preference(for: medicationID) == nil)
		#expect(!store.isUrgent(for: medicationID))
		#expect(store.preference(for: medicationID) == nil)
	}

	@Test("Explicit true and false preferences survive store recreation")
	func explicitPreferencesPersist() {
		let defaults = makeDefaults()
		let urgentMedicationID = UUID()
		let normalMedicationID = UUID()
		let store = MedicationNotificationUrgencyStore(defaults: defaults)

		#expect(store.save(true, for: urgentMedicationID))
		#expect(store.save(false, for: normalMedicationID))

		let recreatedStore = MedicationNotificationUrgencyStore(defaults: defaults)
		#expect(recreatedStore.preference(for: urgentMedicationID) == true)
		#expect(recreatedStore.preference(for: normalMedicationID) == false)
		#expect(recreatedStore.isUrgent(for: urgentMedicationID))
		#expect(!recreatedStore.isUrgent(for: normalMedicationID))
	}

	@Test("Medication preferences remain isolated")
	func medicationPreferencesRemainIsolated() {
		let store = MedicationNotificationUrgencyStore(defaults: makeDefaults())
		let firstMedicationID = UUID()
		let secondMedicationID = UUID()

		#expect(store.save(true, for: firstMedicationID))

		#expect(store.preference(for: firstMedicationID) == true)
		#expect(store.preference(for: secondMedicationID) == nil)
	}

	@Test("Removing one preference preserves other medication preferences")
	func removingOnePreferencePreservesOthers() {
		let store = MedicationNotificationUrgencyStore(defaults: makeDefaults())
		let removedMedicationID = UUID()
		let retainedMedicationID = UUID()
		#expect(store.save(true, for: removedMedicationID))
		#expect(store.save(false, for: retainedMedicationID))

		#expect(store.removePreference(for: removedMedicationID))

		#expect(store.preference(for: removedMedicationID) == nil)
		#expect(store.preference(for: retainedMedicationID) == false)
	}

	@Test("Replacing all preferences preserves explicit false")
	func replaceAllPreservesExplicitFalse() {
		let store = MedicationNotificationUrgencyStore(defaults: makeDefaults())
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
	func emptyDictionaryRemovesPayload() {
		let defaults = makeDefaults()
		let store = MedicationNotificationUrgencyStore(defaults: defaults)
		#expect(store.save(true, for: UUID()))

		#expect(store.replaceAll(with: [:]))

		#expect(defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgency) == nil)
		#expect(store.allPreferences() == [:])
	}

	@Test("Invalid payload blocks mutations without changing stored data")
	func invalidPayloadBlocksMutations() {
		let defaults = makeDefaults()
		let invalidData = Data("not-json".utf8)
		defaults.set(invalidData, forKey: UserDefaultsKeys.medicationNotificationUrgency)
		let store = MedicationNotificationUrgencyStore(defaults: defaults)
		let medicationID = UUID()

		#expect(store.allPreferences() == nil)
		#expect(!store.save(true, for: medicationID))
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == invalidData)
		#expect(!store.removePreference(for: medicationID))
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == invalidData)
		#expect(!store.replaceAll(with: [medicationID.uuidString: false]))
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) == invalidData)
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

	@Test("Migration marker is verified and independent of preference payload")
	func migrationMarkerIsIndependent() {
		let defaults = makeDefaults()
		let store = MedicationNotificationUrgencyStore(defaults: defaults)
		let medicationID = UUID()

		#expect(!store.migrationCompleted)
		#expect(store.save(true, for: medicationID))
		#expect(!store.migrationCompleted)

		#expect(store.markMigrationCompleted())

		#expect(store.migrationCompleted)
		#expect(defaults.object(forKey: UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted) as? Bool == true)
		#expect(store.preference(for: medicationID) == true)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationNotificationUrgency) != nil)
	}
}

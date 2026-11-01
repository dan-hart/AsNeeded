import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationSafetyProfileStore Tests", .tags(.unit))
struct MedicationSafetyProfileStoreTests {
	private func makeDefaults() -> UserDefaults {
		let suiteName = "MedicationSafetyProfileStoreTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName) ?? .standard
		defaults.removePersistentDomain(forName: suiteName)
		return defaults
	}

	@Test("Saving and loading a medication safety profile round trips")
	func saveAndLoadProfile() {
		let defaults = makeDefaults()
		let store = MedicationSafetyProfileStore(defaults: defaults)
		let medicationID = UUID()
		let profile = MedicationSafetyProfile(
			minimumHoursBetweenDoses: 4,
			cautionHoursBetweenDoses: 6,
			maxDailyAmount: 8,
			duplicateDoseWindowMinutes: 45,
			lowStockThreshold: 12,
			refillLeadDays: 6
		)

		store.save(profile, for: medicationID)

		#expect(store.profile(for: medicationID) == profile)
	}

	@Test("Saving an empty profile removes stored data")
	func saveEmptyProfileRemovesStoredData() {
		let defaults = makeDefaults()
		let store = MedicationSafetyProfileStore(defaults: defaults)
		let medicationID = UUID()
		let configured = MedicationSafetyProfile(
			minimumHoursBetweenDoses: 4,
			cautionHoursBetweenDoses: nil,
			maxDailyAmount: nil,
			duplicateDoseWindowMinutes: 30,
			lowStockThreshold: nil,
			refillLeadDays: 5
		)

		store.save(configured, for: medicationID)
		store.save(.empty, for: medicationID)

		#expect(store.profile(for: medicationID) == .empty)
		#expect(defaults.data(forKey: UserDefaultsKeys.medicationSafetyProfiles) == nil)
	}

	@Test("Profiles are filtered to valid medication IDs during import")
	func filterProfilesToValidMedicationIDs() {
		let validID = UUID()
		let invalidID = UUID()
		let profiles: [String: MedicationSafetyProfile] = [
			validID.uuidString: MedicationSafetyProfile(minimumHoursBetweenDoses: 4),
			invalidID.uuidString: MedicationSafetyProfile(maxDailyAmount: 6),
		]

		let filtered = MedicationSafetyProfileStore.filteredProfiles(
			from: profiles,
			validMedicationIDs: [validID.uuidString]
		)

		#expect(filtered.count == 1)
		#expect(filtered[validID.uuidString]?.minimumHoursBetweenDoses == 4)
		#expect(filtered[invalidID.uuidString] == nil)
	}
}

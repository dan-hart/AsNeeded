import ANModelKit
import Foundation

/// Moves only the legacy dosing guardrails into the medication record.
/// No paths or database formats change. A failed write leaves its source intact for retry.
@MainActor
struct MedicationDoseLimitMigration {
	private static var productionTask: Task<Void, Error>?

	func migrate(dataStore: DataStore) async throws {
		if let task = Self.productionTask {
			try await task.value
			return
		}
		let task = Task { @MainActor in
			try await dataStore.medicationsStore.itemsHaveLoaded()
			try await dataStore.eventsStore.itemsHaveLoaded()
			try await migrate(medications: dataStore.medications, profileStore: .shared) { medication in
				try await dataStore.saveMigratedMedication(medication)
			}
		}
		Self.productionTask = task
		defer { Self.productionTask = nil }
		try await task.value
	}

	func migrate(
		medications: [ANMedicationConcept],
		profileStore: MedicationSafetyProfileStore,
		save: (ANMedicationConcept) async throws -> Void
	) async throws {
		for medication in medications {
			let legacy = profileStore.profile(for: medication.id)
			guard legacy.minimumHoursBetweenDoses != nil || legacy.maxDailyAmount != nil else { continue }
			var updated = medication
			if updated.minimumHoursBetweenDoses == nil {
				updated.minimumHoursBetweenDoses = legacy.minimumHoursBetweenDoses
			}
			if updated.maximumDailyDoseAmount == nil {
				updated.maximumDailyDoseAmount = legacy.maxDailyAmount
			}
			try await save(updated)
			// The persistence suspension can overlap a guardrail edit. Clear only the
			// dosing values read for this write, preserving every newer profile field.
			var current = profileStore.profile(for: medication.id)
			if current.minimumHoursBetweenDoses == legacy.minimumHoursBetweenDoses {
				current.minimumHoursBetweenDoses = nil
			}
			if current.maxDailyAmount == legacy.maxDailyAmount {
				current.maxDailyAmount = nil
			}
			if current != profileStore.profile(for: medication.id) {
				profileStore.save(current, for: medication.id)
			}
		}
	}
}

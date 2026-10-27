import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Dose limit migration", .tags(.unit))
struct MedicationDoseLimitMigrationTests {
	@Test("Legacy limits migrate once, preserving model values and other guardrails")
	func migrationAndRestart() async throws {
		let suite = "DoseLimitMigration.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		let profiles = MedicationSafetyProfileStore(defaults: defaults, mirrorToSharedDefaults: false)
		var medication = ANMedicationConcept(clinicalName: "Test")
		medication.minimumHoursBetweenDoses = 8
		profiles.save(.init(minimumHoursBetweenDoses: 4, cautionHoursBetweenDoses: 6, maxDailyAmount: 6), for: medication.id)
		var saved: [ANMedicationConcept] = []
		try await MedicationDoseLimitMigration().migrate(medications: [medication], profileStore: profiles) { saved.append($0) }
		let migrated = try #require(saved.first)
		#expect(migrated.minimumHoursBetweenDoses == 8)
		#expect(migrated.maximumDailyDoseAmount == 6)
		#expect(migrated.nextDoseNotificationEnabled != true)
		#expect(profiles.profile(for: medication.id).minimumHoursBetweenDoses == nil)
		#expect(profiles.profile(for: medication.id).maxDailyAmount == nil)
		#expect(profiles.profile(for: medication.id).cautionHoursBetweenDoses == 6)
		var cleared = migrated
		cleared.maximumDailyDoseAmount = nil
		try await MedicationDoseLimitMigration().migrate(medications: [cleared], profileStore: profiles) { saved.append($0) }
		#expect(saved.count == 1)
	}

	@Test("Migration cleanup preserves guardrail edits made while persistence is suspended")
	func cleanupPreservesConcurrentGuardrailEdits() async throws {
		let suite = "DoseLimitMigration.Concurrent.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		let profiles = MedicationSafetyProfileStore(defaults: defaults, mirrorToSharedDefaults: false)
		let medication = ANMedicationConcept(clinicalName: "Test")
		profiles.save(.init(minimumHoursBetweenDoses: 4, cautionHoursBetweenDoses: 6, maxDailyAmount: 8), for: medication.id)
		try await MedicationDoseLimitMigration().migrate(medications: [medication], profileStore: profiles) { _ in
			await Task.yield()
			profiles.save(.init(minimumHoursBetweenDoses: 4, cautionHoursBetweenDoses: 10, maxDailyAmount: 8, lowStockThreshold: 20), for: medication.id)
		}
		let remaining = profiles.profile(for: medication.id)
		#expect(remaining.minimumHoursBetweenDoses == nil)
		#expect(remaining.maxDailyAmount == nil)
		#expect(remaining.cautionHoursBetweenDoses == 10)
		#expect(remaining.lowStockThreshold == 20)
	}

	@Test("Migration cleanup retains newer legacy limits for a later reconciliation")
	func cleanupPreservesConcurrentDoseLimitEdits() async throws {
		let suite = "DoseLimitMigration.NewLimits.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		let profiles = MedicationSafetyProfileStore(defaults: defaults, mirrorToSharedDefaults: false)
		let medication = ANMedicationConcept(clinicalName: "Test")
		profiles.save(.init(minimumHoursBetweenDoses: 4, maxDailyAmount: 8), for: medication.id)
		try await MedicationDoseLimitMigration().migrate(medications: [medication], profileStore: profiles) { _ in
			await Task.yield()
			profiles.save(.init(minimumHoursBetweenDoses: 6, maxDailyAmount: 12), for: medication.id)
		}
		#expect(profiles.profile(for: medication.id).minimumHoursBetweenDoses == 6)
		#expect(profiles.profile(for: medication.id).maxDailyAmount == 12)
	}

	@Test("Failed persistence retains legacy limits for retry")
	func failedWrite() async throws {
		enum Failure: Error { case write }
		let suite = "DoseLimitMigration.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		let profiles = MedicationSafetyProfileStore(defaults: defaults, mirrorToSharedDefaults: false)
		let medication = ANMedicationConcept(clinicalName: "Test")
		profiles.save(.init(minimumHoursBetweenDoses: 4), for: medication.id)
		do {
			try await MedicationDoseLimitMigration().migrate(medications: [medication], profileStore: profiles) { _ in throw Failure.write }
			Issue.record("Migration should propagate write failure")
		} catch {
			#expect(profiles.profile(for: medication.id).minimumHoursBetweenDoses == 4)
		}
	}

	@Test("Fresh and model-only medications do not write or gain defaults")
	func noLegacyValues() async throws {
		let suite = "DoseLimitMigration.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		let profiles = MedicationSafetyProfileStore(defaults: defaults, mirrorToSharedDefaults: false)
		let fresh = ANMedicationConcept(clinicalName: "Fresh")
		var modelOnly = ANMedicationConcept(clinicalName: "Model")
		modelOnly.maximumDailyDoseAmount = 6
		var writes = 0
		try await MedicationDoseLimitMigration().migrate(medications: [fresh, modelOnly], profileStore: profiles) { _ in writes += 1 }
		#expect(writes == 0)
	}
}

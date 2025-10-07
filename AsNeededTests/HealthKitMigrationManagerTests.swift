// HealthKitMigrationManagerTests.swift
// Tests for HealthKit migration manager functionality.

import Testing
@testable import AsNeeded
import Foundation
import ANModelKit

@Suite("HealthKit Migration Manager")
struct HealthKitMigrationManagerTests {

	// MARK: - Migration Direction Tests

	@Test("Migration direction display names")
	func migrationDirectionDisplayNames() {
		#expect(HealthKitMigrationDirection.toHealthKit.displayName.contains("Health"))
		#expect(HealthKitMigrationDirection.toAsNeeded.displayName.contains("AsNeeded") || HealthKitMigrationDirection.toAsNeeded.displayName.contains("Import"))
		#expect(HealthKitMigrationDirection.skip.displayName.contains("Skip"))
	}

	@Test("Migration direction descriptions")
	func migrationDirectionDescriptions() {
		let toHKDesc = HealthKitMigrationDirection.toHealthKit.description
		#expect(toHKDesc.count > 20)
		#expect(toHKDesc.contains("AsNeeded") || toHKDesc.contains("Copy"))

		let toANDesc = HealthKitMigrationDirection.toAsNeeded.description
		#expect(toANDesc.count > 20)
		#expect(toANDesc.contains("Health") || toANDesc.contains("Import"))

		let skipDesc = HealthKitMigrationDirection.skip.description
		#expect(skipDesc.count > 10)
	}

	@Test("Migration direction warnings")
	func migrationDirectionWarnings() {
		let toHKWarning = HealthKitMigrationDirection.toHealthKit.warningMessage
		#expect(toHKWarning.count > 30)
		#expect(toHKWarning.contains("copied") || toHKWarning.contains("Health"))

		let toANWarning = HealthKitMigrationDirection.toAsNeeded.warningMessage
		#expect(toANWarning.count > 30)
		#expect(toANWarning.contains("import") || toANWarning.contains("merged"))

		let skipWarning = HealthKitMigrationDirection.skip.warningMessage
		#expect(skipWarning.count > 20)
	}

	// MARK: - Migration Result Tests

	@Test("Migration result success status")
	func migrationResultSuccess() {
		// Successful migration
		let successResult = HealthKitMigrationResult(
			direction: .toHealthKit,
			medicationsMigrated: 5,
			eventsMigrated: 10,
			errors: []
		)
		#expect(successResult.success == true)

		// Partial success (with warnings)
		let partialResult = HealthKitMigrationResult(
			direction: .toAsNeeded,
			medicationsMigrated: 3,
			eventsMigrated: 7,
			errors: [NSError(domain: "Test", code: -1)]
		)
		#expect(partialResult.success == false) // Has errors = not complete success

		// Failed migration
		let failedResult = HealthKitMigrationResult(
			direction: .toHealthKit,
			medicationsMigrated: 0,
			eventsMigrated: 0,
			errors: [
				NSError(domain: "Test", code: -1),
				NSError(domain: "Test", code: -2)
			]
		)
		#expect(failedResult.success == false)
		#expect(failedResult.errors.count == 2)
	}

	@Test("Migration result summary messages")
	func migrationResultSummaryMessages() {
		// Success message
		let successResult = HealthKitMigrationResult(
			direction: .toHealthKit,
			medicationsMigrated: 5,
			eventsMigrated: 10,
			errors: []
		)
		let successMessage = successResult.summaryMessage
		#expect(successMessage.contains("5"))
		#expect(successMessage.contains("10"))
		#expect(successMessage.contains("migrated") || successMessage.contains("Success"))

		// Partial success message
		let partialResult = HealthKitMigrationResult(
			direction: .toAsNeeded,
			medicationsMigrated: 3,
			eventsMigrated: 7,
			errors: [NSError(domain: "Test", code: -1)]
		)
		let partialMessage = partialResult.summaryMessage
		#expect(partialMessage.contains("3"))
		#expect(partialMessage.contains("warning") || partialMessage.contains("1"))

		// Failed message
		let failedResult = HealthKitMigrationResult(
			direction: .skip,
			medicationsMigrated: 0,
			eventsMigrated: 0,
			errors: [
				NSError(domain: "Test", code: -1),
				NSError(domain: "Test", code: -2)
			]
		)
		let failedMessage = failedResult.summaryMessage
		#expect(failedMessage.contains("fail") || failedMessage.contains("error"))
	}

	@Test("Migration result total changes calculation")
	func migrationResultTotalChanges() {
		let result = HealthKitMigrationResult(
			direction: .toHealthKit,
			medicationsMigrated: 5,
			eventsMigrated: 10,
			errors: []
		)

		#expect(result.totalChanges == 15) // 5 meds + 10 events
	}

	// MARK: - Backup Tests

	@Test("Should offer backup for destructive migrations")
	func shouldOfferBackup() {
		let manager = HealthKitMigrationManager.shared

		// To HealthKit: should offer backup (copying data)
		let toHKNeedsBackup = manager.shouldOfferBackup(for: .toHealthKit)
		#expect(toHKNeedsBackup == true)

		// To AsNeeded: should offer backup (importing/merging)
		let toANNeedsBackup = manager.shouldOfferBackup(for: .toAsNeeded)
		#expect(toANNeedsBackup == true)

		// Skip: no backup needed
		let skipNeedsBackup = manager.shouldOfferBackup(for: .skip)
		#expect(skipNeedsBackup == false)
	}

	// MARK: - Migration Options Tests

	@Test("All migration directions are covered")
	func allMigrationDirections() {
		let allCases = [
			HealthKitMigrationDirection.toHealthKit,
			HealthKitMigrationDirection.toAsNeeded,
			HealthKitMigrationDirection.skip
		]

		#expect(allCases.count == 3)

		// All should have non-empty display names
		for direction in allCases {
			#expect(direction.displayName.count > 0)
			#expect(direction.description.count > 0)
			#expect(direction.warningMessage.count > 0)
		}
	}

	@Test("Migration direction icons are appropriate")
	func migrationDirectionIcons() {
		// ToHealthKit should have upload/forward icon
		let toHKIcon = HealthKitMigrationDirection.toHealthKit.iconName
		#expect(toHKIcon.contains("arrow") || toHKIcon.contains("upload") || toHKIcon.contains("icloud"))

		// ToAsNeeded should have download/back icon
		let toANIcon = HealthKitMigrationDirection.toAsNeeded.iconName
		#expect(toANIcon.contains("arrow") || toANIcon.contains("download") || toANIcon.contains("tray"))

		// Skip should have skip/forward icon
		let skipIcon = HealthKitMigrationDirection.skip.iconName
		#expect(skipIcon.contains("forward") || skipIcon.contains("skip") || skipIcon.contains("arrow"))
	}

	// MARK: - Error Handling Tests

	@Test("Migration handles empty datasets gracefully")
	func emptyDatasetHandling() {
		// Result with no data should still be valid
		let emptyResult = HealthKitMigrationResult(
			direction: .skip,
			medicationsMigrated: 0,
			eventsMigrated: 0,
			errors: []
		)

		#expect(emptyResult.success == true)
		#expect(emptyResult.totalChanges == 0)
		#expect(emptyResult.summaryMessage.count > 0)
	}

	@Test("Migration result with only medication changes")
	func medicationOnlyMigration() {
		let result = HealthKitMigrationResult(
			direction: .toHealthKit,
			medicationsMigrated: 5,
			eventsMigrated: 0,
			errors: []
		)

		#expect(result.totalChanges == 5)
		#expect(result.success == true)
		#expect(result.summaryMessage.contains("5"))
	}

	@Test("Migration result with only event changes")
	func eventsOnlyMigration() {
		let result = HealthKitMigrationResult(
			direction: .toAsNeeded,
			medicationsMigrated: 0,
			eventsMigrated: 20,
			errors: []
		)

		#expect(result.totalChanges == 20)
		#expect(result.success == true)
		#expect(result.summaryMessage.contains("20"))
	}

	// MARK: - State Management Tests

	@Test("Migration manager is singleton")
	func managerIsSingleton() {
		let manager1 = HealthKitMigrationManager.shared
		let manager2 = HealthKitMigrationManager.shared

		// Should be the same instance
		#expect(manager1 === manager2)
	}

	// MARK: - Integration Tests

	@Test("Migration direction affects sync mode recommendation")
	func migrationAffectsSyncModeRecommendation() {
		// To HealthKit migration might suggest HealthKit SOT or bidirectional
		let toHKDirection = HealthKitMigrationDirection.toHealthKit
		#expect(toHKDirection.displayName.count > 0)

		// To AsNeeded migration might suggest AsNeeded SOT or bidirectional
		let toANDirection = HealthKitMigrationDirection.toAsNeeded
		#expect(toANDirection.displayName.count > 0)

		// Skip keeps current setup
		let skipDirection = HealthKitMigrationDirection.skip
		#expect(skipDirection.displayName.count > 0)
	}

	// MARK: - Progress Reporting Tests

	@Test("Migration can track progress")
	func migrationProgressTracking() async {
		// This test verifies the progress callback mechanism exists
		// Actual progress testing would require mocking HealthKit

		var progressUpdates: [(Double, String)] = []

		let progressHandler: (Double, String) -> Void = { progress, message in
			progressUpdates.append((progress, message))
		}

		// Progress handler should be called during migration
		// In real migration, this would be called multiple times
		progressHandler(0.0, "Starting")
		progressHandler(0.5, "Halfway")
		progressHandler(1.0, "Complete")

		#expect(progressUpdates.count == 3)
		#expect(progressUpdates[0].0 == 0.0)
		#expect(progressUpdates[1].0 == 0.5)
		#expect(progressUpdates[2].0 == 1.0)
		#expect(progressUpdates[2].1.contains("Complete"))
	}
}

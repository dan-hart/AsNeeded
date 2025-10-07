// HealthKitMigrationOptions.swift
// Options for migrating data between AsNeeded and HealthKit.

import Foundation

/// Data migration options when setting up or changing HealthKit sync
enum HealthKitMigrationDirection: String, Codable, CaseIterable, Identifiable {
	/// Migrate data from AsNeeded to HealthKit
	case toHealthKit

	/// Migrate data from HealthKit to AsNeeded
	case toAsNeeded

	/// Skip migration and use current state
	case skip

	var id: String { rawValue }

	/// User-facing display name
	var displayName: String {
		switch self {
		case .toHealthKit:
			return "Copy to Apple Health"
		case .toAsNeeded:
			return "Import from Apple Health"
		case .skip:
			return "Skip Migration"
		}
	}

	/// Short description of the migration
	var shortDescription: String {
		switch self {
		case .toHealthKit:
			return "Copy your AsNeeded medications and dose history to Apple Health"
		case .toAsNeeded:
			return "Import medications and doses from Apple Health into AsNeeded"
		case .skip:
			return "Keep your data as-is and proceed with sync"
		}
	}

	/// Detailed explanation of what will happen
	var detailedDescription: String {
		switch self {
		case .toHealthKit:
			return "All medications and dose events currently in AsNeeded will be copied to Apple Health. Existing Health data won't be modified. This is useful if you have historical data in AsNeeded that you want available in Health."
		case .toAsNeeded:
			return "All medications and dose events from Apple Health will be imported into AsNeeded. Existing AsNeeded data will be merged with Health data. This is useful if you've been using Apple Health to track medications and want to bring that history into AsNeeded."
		case .skip:
			return "No data will be moved. You'll start syncing from this point forward with your data in its current state. Choose this if you want to start fresh or if you've already manually synced your data."
		}
	}

	/// Warning message if this option could cause data issues
	var warningMessage: String? {
		switch self {
		case .toHealthKit:
			return "This will copy all your AsNeeded data to Health. Make sure you have enough iCloud storage if you have a large medication history."
		case .toAsNeeded:
			return "This will import Health data into AsNeeded. If you have a large medication history in Health, this may take a few minutes."
		case .skip:
			return nil
		}
	}

	/// Whether a backup should be offered before this migration
	var shouldOfferBackup: Bool {
		switch self {
		case .toHealthKit:
			return false // We're copying, not deleting
		case .toAsNeeded:
			return true // We're modifying local storage
		case .skip:
			return false
		}
	}
}

/// Result of a migration operation
struct HealthKitMigrationResult {
	/// Number of medications migrated
	let medicationsMigrated: Int

	/// Number of dose events migrated
	let eventsMigrated: Int

	/// Whether the migration completed successfully
	let success: Bool

	/// Any errors that occurred during migration
	let errors: [Error]

	/// Duration of the migration
	let duration: TimeInterval

	/// User-facing summary message
	var summaryMessage: String {
		if success && errors.isEmpty {
			return "Successfully migrated \(medicationsMigrated) medication(s) and \(eventsMigrated) dose event(s)."
		} else if success && !errors.isEmpty {
			return "Migrated \(medicationsMigrated) medication(s) and \(eventsMigrated) dose event(s) with \(errors.count) warning(s)."
		} else {
			return "Migration failed. \(errors.count) error(s) occurred."
		}
	}
}

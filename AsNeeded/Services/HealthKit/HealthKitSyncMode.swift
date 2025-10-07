// HealthKitSyncMode.swift
// Defines the three synchronization modes between AsNeeded and HealthKit.

import Foundation

/// Synchronization mode between AsNeeded local storage and Apple HealthKit
enum HealthKitSyncMode: String, Codable, CaseIterable, Identifiable {
	/// Bidirectional sync - keep both databases in sync
	/// - AsNeeded writes to both Boutique and HealthKit
	/// - Data is read from both sources and merged
	/// - Best for most users who want comprehensive tracking
	case bidirectional

	/// HealthKit as source of truth
	/// - AsNeeded reads from HealthKit but does NOT write to Boutique
	/// - All data lives in HealthKit only
	/// - WARNING: Data export will not be available
	/// - Best for users who manage medications primarily in Health app
	case healthKitSOT

	/// AsNeeded as source of truth
	/// - AsNeeded writes to both Boutique and HealthKit
	/// - Boutique is the primary storage, HealthKit is a backup
	/// - Data export includes all local data
	/// - Best for users who want full control and local backup
	case asNeededSOT

	var id: String { rawValue }

	/// User-facing display name
	var displayName: String {
		switch self {
		case .bidirectional:
			return "Sync with Health"
		case .healthKitSOT:
			return "Health as Primary"
		case .asNeededSOT:
			return "AsNeeded as Primary"
		}
	}

	/// Short description of the sync mode
	var shortDescription: String {
		switch self {
		case .bidirectional:
			return "Keep everything in sync between AsNeeded and Apple Health"
		case .healthKitSOT:
			return "Manage medications in Apple Health, view in AsNeeded"
		case .asNeededSOT:
			return "Manage in AsNeeded, backup to Apple Health"
		}
	}

	/// Detailed explanation of how this mode works
	var detailedDescription: String {
		switch self {
		case .bidirectional:
			return "AsNeeded and Apple Health stay synchronized. When you log a dose in either app, it appears in both. Your medication history is available everywhere."
		case .healthKitSOT:
			return "All medication data lives in Apple Health. AsNeeded displays your Health data but doesn't store it locally. Note: Data export will not be available in AsNeeded."
		case .asNeededSOT:
			return "AsNeeded stores all data locally and syncs copies to Apple Health. You have full control and can export your data anytime."
		}
	}

	/// Pros of using this sync mode
	var pros: [String] {
		switch self {
		case .bidirectional:
			return [
				"Works seamlessly with both apps",
				"Data available on all devices",
				"Best of both worlds",
				"Full data export available"
			]
		case .healthKitSOT:
			return [
				"Single source of truth in Health",
				"Consistent with other Health data",
				"No duplicate storage",
				"iCloud sync via Health"
			]
		case .asNeededSOT:
			return [
				"Full local control",
				"Complete data export",
				"Works offline",
				"Health app as backup"
			]
		}
	}

	/// Cons or limitations of this sync mode
	var cons: [String] {
		switch self {
		case .bidirectional:
			return [
				"Requires managing sync conflicts",
				"Uses storage in both locations"
			]
		case .healthKitSOT:
			return [
				"No data export from AsNeeded",
				"Limited offline access",
				"Must manage in Health app"
			]
		case .asNeededSOT:
			return [
				"Primary management in AsNeeded",
				"Health app may show duplicates if modified there"
			]
		}
	}

	/// Whether this mode allows local data export
	var allowsDataExport: Bool {
		switch self {
		case .bidirectional, .asNeededSOT:
			return true
		case .healthKitSOT:
			return false
		}
	}

	/// Whether this mode writes to local Boutique storage
	var writesToLocalStorage: Bool {
		switch self {
		case .bidirectional, .asNeededSOT:
			return true
		case .healthKitSOT:
			return false
		}
	}

	/// Whether this mode writes to HealthKit
	var writesToHealthKit: Bool {
		return true // All modes write to HealthKit
	}
}

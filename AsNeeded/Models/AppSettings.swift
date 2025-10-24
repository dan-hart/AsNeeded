// AppSettings.swift
// Codable model for exportable app settings

import Foundation

/// Represents exportable app settings that can be included in data exports and backups
struct AppSettings: Codable {
	// MARK: - App Preferences

	/// Whether haptic feedback is enabled
	var hapticsEnabled: Bool?

	/// Currently selected tab index
	var selectedTab: Int?

	// MARK: - Display Settings

	/// Trends visualization type (chart, list, etc.)
	var trendsVisualizationType: Int?

	/// Trends time window in days (14 or 30)
	var trendsDaysWindow: Int?

	/// Whether to hide support banners
	var hideSupportBanners: Bool?

	// MARK: - Notification Settings

	/// Whether to show medication names in notifications
	var showMedicationNamesInNotifications: Bool?

	// MARK: - Typography Settings

	/// Selected font family for app-wide text display
	var selectedFontFamily: String?

	// MARK: - Feature Toggles

	/// Feature toggle for quick note phrases
	var featureToggleQuickPhrases: Bool?

	// MARK: - Automatic Backup Settings

	/// Whether automatic backup is enabled
	var automaticBackupEnabled: Bool?

	/// Whether to redact medication names in automatic backups
	var automaticBackupRedactMedicationNames: Bool?

	/// Whether to redact notes in automatic backups
	var automaticBackupRedactNotes: Bool?

	/// Number of days to retain automatic backups before deletion
	var automaticBackupRetentionDays: Int?

	/// Whether to include app settings in automatic backups
	var automaticBackupIncludeSettings: Bool?

	// MARK: - Medication ID References
	// Note: These will be validated after import to ensure referenced medications exist

	/// Selected medication ID for history tab
	var historySelectedMedicationID: String?

	/// Selected medication ID for trends tab
	var trendsSelectedMedicationID: String?

	/// Order of medications in the list
	var medicationOrder: [String]?

	// MARK: - Search Settings

	/// Recent medication search terms
	var recentMedicationSearches: [String]?

	// MARK: - Initialization

	/// Create empty settings (all nil)
	init() {}

	/// Create settings from UserDefaults
	/// - Parameter defaults: UserDefaults instance to read from (default: .standard)
	init(from defaults: UserDefaults = .standard) {
		// App Preferences
		hapticsEnabled = defaults.object(forKey: UserDefaultsKeys.hapticsEnabled) as? Bool
		selectedTab = defaults.object(forKey: UserDefaultsKeys.selectedTab) as? Int

		// Display Settings
		trendsVisualizationType = defaults.object(forKey: UserDefaultsKeys.trendsVisualizationType) as? Int
		trendsDaysWindow = defaults.object(forKey: UserDefaultsKeys.trendsDaysWindow) as? Int
		hideSupportBanners = defaults.object(forKey: UserDefaultsKeys.hideSupportBanners) as? Bool

		// Notification Settings
		showMedicationNamesInNotifications = defaults.object(forKey: UserDefaultsKeys.showMedicationNamesInNotifications) as? Bool

		// Typography Settings
		selectedFontFamily = defaults.string(forKey: UserDefaultsKeys.selectedFontFamily)

		// Feature Toggles
		featureToggleQuickPhrases = defaults.object(forKey: UserDefaultsKeys.featureToggleQuickPhrases) as? Bool

		// Automatic Backup Settings
		automaticBackupEnabled = defaults.object(forKey: UserDefaultsKeys.automaticBackupEnabled) as? Bool
		automaticBackupRedactMedicationNames = defaults.object(forKey: UserDefaultsKeys.automaticBackupRedactMedicationNames) as? Bool
		automaticBackupRedactNotes = defaults.object(forKey: UserDefaultsKeys.automaticBackupRedactNotes) as? Bool
		automaticBackupRetentionDays = defaults.object(forKey: UserDefaultsKeys.automaticBackupRetentionDays) as? Int
		automaticBackupIncludeSettings = defaults.object(forKey: UserDefaultsKeys.automaticBackupIncludeSettings) as? Bool

		// Medication ID References (will be validated after import)
		historySelectedMedicationID = defaults.string(forKey: UserDefaultsKeys.historySelectedMedicationID)
		trendsSelectedMedicationID = defaults.string(forKey: UserDefaultsKeys.trendsSelectedMedicationID)
		medicationOrder = defaults.array(forKey: UserDefaultsKeys.medicationOrder) as? [String]

		// Search Settings
		recentMedicationSearches = defaults.array(forKey: UserDefaultsKeys.recentMedicationSearches) as? [String]
	}

	// MARK: - Export/Import

	/// Apply these settings to UserDefaults
	/// - Parameter defaults: UserDefaults instance to write to (default: .standard)
	/// - Parameter validateMedicationIDs: Closure to validate medication IDs exist, returns set of valid IDs
	func apply(to defaults: UserDefaults = .standard, validateMedicationIDs: () -> Set<String>) {
		let validMedicationIDs = validateMedicationIDs()

		// App Preferences
		if let value = hapticsEnabled {
			defaults.set(value, forKey: UserDefaultsKeys.hapticsEnabled)
		}
		if let value = selectedTab {
			defaults.set(value, forKey: UserDefaultsKeys.selectedTab)
		}

		// Display Settings
		if let value = trendsVisualizationType {
			defaults.set(value, forKey: UserDefaultsKeys.trendsVisualizationType)
		}
		if let value = trendsDaysWindow {
			defaults.set(value, forKey: UserDefaultsKeys.trendsDaysWindow)
		}
		if let value = hideSupportBanners {
			defaults.set(value, forKey: UserDefaultsKeys.hideSupportBanners)
		}

		// Notification Settings
		if let value = showMedicationNamesInNotifications {
			defaults.set(value, forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
		}

		// Typography Settings
		if let value = selectedFontFamily {
			defaults.set(value, forKey: UserDefaultsKeys.selectedFontFamily)
		}

		// Feature Toggles
		if let value = featureToggleQuickPhrases {
			defaults.set(value, forKey: UserDefaultsKeys.featureToggleQuickPhrases)
		}

		// Automatic Backup Settings
		if let value = automaticBackupEnabled {
			defaults.set(value, forKey: UserDefaultsKeys.automaticBackupEnabled)
		}
		if let value = automaticBackupRedactMedicationNames {
			defaults.set(value, forKey: UserDefaultsKeys.automaticBackupRedactMedicationNames)
		}
		if let value = automaticBackupRedactNotes {
			defaults.set(value, forKey: UserDefaultsKeys.automaticBackupRedactNotes)
		}
		if let value = automaticBackupRetentionDays {
			defaults.set(value, forKey: UserDefaultsKeys.automaticBackupRetentionDays)
		}
		if let value = automaticBackupIncludeSettings {
			defaults.set(value, forKey: UserDefaultsKeys.automaticBackupIncludeSettings)
		}

		// Medication ID References - Validate before applying
		if let value = historySelectedMedicationID, validMedicationIDs.contains(value) {
			defaults.set(value, forKey: UserDefaultsKeys.historySelectedMedicationID)
		} else if historySelectedMedicationID != nil {
			// Clear invalid reference
			defaults.removeObject(forKey: UserDefaultsKeys.historySelectedMedicationID)
		}

		if let value = trendsSelectedMedicationID, validMedicationIDs.contains(value) {
			defaults.set(value, forKey: UserDefaultsKeys.trendsSelectedMedicationID)
		} else if trendsSelectedMedicationID != nil {
			// Clear invalid reference
			defaults.removeObject(forKey: UserDefaultsKeys.trendsSelectedMedicationID)
		}

		if let value = medicationOrder {
			// Filter out invalid medication IDs
			let validOrder = value.filter { validMedicationIDs.contains($0) }
			if !validOrder.isEmpty {
				defaults.set(validOrder, forKey: UserDefaultsKeys.medicationOrder)
			} else {
				defaults.removeObject(forKey: UserDefaultsKeys.medicationOrder)
			}
		}

		// Search Settings
		if let value = recentMedicationSearches {
			defaults.set(value, forKey: UserDefaultsKeys.recentMedicationSearches)
		}

		// Synchronize to ensure changes are persisted
		defaults.synchronize()
	}

	/// Get a user-friendly summary of included settings categories
	var settingsCategories: [String] {
		var categories: [String] = []

		// Check which categories have non-nil values
		if hapticsEnabled != nil || selectedTab != nil {
			categories.append("App Preferences")
		}
		if trendsVisualizationType != nil || trendsDaysWindow != nil || hideSupportBanners != nil {
			categories.append("Display Settings")
		}
		if showMedicationNamesInNotifications != nil {
			categories.append("Notification Settings")
		}
		if selectedFontFamily != nil {
			categories.append("Typography")
		}
		if featureToggleQuickPhrases != nil {
			categories.append("Feature Toggles")
		}
		if automaticBackupEnabled != nil || automaticBackupRedactMedicationNames != nil ||
			automaticBackupRedactNotes != nil || automaticBackupRetentionDays != nil
		{
			categories.append("Automatic Backup Settings")
		}
		if historySelectedMedicationID != nil || trendsSelectedMedicationID != nil || medicationOrder != nil {
			categories.append("View Selections")
		}
		if recentMedicationSearches != nil {
			categories.append("Search History")
		}

		return categories
	}
}

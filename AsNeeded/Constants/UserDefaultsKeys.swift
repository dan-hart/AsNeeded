// UserDefaultsKeys.swift
// Centralized constants for all UserDefaults/AppStorage keys

import Foundation

/// Centralized UserDefaults keys for maintainability and testing
public enum UserDefaultsKeys {
	// MARK: - Medication Settings
	/// Selected medication ID for history tab
	static let historySelectedMedicationID = "historySelectedMedicationID"
	
	/// Selected medication ID for trends tab
	static let trendsSelectedMedicationID = "trendsSelectedMedicationID"
	
	/// Order of medications in the list
	static let medicationOrder = "medicationOrder"
	
	// MARK: - App Preferences
	/// Whether the user has seen the welcome screen
	static let hasSeenWelcome = "hasSeenWelcome"
	
	/// Whether to show welcome on next launch (set during reset, cleared on launch)
	static let shouldShowWelcomeOnNextLaunch = "shouldShowWelcomeOnNextLaunch"
	
	/// Whether haptic feedback is enabled
	static let hapticsEnabled = "hapticsEnabled"
	
	/// Currently selected tab index
	static let selectedTab = "selectedTab"
	
	// MARK: - Display Settings
	/// Trends visualization type (chart, list, etc.)
	static let trendsVisualizationType = "trendsVisualizationType"
	
	/// Whether to hide support banners
	static let hideSupportBanners = "hideSupportBanners"
	
	// MARK: - Notification Settings
	/// Whether to show medication names in notifications
	static let showMedicationNamesInNotifications = "showMedicationNamesInNotifications"

	// MARK: - Typography Settings
	/// Selected font family for app-wide text display
	static let selectedFontFamily = "selectedFontFamily"

	// MARK: - Feature Toggles
	/// Feature toggle for quick note phrases
	static let featureToggleQuickPhrases = "featureToggle.quickPhrases"

	// MARK: - All Keys
	/// Array of all UserDefaults keys for iteration/testing
	public static let allKeys: [String] = [
		historySelectedMedicationID,
		trendsSelectedMedicationID,
		medicationOrder,
		hasSeenWelcome,
		shouldShowWelcomeOnNextLaunch,
		hapticsEnabled,
		selectedTab,
		trendsVisualizationType,
		hideSupportBanners,
		showMedicationNamesInNotifications,
		selectedFontFamily,
		featureToggleQuickPhrases
	]
	
	// MARK: - Default Values
	/// Default values for each key when resetting
	nonisolated(unsafe) public static let defaultValues: [String: Any] = [
		// hasSeenWelcome is handled specially - not reset immediately
		shouldShowWelcomeOnNextLaunch: true, // Set flag to show welcome on next launch
		hapticsEnabled: true,
		selectedTab: 0,
		trendsVisualizationType: 0, // Chart view
		hideSupportBanners: false,
		showMedicationNamesInNotifications: false,
		selectedFontFamily: "system", // Default to system font
		featureToggleQuickPhrases: false // Feature toggles default to OFF
	]
	
	// MARK: - Keys to Remove
	/// Keys that should be removed (not set to a default) when resetting
	public static let keysToRemove: Set<String> = [
		historySelectedMedicationID,
		trendsSelectedMedicationID,
		medicationOrder
	]
	
	// MARK: - Keys to Skip
	/// Keys that should not be touched during reset (handled specially)
	public static let keysToSkip: Set<String> = [
		hasSeenWelcome // Don't reset immediately, handled by shouldShowWelcomeOnNextLaunch
	]
}
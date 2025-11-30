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

    /// Trends time window in days (14 or 30)
    static let trendsDaysWindow = "trendsDaysWindow"

    /// Whether to hide support banners
    static let hideSupportBanners = "hideSupportBanners"

    // MARK: - Notification Settings

    /// Whether to show medication names in notifications
    static let showMedicationNamesInNotifications = "showMedicationNamesInNotifications"

    // MARK: - Typography Settings

    /// Selected font family for app-wide text display
    static let selectedFontFamily = "selectedFontFamily"

    // MARK: - App Review & Analytics

    /// Whether the user has opted out of review requests
    static let hasUserOptedOutOfReviews = "hasUserOptedOutOfReviews"

    /// Total number of app launches
    static let appLaunchCount = "appLaunchCount"

    /// Total number of medication events logged
    static let medicationEventsCount = "medicationEventsCount"

    /// Number of consecutive days the app has been used
    static let consecutiveDaysOfUse = "consecutiveDaysOfUse"

    /// Date of last app usage
    static let lastAppUseDate = "lastAppUseDate"

    /// Date of last review request shown to user
    static let lastReviewRequestDate = "lastReviewRequestDate"

    /// Number of review requests shown to user
    static let reviewRequestsShown = "reviewRequestsShown"

    /// Number of review requests dismissed by user
    static let reviewRequestsDismissed = "reviewRequestsDismissed"

    // MARK: - Analytics Service

    /// Date of first app launch
    static let analyticsFirstLaunchDate = "analytics.firstLaunchDate"

    /// Total analytics launch count
    static let analyticsLaunchCount = "analytics.launchCount"

    /// Date of last app launch
    static let analyticsLastLaunchDate = "analytics.lastLaunchDate"

    /// Total medications added
    static let analyticsTotalMedicationsAdded = "analytics.totalMedicationsAdded"

    /// Total events logged
    static let analyticsTotalEventsLogged = "analytics.totalEventsLogged"

    /// Date of last data export
    static let analyticsLastExportDate = "analytics.lastExportDate"

    /// Date of last data import
    static let analyticsLastImportDate = "analytics.lastImportDate"

    /// Dictionary of most used features with counts
    static let analyticsMostUsedFeatures = "analytics.mostUsedFeatures"

    /// Date tracking daily active use
    static let analyticsDailyActiveUse = "analytics.dailyActiveUse"

    // MARK: - Search

    /// Recent medication search terms
    static let recentMedicationSearches = "RecentMedicationSearches"

    // MARK: - Automatic Backup

    /// Whether automatic backup is enabled
    static let automaticBackupEnabled = "automaticBackup.enabled"

    /// Security-scoped bookmark data for backup location
    static let automaticBackupLocationBookmark = "automaticBackup.locationBookmark"

    /// Whether to redact medication names in automatic backups
    static let automaticBackupRedactMedicationNames = "automaticBackup.redactMedicationNames"

    /// Whether to redact notes in automatic backups
    static let automaticBackupRedactNotes = "automaticBackup.redactNotes"

    /// Date of last successful automatic backup
    static let automaticBackupLastBackupDate = "automaticBackup.lastBackupDate"

    /// Date of last cleanup run
    static let automaticBackupLastCleanupDate = "automaticBackup.lastCleanupDate"

    /// Number of days to retain automatic backups before deletion
    static let automaticBackupRetentionDays = "automaticBackup.retentionDays"

    /// Whether to include app settings in automatic backups
    static let automaticBackupIncludeSettings = "automaticBackup.includeSettings"

    // MARK: - Data Import/Export

    /// Default behavior when importing data that contains settings ("keep" or "import")
    static let importSettingsDefaultBehavior = "importSettings.defaultBehavior"

    // MARK: - Storage Schema Versioning

    /// Current storage schema version - tracks database structure for migrations
    /// Increment when changing storage paths, database structure, or file formats
    /// See StorageConstants.swift for the current version number
    static let storageSchemaVersion = "storage.schemaVersion"

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
        trendsDaysWindow,
        hideSupportBanners,
        showMedicationNamesInNotifications,
        selectedFontFamily,
        hasUserOptedOutOfReviews,
        appLaunchCount,
        medicationEventsCount,
        consecutiveDaysOfUse,
        lastAppUseDate,
        lastReviewRequestDate,
        reviewRequestsShown,
        reviewRequestsDismissed,
        analyticsFirstLaunchDate,
        analyticsLaunchCount,
        analyticsLastLaunchDate,
        analyticsTotalMedicationsAdded,
        analyticsTotalEventsLogged,
        analyticsLastExportDate,
        analyticsLastImportDate,
        analyticsMostUsedFeatures,
        analyticsDailyActiveUse,
        recentMedicationSearches,
        automaticBackupEnabled,
        automaticBackupLocationBookmark,
        automaticBackupRedactMedicationNames,
        automaticBackupRedactNotes,
        automaticBackupLastBackupDate,
        automaticBackupLastCleanupDate,
        automaticBackupRetentionDays,
        automaticBackupIncludeSettings,
        importSettingsDefaultBehavior,
        storageSchemaVersion,
    ]

    // MARK: - Default Values

    /// Default values for each key when resetting
    public nonisolated(unsafe) static let defaultValues: [String: Any] = [
        // hasSeenWelcome is handled specially - not reset immediately
        shouldShowWelcomeOnNextLaunch: true, // Set flag to show welcome on next launch
        hapticsEnabled: true,
        selectedTab: 0,
        trendsVisualizationType: 0, // Chart view
        trendsDaysWindow: 14, // 14 days by default
        hideSupportBanners: false,
        showMedicationNamesInNotifications: false,
        selectedFontFamily: "system", // Default to system font
        hasUserOptedOutOfReviews: false,
        appLaunchCount: 0,
        medicationEventsCount: 0,
        consecutiveDaysOfUse: 0,
        reviewRequestsShown: 0,
        reviewRequestsDismissed: 0,
        analyticsLaunchCount: 0,
        analyticsTotalMedicationsAdded: 0,
        analyticsTotalEventsLogged: 0,
        automaticBackupEnabled: false,
        automaticBackupRedactMedicationNames: false,
        automaticBackupRedactNotes: false,
        automaticBackupRetentionDays: 90,
        automaticBackupIncludeSettings: true, // Include settings by default
        importSettingsDefaultBehavior: "keep", // Default to keeping current settings
    ]

    // MARK: - Keys to Remove

    /// Keys that should be removed (not set to a default) when resetting
    public static let keysToRemove: Set<String> = [
        historySelectedMedicationID,
        trendsSelectedMedicationID,
        medicationOrder,
        lastAppUseDate,
        lastReviewRequestDate,
        analyticsFirstLaunchDate,
        analyticsLastLaunchDate,
        analyticsLastExportDate,
        analyticsLastImportDate,
        analyticsMostUsedFeatures,
        analyticsDailyActiveUse,
        recentMedicationSearches,
        automaticBackupLocationBookmark,
        automaticBackupLastBackupDate,
        automaticBackupLastCleanupDate,
    ]

    // MARK: - Keys to Skip

    /// Keys that should not be touched during reset (handled specially)
    public static let keysToSkip: Set<String> = [
        hasSeenWelcome, // Don't reset immediately, handled by shouldShowWelcomeOnNextLaunch
    ]

    // MARK: - Export/Import Allowlist & Blocklist

    /// Keys that are safe to export and import (allowlist approach)
    /// These settings represent user preferences that can safely be transferred between devices
    public static let safeToExportKeys: Set<String> = [
        // App Preferences
        hapticsEnabled,
        selectedTab,

        // Display Settings
        trendsVisualizationType,
        trendsDaysWindow,
        hideSupportBanners,

        // Notification Settings
        showMedicationNamesInNotifications,

        // Typography Settings
        selectedFontFamily,

        // Automatic Backup Settings (excluding location bookmark and timestamps)
        automaticBackupEnabled,
        automaticBackupRedactMedicationNames,
        automaticBackupRedactNotes,
        automaticBackupRetentionDays,
        automaticBackupIncludeSettings,

        // Medication ID References (will be validated after import)
        historySelectedMedicationID,
        trendsSelectedMedicationID,
        medicationOrder,

        // Search Settings
        recentMedicationSearches,
    ]

    /// Keys that should NEVER be exported (blocklist for security/privacy)
    /// These contain device-specific data, security-scoped bookmarks, or historical analytics
    public static let keysToNeverExport: Set<String> = [
        // Security-scoped bookmarks (device-specific, won't work on other devices)
        automaticBackupLocationBookmark,

        // Historical analytics (device-specific, should not be overwritten)
        analyticsFirstLaunchDate,
        lastAppUseDate,
        analyticsLastLaunchDate,
        analyticsLastExportDate,
        analyticsLastImportDate,

        // Device-specific timestamps
        automaticBackupLastBackupDate,
        automaticBackupLastCleanupDate,
        lastReviewRequestDate,

        // Onboarding state (device-specific)
        hasSeenWelcome,
        shouldShowWelcomeOnNextLaunch,

        // App usage counters (device-specific)
        appLaunchCount,
        medicationEventsCount,
        consecutiveDaysOfUse,
        reviewRequestsShown,
        reviewRequestsDismissed,
        analyticsLaunchCount,
        analyticsTotalMedicationsAdded,
        analyticsTotalEventsLogged,
        analyticsMostUsedFeatures,
        analyticsDailyActiveUse,
        hasUserOptedOutOfReviews,

        // Storage schema version (device-specific, must not be overwritten)
        storageSchemaVersion,
    ]
}

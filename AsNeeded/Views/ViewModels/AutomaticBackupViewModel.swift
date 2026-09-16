// AutomaticBackupViewModel.swift
// View model for automatic backup settings and operations

import Foundation
import SwiftUI

@MainActor
final class AutomaticBackupViewModel: ObservableObject {
    private let manager = AutomaticBackupManager.shared

    // MARK: - Published Properties

    @Published var backupHistory: [BackupFile] = []
    @Published var totalStorageUsed: Int64 = 0
    @Published var showingLocationPicker = false
    @Published var showingClearAllConfirmation = false
    @Published var showingDisableConfirmation = false
    @Published var showingExplainer = false
    @Published var showingRestoreSheet = false
    @Published var showingPrivacyOnboarding = false
    /// True while the setup sheets (privacy options, then the folder picker) are on screen.
    @Published var isSettingUp = false
    /// True while a chosen folder is being bookmarked and its first backup written.
    @Published private(set) var isSavingLocation = false
    /// Name of the configured backup folder. Stored rather than computed because resolving the bookmark
    /// reads the file system, which must not happen while SwiftUI is building the view.
    @Published private(set) var locationName: String?
    /// Set when the privacy sheet is dismissed on the way to the folder picker.
    private var shouldPresentLocationPickerAfterOnboarding = false
    @Published var selectedBackup: BackupFile?
    @Published var alertMessage: String?
    @Published var showingAlert = false
    @Published var successMessage: String?
    @Published var showingSuccess = false
    @Published var showingBackupReconfigAlert = false

    // MARK: - Computed Properties

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled)
    }

    /// Whether the Enable button should read as busy: setup sheets are up, or the location is being saved.
    var isBusy: Bool {
        isSettingUp || isSavingLocation
    }

    var isConfigured: Bool {
        UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) != nil
    }

    var lastBackupDate: Date? {
        manager.lastBackupDate
    }

    var isBackupInProgress: Bool {
        manager.isBackupInProgress
    }

    var statusCardState: StatusCardState {
        if !isEnabled {
            return .disabled
        }

        // If enabled and configured, check bookmark status
        if isConfigured {
            let bookmarkStatus = manager.checkBookmarkStatus()
            switch bookmarkStatus {
            case .bookmarkStale:
                return .warning
            case .accessDenied, .storageFull, .failed:
                return .error
            case .success:
                return .active
            case .none:
                // Configured but no backup yet - still active
                return .active
            }
        } else {
            // Enabled but not configured yet
            return .disabled
        }
    }

    var statusMessage: String {
        switch statusCardState {
        case .active:
            if let lastBackup = lastBackupDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Last backup: \(formatter.localizedString(for: lastBackup, relativeTo: Date()))"
            }
            return "Ready for backup"
        case .warning:
            return "Location may be inaccessible"
        case .error:
            return manager.lastError ?? "Backup error occurred"
        case .disabled:
            return "Not configured"
        }
    }

    var retentionDays: Int {
        get {
            manager.retentionDays
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.automaticBackupRetentionDays)
            objectWillChange.send()
        }
    }

    var automaticBackupRedactMedicationNames: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupRedactMedicationNames)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.automaticBackupRedactMedicationNames)
        }
    }

    var automaticBackupRedactNotes: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupRedactNotes)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.automaticBackupRedactNotes)
        }
    }

    var automaticBackupIncludeSettings: Bool {
        get {
            // Default to true if not explicitly set
            if UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupIncludeSettings) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupIncludeSettings)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.automaticBackupIncludeSettings)
        }
    }

    // MARK: - Initialization

    init() {
        // Reading the backup folder touches the file system, so the view kicks it off from `.task`
        // instead of blocking whoever creates this view model.
    }

    // MARK: - Public Methods

    func loadBackupHistory() async {
        let files = await manager.backupHistory()
        backupHistory = files
        totalStorageUsed = files.reduce(0) { $0 + $1.size }
    }

    /// Refreshes everything the backup screen shows, off the main actor. Called when the screen appears.
    func refreshStatus() async {
        await manager.refreshBookmarkStatus()
        locationName = await manager.backupLocationName()
        await loadBackupHistory()
        objectWillChange.send()
    }

    func enableAutomaticBackup() {
        // Show privacy options first for initial setup
        isSettingUp = true
        showingPrivacyOnboarding = true
    }

    /// Starts the hand-off from the privacy sheet to the folder picker.
    ///
    /// The picker is not presented here: asking UIKit to present it in the same runloop turn that
    /// dismisses the privacy sheet makes the two presentations race, and the picker can silently fail to
    /// appear. `privacyOnboardingDismissed()` presents it once the sheet is actually gone.
    func proceedWithLocationSelection() {
        shouldPresentLocationPickerAfterOnboarding = true
        showingPrivacyOnboarding = false
    }

    /// Called from the privacy sheet's `onDismiss`, after UIKit has finished tearing the sheet down.
    func privacyOnboardingDismissed() {
        if shouldPresentLocationPickerAfterOnboarding {
            shouldPresentLocationPickerAfterOnboarding = false
            showingLocationPicker = true
        } else {
            // Cancelled or swiped away, so setup is over and the Enable button must come back.
            isSettingUp = false
        }
    }

    /// Called when the folder picker goes away for any reason.
    ///
    /// A cancelled picker does not reliably call its completion handler, so clearing setup state here is
    /// what stops the Enable button from being stuck on "Loading..." forever.
    func locationPickerDismissed() {
        isSettingUp = false
    }

    func confirmDisableAutomaticBackup() {
        showingDisableConfirmation = true
    }

    func disableAutomaticBackup() {
        manager.disable()
        backupHistory = []
        totalStorageUsed = 0
        objectWillChange.send()
    }

    /// Marks a folder selection as claimed, before the picker's dismissal clears `isSettingUp`.
    func beginSavingLocation() {
        isSavingLocation = true
    }

    func saveBackupLocation(url: URL) async {
        isSavingLocation = true
        defer {
            isSavingLocation = false
            isSettingUp = false
        }

        do {
            // Access security-scoped resource before creating bookmark
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "Permission denied to access selected location"
                showingAlert = true
                return
            }
            defer {
                url.stopAccessingSecurityScopedResource()
            }

            // Create security-scoped bookmark
            let bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            manager.saveBackupLocation(bookmark: bookmark)
            locationName = url.lastPathComponent
            objectWillChange.send()

            // Perform automatic test backup
            let status = await manager.performManualBackup()
            await manager.refreshBookmarkStatus()

            switch status {
            case .success:
                successMessage = "Automatic backup enabled and initial backup completed successfully"
                showingSuccess = true
                await loadBackupHistory()
            case let .failed(message):
                alertMessage = "Automatic backup enabled, but initial backup failed: \(message)"
                showingAlert = true
            case .bookmarkStale:
                alertMessage = "Backup location is no longer accessible. Please select a new location."
                showingAlert = true
            case let .storageFull(bytes):
                let needed = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                alertMessage = "Not enough storage space. Need \(needed) to complete backup."
                showingAlert = true
            case .accessDenied:
                alertMessage = "Permission denied to access backup location."
                showingAlert = true
            case .none:
                alertMessage = "Backup location not configured."
                showingAlert = true
            }
        } catch {
            alertMessage = "Failed to save backup location: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func changeBackupLocation() {
        showingLocationPicker = true
    }

    func performManualBackup() async {
        let status = await manager.performManualBackup()

        switch status {
        case .success:
            successMessage = "Backup completed successfully"
            showingSuccess = true
            await loadBackupHistory()
        case let .failed(message):
            alertMessage = message
            showingAlert = true
        case .bookmarkStale:
            alertMessage = "Backup location is no longer accessible. Please select a new location."
            showingAlert = true
        case let .storageFull(bytes):
            let needed = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            alertMessage = "Not enough storage space. Need \(needed) to complete backup."
            showingAlert = true
        case .accessDenied:
            alertMessage = "Permission denied to access backup location."
            showingAlert = true
        case .none:
            alertMessage = "Backup location not configured."
            showingAlert = true
        }
    }

    func deleteBackup(at offsets: IndexSet) async {
        let doomed = offsets.compactMap { backupHistory[doesExistAt: $0] }
        for backup in doomed {
            do {
                let url = backup.url
                try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.removeItem(at: url)
                }.value
            } catch {
                alertMessage = "Failed to delete backup: \(error.localizedDescription)"
                showingAlert = true
            }
        }
        await loadBackupHistory()
    }

    func clearAllBackups() async {
        do {
            try await manager.clearAllBackups()
            successMessage = "All backups cleared successfully"
            showingSuccess = true
            await loadBackupHistory()
        } catch {
            alertMessage = "Failed to clear backups: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func selectBackup(_ backup: BackupFile) {
        selectedBackup = backup
        showingRestoreSheet = true
    }

    func restoreFromBackup(mergeExisting: Bool) async {
        guard let backup = selectedBackup else { return }

        // Check if automatic backups are currently configured and working
        let wasAutomaticBackupConfigured = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled) &&
            UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) != nil

        do {
            try await manager.restoreFromBackup(url: backup.url, mergeExisting: mergeExisting)

            // Check if automatic backups are still configured after restore
            let isAutomaticBackupConfiguredAfter = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled) &&
                UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) != nil

            // Alert user if backups were working but are now broken
            if wasAutomaticBackupConfigured && !isAutomaticBackupConfiguredAfter {
                showingBackupReconfigAlert = true
            }

            successMessage = "Data restored successfully from backup"
            showingSuccess = true
            selectedBackup = nil
            showingRestoreSheet = false
        } catch {
            alertMessage = "Failed to restore backup: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func refreshBookmark() {
        showingLocationPicker = true
    }
}

// MARK: - Supporting Types

enum StatusCardState {
    case active
    case warning
    case error
    case disabled
}

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
    @Published var isSettingUp = false
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

    var locationName: String? {
        guard let bookmark = UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        return url.lastPathComponent
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
        loadBackupHistory()
    }

    // MARK: - Public Methods

    func loadBackupHistory() {
        backupHistory = manager.getBackupHistory()
        totalStorageUsed = manager.getTotalBackupSize()
    }

    func enableAutomaticBackup() {
        // Show privacy options first for initial setup
        isSettingUp = true
        showingPrivacyOnboarding = true
    }

    func proceedWithLocationSelection() {
        showingPrivacyOnboarding = false
        showingLocationPicker = true
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

    func saveBackupLocation(url: URL) async {
        defer {
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
            objectWillChange.send()
            loadBackupHistory()

            // Perform automatic test backup
            let status = await manager.performManualBackup()

            switch status {
            case .success:
                successMessage = "Automatic backup enabled and initial backup completed successfully"
                showingSuccess = true
                loadBackupHistory()
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
            loadBackupHistory()
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

    func deleteBackup(at offsets: IndexSet) {
        for index in offsets {
            let backup = backupHistory[index]
            do {
                try FileManager.default.removeItem(at: backup.url)
                loadBackupHistory()
            } catch {
                alertMessage = "Failed to delete backup: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }

    func clearAllBackups() async {
        do {
            try await manager.clearAllBackups()
            successMessage = "All backups cleared successfully"
            showingSuccess = true
            loadBackupHistory()
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

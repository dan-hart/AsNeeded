// DataManagementViewModel.swift
// View model for data management operations (export, import, clear).

import DHLoggingKit
import Foundation
import SwiftUI

@MainActor
final class DataManagementViewModel: ObservableObject {
    private let dataStore: DataStore
    private let logger = DHLogger(category: "DataManagement")

    @Published var isExporting = false
    @Published var isImporting = false
    @Published var isClearing = false
    @Published var isClearingUserData = false
    @Published var isResettingSettings = false
    @Published var isExportingLogs = false
    @Published var showingClearConfirmation = false
    @Published var showingClearUserDataConfirmation = false
    @Published var showingPreClearExportDialog = false
    @Published var showingResetSettingsConfirmation = false
    @Published var showingExportConfirmation = false
    @Published var showingDocumentPicker = false
    @Published var showingLogExportConfirmation = false
    @Published var showingDataShareSheet = false
    @Published var showingLogShareSheet = false
    @Published var exportedDataURL: URL?
    @Published var exportedLogsURL: URL?
    @Published var alertMessage: String?
    @Published var showingAlert = false
    @Published var logCount: Int = 0
    @Published var isLoadingLogCount = false
    @Published var shouldClearAfterExport = false

    // Settings export/import
    @Published var includeSettings = true // Default enabled per requirements
    @Published var importContainsSettings = false
    @Published var showingImportSettingsDialog = false
    @Published var pendingImportURL: URL?
    @Published var pendingImportData: Data?

    // Automatic backup reconfiguration alert
    @Published var showingAutomaticBackupReconfigAlert = false
    @Published var shouldNavigateToAutomaticBackup = false

    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore
        refreshAutomaticBackupStatus()
        Task {
            await fetchLogCount()
        }
    }

    func fetchLogCount() async {
        logger.debug("Fetching log count")
        await MainActor.run {
            self.isLoadingLogCount = true
        }

        defer {
            Task { @MainActor in
                self.isLoadingLogCount = false
            }
        }

        if #available(iOS 15.0, *) {
            let count = await DHLoggingKit.exporter.getLogCount(timeInterval: 86400) // Last 24 hours
            await MainActor.run {
                self.logCount = count
                logger.debug("Log count updated: \(count)")
            }
        } else {
            await MainActor.run {
                self.logCount = 0
            }
        }
    }

    func requestExport() {
        logger.info("Export requested - showing confirmation dialog")
        showingExportConfirmation = true
    }

    func exportData(redactMedicationNames: Bool, redactNotes: Bool) async {
        logger.info("Starting data export - redactMedicationNames: \(redactMedicationNames), redactNotes: \(redactNotes), includeSettings: \(includeSettings)")
        isExporting = true
        defer {
            isExporting = false
            logger.debug("Export process completed - isExporting set to false")
        }

        do {
            logger.debug("Calling dataStore.exportDataAsJSON with redactNames: \(redactMedicationNames), redactNotes: \(redactNotes), includeSettings: \(includeSettings)")
            let data = try await dataStore.exportDataAsJSON(redactNames: redactMedicationNames, redactNotes: redactNotes, includeSettings: includeSettings)
            logger.info("Export data generated successfully - size: \(data.count) bytes")

            // Create a file URL in the documents directory for sharing
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
            let filename = "AsNeeded-Export-\(dateFormatter.string(from: Date())).json"

            // Use documents directory for better compatibility
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                logger.error("Could not access documents directory")
                alertMessage = "Export failed: Could not access documents directory"
                showingAlert = true
                return
            }
            let tempURL = documentsPath.appendingPathComponent(filename)

            // Write with proper attributes
            try data.write(to: tempURL, options: [.atomic])
            logger.debug("Wrote export data to file: \(tempURL.lastPathComponent)")

            // Ensure file is accessible
            _ = tempURL.startAccessingSecurityScopedResource()

            exportedDataURL = tempURL
            showingDataShareSheet = true
            logger.debug("exportedDataURL set - share sheet should be triggered")

            // If this export was part of the clear flow, show clear confirmation after share sheet dismisses
            if shouldClearAfterExport {
                logger.info("Export completed as part of clear flow - will show clear confirmation")
                // The clear confirmation will be shown after user dismisses the share sheet
            }
        } catch {
            logger.error("Export failed", error: error)
            alertMessage = "Export failed: \(error.localizedDescription)"
            showingAlert = true
            shouldClearAfterExport = false // Reset flag on error
        }
    }

    func onShareSheetDismissed() {
        if shouldClearAfterExport {
            logger.info("Share sheet dismissed - showing clear confirmation")
            shouldClearAfterExport = false
            showingClearUserDataConfirmation = true
        }
    }

    func importData(from url: URL) async {
        logger.info("Starting data import from: \(url.lastPathComponent)")
        isImporting = true
        defer {
            isImporting = false
            logger.debug("Import process completed")
        }

        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            logger.error("Failed to access security-scoped resource")
            alertMessage = "Import failed: Unable to access the selected file. Please try again."
            showingAlert = true
            return
        }

        // Ensure we stop accessing the resource when done
        defer {
            url.stopAccessingSecurityScopedResource()
            logger.debug("Stopped accessing security-scoped resource")
        }

        do {
            let data = try Data(contentsOf: url)
            logger.debug("Read data from file, size: \(data.count) bytes")

            // Check if import contains settings
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importData = try decoder.decode(DataExport.self, from: data)

            if let _ = importData.settings {
                logger.info("Import contains settings, checking user preference")
                importContainsSettings = true
                pendingImportData = data

                // Check user's default behavior
                let defaultBehavior = UserDefaults.standard.string(forKey: UserDefaultsKeys.importSettingsDefaultBehavior) ?? "keep"

                if defaultBehavior == "keep" {
                    // Show dialog to confirm keeping settings (user can override)
                    logger.info("Showing import settings dialog (default: keep)")
                    showingImportSettingsDialog = true
                } else {
                    // Show dialog to confirm importing settings (user can override)
                    logger.info("Showing import settings dialog (default: import)")
                    showingImportSettingsDialog = true
                }
            } else {
                // No settings in import, proceed directly
                logger.info("Import does not contain settings, importing data only")
                try await dataStore.importDataFromJSON(data, mergeExisting: false, applySettings: false)
                logger.info("Data imported successfully")

                // Get counts for success message
                let medicationCount = dataStore.medications.count
                let eventCount = dataStore.events.count
                alertMessage = "Data imported successfully\n\(medicationCount) medications, \(eventCount) events"
                showingAlert = true
            }
        } catch {
            logger.error("Import failed", error: error)
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    /// Proceed with import after user confirms settings choice
    func proceedWithImport(applySettings: Bool) async {
        guard let data = pendingImportData else {
            logger.error("No pending import data")
            return
        }

        logger.info("Proceeding with import (applySettings: \(applySettings))")
        isImporting = true
        defer {
            isImporting = false
            pendingImportData = nil
            importContainsSettings = false
        }

        // Check if automatic backups are currently configured and working
        let wasAutomaticBackupConfigured = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled) &&
            UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) != nil

        do {
            try await dataStore.importDataFromJSON(data, mergeExisting: false, applySettings: applySettings)
            logger.info("Data imported successfully with settings choice: \(applySettings)")

            // Check if automatic backups are still configured after import
            let isAutomaticBackupConfiguredAfter = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled) &&
                UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) != nil

            // Alert user if backups were working but are now broken
            if wasAutomaticBackupConfigured && !isAutomaticBackupConfiguredAfter {
                logger.warning("Automatic backups were disabled by import, alerting user")
                showingAutomaticBackupReconfigAlert = true
            }

            // Get counts for success message
            let medicationCount = dataStore.medications.count
            let eventCount = dataStore.events.count
            let baseMessage = applySettings ? "Data and settings imported successfully" : "Data imported successfully (settings kept)"
            alertMessage = "\(baseMessage)\n\(medicationCount) medications, \(eventCount) events"
            showingAlert = true
        } catch {
            logger.error("Import failed", error: error)
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    /// Navigate to automatic backup settings
    func navigateToAutomaticBackup() {
        logger.info("User chose to reconfigure automatic backups")
        shouldNavigateToAutomaticBackup = true
    }

    func clearUserData() async {
        logger.warning("Starting clear user data operation")
        isClearingUserData = true
        defer {
            isClearingUserData = false
            logger.debug("Clear user data process completed")
        }

        do {
            try await dataStore.clearUserData()
            logger.info("User data cleared successfully")
            alertMessage = "All user data (medications and events) cleared successfully"
            showingAlert = true
        } catch {
            logger.error("Clear user data failed", error: error)
            alertMessage = "Clear data failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func resetAppSettings() async {
        logger.warning("Starting reset app settings operation")
        isResettingSettings = true
        defer {
            isResettingSettings = false
            logger.debug("Reset app settings process completed")
        }

        await dataStore.resetAppSettings()
        logger.info("App settings reset successfully")
        alertMessage = "App settings restored to defaults successfully"
        showingAlert = true
    }

    func clearAllData() async {
        logger.warning("Starting reset and clear all data operation")
        isClearing = true
        defer {
            isClearing = false
            logger.debug("Reset and clear data process completed")
        }

        do {
            try await dataStore.clearAllData()
            logger.info("All data cleared and settings reset successfully")
            alertMessage = "All data cleared and settings restored to defaults"
            showingAlert = true
        } catch {
            logger.error("Reset and clear data failed", error: error)
            alertMessage = "Reset failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func confirmClearUserData() {
        logger.info("Clear user data confirmation requested - showing pre-export dialog")
        showingPreClearExportDialog = true
    }

    func handlePreClearExportChoice(shouldExport: Bool) {
        logger.info("User chose to \(shouldExport ? "export before clearing" : "clear without exporting")")

        if shouldExport {
            shouldClearAfterExport = true
            // Show export confirmation sheet
            showingExportConfirmation = true
        } else {
            // Skip export and go directly to clear confirmation
            showingClearUserDataConfirmation = true
        }
    }

    func confirmResetSettings() {
        logger.info("Reset settings confirmation requested")
        showingResetSettingsConfirmation = true
    }

    func confirmClearData() {
        logger.info("Clear data confirmation requested")
        showingClearConfirmation = true
    }

    func requestLogExport() {
        logger.info("Log export requested - showing time period dialog")
        showingLogExportConfirmation = true
    }

    func exportLogs(timeInterval: TimeInterval = 3600) async {
        isExportingLogs = true
        defer { isExportingLogs = false }

        do {
            var logData: Data
            if #available(iOS 15.0, *) {
                logData = try await DHLoggingKit.exporter.exportLogs(timeInterval: timeInterval)
            } else {
                logData = "Log export requires iOS 15.0 or later. This device is running iOS \(UIDevice.current.systemVersion).".data(using: .utf8) ?? Data()
            }

            // Create a file URL in the documents directory for sharing
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
            let filename = "AsNeeded-Logs-\(dateFormatter.string(from: Date())).txt"

            // Use documents directory for better compatibility
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                logger.error("Could not access documents directory")
                alertMessage = "Log export failed: Could not access documents directory"
                showingAlert = true
                return
            }
            let tempURL = documentsPath.appendingPathComponent(filename)

            // Write with proper attributes
            try logData.write(to: tempURL, options: [.atomic])
            logger.debug("Wrote log data to file: \(tempURL.lastPathComponent)")

            // Ensure file is accessible
            _ = tempURL.startAccessingSecurityScopedResource()

            exportedLogsURL = tempURL
            showingLogShareSheet = true
            logger.debug("exportedLogsURL set - share sheet should be triggered")
        } catch {
            alertMessage = "Log export failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    var medicationCount: Int {
        dataStore.medications.count
    }

    var eventCount: Int {
        dataStore.events.count
    }

    // MARK: - Automatic Backup

    /// Used by navigation link to show status
    @Published var isAutomaticBackupEnabled: Bool = false
    @Published var lastAutomaticBackupDate: Date?

    /// Refresh automatic backup status from UserDefaults
    func refreshAutomaticBackupStatus() {
        isAutomaticBackupEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled)
        lastAutomaticBackupDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupLastBackupDate) as? Date
    }
}

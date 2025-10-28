// DataStore.swift
// Centralized Boutique stores and high-level persistence operations.

import ANModelKit
import Boutique
import DHLoggingKit
import Foundation

@MainActor
public final class DataStore {
    public static let shared = DataStore()
    private let logger = DHLogger.data

    // App Group identifier for shared storage with widgets
    private static let appGroupIdentifier = "group.com.codedbydan.AsNeeded"

    // Underlying Boutique stores
    public let medicationsStore: Store<ANMedicationConcept>
    public let eventsStore: Store<ANEventConcept>

    public var medications: [ANMedicationConcept] { medicationsStore.items }
    public var events: [ANEventConcept] { eventsStore.items }

    private init() {
        logger.info("Initializing DataStore with persistent storage in App Group")

        // Get shared container URL for App Group
        guard let sharedContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) else {
            // CRITICAL: App Group is REQUIRED for data storage
            // If App Group is unavailable, the app cannot function correctly
            // This should NEVER happen if MigrationCoordinator succeeded
            logger.error("❌ FATAL: Unable to access App Group container: \(Self.appGroupIdentifier)")
            logger.error("This indicates a critical configuration issue:")
            logger.error("1. App Group entitlement may be missing or misconfigured")
            logger.error("2. Provisioning profile may not include App Group")
            logger.error("3. Migration may have failed (check MigrationCoordinator error)")
            logger.error("")
            logger.error("Cannot continue without App Group access - app will crash")
            logger.error("User data is at risk if we fall back to default container")

            fatalError("""
                App Group container is unavailable: \(Self.appGroupIdentifier)

                This is a CRITICAL error. The app requires App Group access for data storage.

                Possible causes:
                1. App Group entitlement missing or misconfigured
                2. Provisioning profile doesn't include App Group
                3. Data migration failed (check migration logs)

                Please check:
                - Xcode project capabilities
                - Provisioning profile configuration
                - Migration coordinator error state

                If you're seeing this error, please report it with full logs.
                """)
        }

        logger.info("Using shared container at: \(sharedContainerURL.path)")

        // Initialize stores with shared container path using FileManager.Directory
        logger.info("Creating SQLiteStorageEngine for medications database...")
        guard let medicationsStorage = try? SQLiteStorageEngine(
            directory: FileManager.Directory(url: sharedContainerURL),
            databaseFilename: "medications"
        ) else {
            logger.error("❌ FATAL: Failed to create SQLiteStorageEngine for medications")
            fatalError("Failed to initialize medications storage engine")
        }
        logger.info("✅ Medications storage engine created successfully")

        logger.info("Creating SQLiteStorageEngine for events database...")
        guard let eventsStorage = try? SQLiteStorageEngine(
            directory: FileManager.Directory(url: sharedContainerURL),
            databaseFilename: "events"
        ) else {
            logger.error("❌ FATAL: Failed to create SQLiteStorageEngine for events")
            fatalError("Failed to initialize events storage engine")
        }
        logger.info("✅ Events storage engine created successfully")

        logger.info("Initializing Boutique stores...")
        medicationsStore = Store<ANMedicationConcept>(
            storage: medicationsStorage,
            cacheIdentifier: \ANMedicationConcept.id.uuidString
        )
        eventsStore = Store<ANEventConcept>(
            storage: eventsStorage,
            cacheIdentifier: \ANEventConcept.id.uuidString
        )
        logger.info("✅ Boutique stores initialized successfully")

        // Log detailed initialization diagnostics
        logInitializationDiagnostics(containerURL: sharedContainerURL)

        logger.info("✅ DataStore initialized in APP GROUP: \(medications.count) medications, \(events.count) events")

        // Note: Migration is now handled by MigrationCoordinator before DataStore is accessed
        // See AsNeededApp.swift and MigrationCoordinator.swift for migration flow
    }

    // Test initializer using isolated test storage
    public init(testIdentifier: String) {
        let testId = UUID().uuidString
        medicationsStore = Store<ANMedicationConcept>(
            storage: SQLiteStorageEngine.default(appendingPath: "test_medications_\(testIdentifier)_\(testId)"),
            cacheIdentifier: \ANMedicationConcept.id.uuidString
        )
        eventsStore = Store<ANEventConcept>(
            storage: SQLiteStorageEngine.default(appendingPath: "test_events_\(testIdentifier)_\(testId)"),
            cacheIdentifier: \ANEventConcept.id.uuidString
        )
    }

    // MARK: - Medication Operations

    public func addMedication(_ med: ANMedicationConcept) async throws {
        logger.logMedicationOperation("Adding", id: med.id)
        do {
            try await medicationsStore.insert(med)
            logger.logMedicationOperation("Successfully added to local storage", id: med.id)
        } catch {
            logger.error("Failed to add medication \(med.id.uuidString): \(error.localizedDescription)")
            throw error
        }
    }

    public func updateMedication(_ med: ANMedicationConcept) async throws {
        logger.logMedicationOperation("Updating", id: med.id)
        do {
            // Boutique has no explicit update; remove + insert to replace by id.
            try await medicationsStore.remove(med)
            try await medicationsStore.insert(med)
            logger.logMedicationOperation("Successfully updated in local storage", id: med.id)
        } catch {
            logger.error("Failed to update medication \(med.id.uuidString): \(error.localizedDescription)")
            throw error
        }
    }

    public func deleteMedication(_ med: ANMedicationConcept) async throws {
        logger.logMedicationOperation("Deleting", id: med.id)
        do {
            // Find associated events first
            let associatedEvents = events.filter { $0.medication?.id == med.id }
            logger.debug("Found \(associatedEvents.count) associated events to delete")

            for event in associatedEvents {
                try await eventsStore.remove(event)
            }

            try await medicationsStore.remove(med)

            // Clear the deleted medication ID from AppStorage selections to prevent crashes
            let deletedIDString = med.id.uuidString

            // Clear from history view selection
            if UserDefaults.standard.string(forKey: UserDefaultsKeys.historySelectedMedicationID) == deletedIDString {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.historySelectedMedicationID)
                logger.info("Cleared deleted medication from history selection")
            }

            // Clear from trends view selection
            if UserDefaults.standard.string(forKey: UserDefaultsKeys.trendsSelectedMedicationID) == deletedIDString {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.trendsSelectedMedicationID)
                logger.info("Cleared deleted medication from trends selection")
            }

            // Clear from medication order array
            if var order = UserDefaults.standard.array(forKey: UserDefaultsKeys.medicationOrder) as? [String] {
                order.removeAll { $0 == deletedIDString }
                UserDefaults.standard.set(order, forKey: UserDefaultsKeys.medicationOrder)
                logger.info("Removed deleted medication from order array")
            }

            // Clear from navigation manager if it matches
            if NavigationManager.shared.historyTargetMedicationID == deletedIDString {
                NavigationManager.shared.historyTargetMedicationID = nil
                logger.info("Cleared deleted medication from navigation target")
            }

            // Synchronize UserDefaults to ensure changes are persisted
            UserDefaults.standard.synchronize()

            logger.logMedicationOperation("Successfully deleted", id: med.id, details: "\(associatedEvents.count) associated events")
        } catch {
            logger.error("Failed to delete medication \(med.id.uuidString): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Events

    public func addEvent(_ event: ANEventConcept, shouldRecordForReview: Bool = true) async throws {
        logger.logEventOperation("Adding", eventType: event.eventType.rawValue, medicationId: event.medication?.id)
        do {
            try await eventsStore.insert(event)
            logger.info("Successfully added event to local storage: \(event.id)")

            // Track medication event for review eligibility (skip for quick log)
            if shouldRecordForReview {
                await MainActor.run {
                    AppReviewManager.shared.recordMedicationEvent()
                }
            }

            // Trigger automatic backup (debounced)
            await MainActor.run {
                AutomaticBackupManager.shared.triggerBackup()
            }
        } catch {
            logger.error("Failed to add event: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Data Management

    /// Export app settings from UserDefaults
    /// - Returns: AppSettings object with current settings
    private func exportSettings() -> AppSettings {
        logger.debug("Exporting app settings")
        return AppSettings(from: .standard)
    }

    /// Export all data as JSON
    public func exportDataAsJSON(redactNames: Bool = false, redactNotes: Bool = false, includeSettings: Bool = false) async throws -> Data {
        let startTime = Date()
        logger.info("Starting data export (redactNames: \(redactNames), redactNotes: \(redactNotes), includeSettings: \(includeSettings))")

        // Count items before processing
        let medicationCount = medications.count
        let eventCount = events.count
        logger.debug("Source data: \(medicationCount) medications, \(eventCount) events")

        // Redact medication names if requested
        let exportMedications = redactNames ? medications.map { medication in
            var redacted = medication
            redacted.clinicalName = "[REDACTED]"
            redacted.nickname = medication.nickname != nil ? "[REDACTED]" : nil
            return redacted
        } : medications

        // Handle event redaction - redact medication names and/or notes as requested
        var notesRedactedCount = 0
        let exportEvents = events.map { event in
            var modifiedEvent = event

            // Redact medication names if requested (uses built-in redacted() for medication)
            if redactNames {
                modifiedEvent = event.redacted()
            }

            // Additionally redact notes if requested
            if redactNotes, event.note != nil {
                modifiedEvent.note = nil
                notesRedactedCount += 1
            }

            return modifiedEvent
        }

        // Log redaction statistics
        if redactNames || redactNotes {
            let redactedMedCount = redactNames ? medicationCount : 0
            logger.debug("Redaction applied: \(redactedMedCount) medication names, \(notesRedactedCount) notes")
        }

        // Export settings if requested
        let exportedSettings: AppSettings? = includeSettings ? exportSettings() : nil
        if let settings = exportedSettings {
            logger.info("Including app settings in export: \(settings.settingsCategories.joined(separator: ", "))")
        }

        let exportData = DataExport(
            medications: exportMedications,
            events: exportEvents,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            dataVersion: "1.0",
            settings: exportedSettings
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(exportData)
            let duration = Date().timeIntervalSince(startTime)

            // Use enhanced privacy-safe logging
            logger.logExportOperation(
                medicationCount: medicationCount,
                eventCount: eventCount,
                includeSettings: includeSettings,
                redactedMedications: redactNames ? medicationCount : 0,
                redactedNotes: notesRedactedCount,
                fileSize: data.count
            )

            logger.info(String(format: "Export completed in %.2fs", duration))
            return data
        } catch {
            logger.error("Failed to export data: \(error.localizedDescription)")
            throw error
        }
    }

    /// Import app settings to UserDefaults
    /// - Parameter settings: AppSettings to apply
    /// - Parameter defaults: UserDefaults instance to write to
    private func importSettings(_ settings: AppSettings, to defaults: UserDefaults = .standard) {
        logger.info("Importing app settings: \(settings.settingsCategories.joined(separator: ", "))")

        // Get valid medication IDs after import
        let validMedicationIDs = Set(medications.map { $0.id.uuidString })

        // Apply settings with validation
        settings.apply(to: defaults, validateMedicationIDs: { validMedicationIDs })

        logger.info("App settings imported successfully")
    }

    /// Import data from JSON, with options for merge or replace
    public func importDataFromJSON(_ data: Data, mergeExisting: Bool = false, applySettings: Bool = false) async throws {
        let startTime = Date()
        let fileSizeFormatted = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        logger.info("Starting data import (merge: \(mergeExisting), applySettings: \(applySettings), size: \(fileSizeFormatted))")

        // Capture before counts
        let beforeMedicationCount = medications.count
        let beforeEventCount = events.count
        logger.debug("Current data: \(beforeMedicationCount) medications, \(beforeEventCount) events")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importedData: DataExport
        do {
            importedData = try decoder.decode(DataExport.self, from: data)
            logger.info("Decoded import data: \(importedData.medications.count) medications, \(importedData.events.count) events")
        } catch {
            logger.error("Failed to decode import data: \(error.localizedDescription)")
            throw DataImportError.invalidFormat
        }

        // Validate data version
        if let dataVersion = importedData.dataVersion, dataVersion != "1.0" {
            logger.warning("Import data version mismatch: expected 1.0, got \(dataVersion)")
        }

        // Clear existing data if not merging
        if !mergeExisting {
            logger.info("Clearing existing data before import")
            try await clearAllData()
        }

        // Import medications
        var medicationImportCount = 0
        var medicationFailureCount = 0
        var medicationDuplicateCount = 0
        for medication in importedData.medications {
            do {
                if mergeExisting, medications.contains(where: { $0.id == medication.id }) {
                    logger.debug("Skipping duplicate medication: \(medication.id.uuidString)")
                    medicationDuplicateCount += 1
                    continue
                }
                try await medicationsStore.insert(medication)
                medicationImportCount += 1
            } catch {
                logger.error("Failed to import medication \(medication.id.uuidString): \(error.localizedDescription)")
                medicationFailureCount += 1
                // Continue with other medications
            }
        }

        // Import events with medication reference validation
        var eventImportCount = 0
        var eventFailureCount = 0
        var eventDuplicateCount = 0
        var eventValidationFailureCount = 0
        for var event in importedData.events {
            do {
                if mergeExisting, events.contains(where: { $0.id == event.id }) {
                    logger.debug("Skipping duplicate event: \(event.id)")
                    eventDuplicateCount += 1
                    continue
                }

                // Validate and fix medication reference
                if let eventMedication = event.medication {
                    // Check if the medication ID exists in our imported medications
                    if let correctMedication = importedData.medications.first(where: {
                        // Match by clinical name and nickname as fallback if ID doesn't match
                        $0.id == eventMedication.id ||
                            ($0.clinicalName == eventMedication.clinicalName &&
                                $0.nickname == eventMedication.nickname)
                    }) {
                        // Update the event's medication reference to use the correct medication
                        event.medication = correctMedication
                        logger.debug("Validated medication reference for event \(event.id)")
                    } else {
                        // Medication not found, skip this event
                        logger.warning("Skipping event \(event.id): medication \(eventMedication.id.uuidString) not found")
                        eventValidationFailureCount += 1
                        continue
                    }
                }

                try await eventsStore.insert(event)
                eventImportCount += 1
            } catch {
                logger.error("Failed to import event \(event.id): \(error.localizedDescription)")
                eventFailureCount += 1
                // Continue with other events
            }
        }

        // Capture after counts
        let afterMedicationCount = medications.count
        let afterEventCount = events.count

        // Log detailed statistics
        logger.info("Import statistics: Medications: \(medicationImportCount) imported, \(medicationDuplicateCount) duplicates, \(medicationFailureCount) failures")
        logger.info("Import statistics: Events: \(eventImportCount) imported, \(eventDuplicateCount) duplicates, \(eventValidationFailureCount) validation failures, \(eventFailureCount) other failures")

        let duration = Date().timeIntervalSince(startTime)
        let totalValidationFailures = eventValidationFailureCount + medicationFailureCount + eventFailureCount

        // Use enhanced privacy-safe logging
        logger.logImportOperation(
            medicationCount: afterMedicationCount,
            eventCount: afterEventCount,
            includeSettings: applySettings && importedData.settings != nil,
            beforeMedicationCount: beforeMedicationCount,
            beforeEventCount: beforeEventCount,
            validationFailures: totalValidationFailures,
            duration: duration
        )

        // Import settings if present and requested
        if applySettings, let settings = importedData.settings {
            logger.info("Applying imported settings")
            importSettings(settings)
        } else if importedData.settings != nil {
            logger.info("Settings present in import but not applying (applySettings: \(applySettings))")
        }
    }

    /// Clear only user data (medications and events)
    public func clearUserData() async throws {
        logger.warning("Clearing user data (medications and events)")
        do {
            try await medicationsStore.removeAll()
            try await eventsStore.removeAll()
            logger.info("Successfully cleared all user data")
        } catch {
            logger.error("Failed to clear user data: \(error.localizedDescription)")
            throw error
        }
    }

    /// Reset only app settings and user preferences to defaults
    public func resetAppSettings() async {
        logger.warning("Resetting app settings to defaults")
        await MainActor.run {
            // Remove keys that should have no value
            for key in UserDefaultsKeys.keysToRemove {
                UserDefaults.standard.removeObject(forKey: key)
            }

            // Set keys to their default values
            for (key, value) in UserDefaultsKeys.defaultValues {
                UserDefaults.standard.set(value, forKey: key)
            }

            // Clear navigation targets
            NavigationManager.shared.clearHistoryNavigation()

            // Synchronize to ensure changes are persisted
            UserDefaults.standard.synchronize()

            logger.info("Successfully reset all app settings to defaults")
        }
    }

    /// Clear all data from both stores and reset all user preferences
    public func clearAllData() async throws {
        logger.warning("Clearing all data and resetting user preferences")
        do {
            try await clearUserData()
            await resetAppSettings()
            logger.info("Successfully cleared all data and reset preferences")
        } catch {
            logger.error("Failed to clear data: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Initialization Diagnostics

    /// Logs detailed diagnostics during DataStore initialization
    private func logInitializationDiagnostics(containerURL: URL) {
        logger.info("=== DataStore Initialization Diagnostics ===")

        let fileManager = FileManager.default

        // Database file paths
        let medicationsDBPath = containerURL.appendingPathComponent("medications.sqlite")
        let eventsDBPath = containerURL.appendingPathComponent("events.sqlite")

        logger.info("Database paths:")
        logger.info("  Medications: \(medicationsDBPath.path)")
        logger.info("  Events: \(eventsDBPath.path)")

        // Check file existence and sizes
        logFileInfo(at: medicationsDBPath, name: "Medications DB")
        logFileInfo(at: eventsDBPath, name: "Events DB")

        // Check for WAL/SHM files
        checkForWALFiles(basePath: medicationsDBPath.path, name: "Medications")
        checkForWALFiles(basePath: eventsDBPath.path, name: "Events")

        // Available disk space
        if let volumeURL = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            if let resourceValues = try? volumeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
               let availableCapacity = resourceValues.volumeAvailableCapacity {
                let capacityMB = Double(availableCapacity) / 1_048_576 // Convert to MB
                logger.info("Available disk space: \(String(format: "%.2f", capacityMB)) MB")

                if capacityMB < 50 {
                    logger.warning("⚠️ Low disk space: \(String(format: "%.2f", capacityMB)) MB (minimum 50 MB recommended)")
                }
            }
        }

        // Test write permissions
        let testFile = containerURL.appendingPathComponent(".datastore_write_test")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try? fileManager.removeItem(at: testFile)
            logger.info("✅ App Group container is writable")
        } catch {
            logger.error("❌ App Group container is NOT writable: \(error.localizedDescription)")
        }

        // List directory contents
        if let contents = try? fileManager.contentsOfDirectory(atPath: containerURL.path) {
            logger.info("App Group contents (\(contents.count) items): \(contents.joined(separator: ", "))")
        }

        logger.info("=== End Initialization Diagnostics ===")
    }

    /// Logs file information (existence, size, permissions)
    private func logFileInfo(at url: URL, name: String) {
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: url.path)

        if exists {
            if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                let sizeMB = Double(size) / 1_048_576
                logger.info("  \(name): EXISTS (size: \(String(format: "%.2f", sizeMB)) MB)")
            } else {
                logger.info("  \(name): EXISTS (size unknown)")
            }
        } else {
            logger.info("  \(name): DOES NOT EXIST (will be created)")
        }
    }

    /// Checks for and logs WAL (Write-Ahead Log) and SHM (Shared Memory) files
    private func checkForWALFiles(basePath: String, name: String) {
        let fileManager = FileManager.default
        let walPath = "\(basePath)-wal"
        let shmPath = "\(basePath)-shm"

        let walExists = fileManager.fileExists(atPath: walPath)
        let shmExists = fileManager.fileExists(atPath: shmPath)

        if walExists || shmExists {
            logger.info("  \(name) SQLite WAL files:")
            if walExists {
                if let attributes = try? fileManager.attributesOfItem(atPath: walPath),
                   let size = attributes[.size] as? Int64 {
                    logger.info("    - WAL: \(size) bytes")
                }
            }
            if shmExists {
                logger.info("    - SHM: present")
            }
        }
    }
}

/// Structure for data export/import
struct DataExport: Codable {
    let medications: [ANMedicationConcept]
    let events: [ANEventConcept]
    let exportDate: Date
    let appVersion: String
    let dataVersion: String?
    let settings: AppSettings? // Optional app settings for import/export
}

/// Errors for data import/export operations
public enum DataImportError: LocalizedError {
    case invalidFormat
    case versionMismatch(expected: String, actual: String)
    case partialImport(imported: Int, failed: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The import file format is invalid or corrupted"
        case let .versionMismatch(expected, actual):
            return "Data version mismatch: expected \(expected), got \(actual)"
        case let .partialImport(imported, failed):
            return "Partial import: \(imported) items imported, \(failed) failed"
        }
    }
}

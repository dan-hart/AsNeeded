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
            logger.error("Unable to access App Group container: \(Self.appGroupIdentifier)")
            // Fallback to default container if App Group unavailable
            medicationsStore = Store<ANMedicationConcept>(
                storage: SQLiteStorageEngine.default(appendingPath: "medications"),
                cacheIdentifier: \ANMedicationConcept.id.uuidString
            )
            eventsStore = Store<ANEventConcept>(
                storage: SQLiteStorageEngine.default(appendingPath: "events"),
                cacheIdentifier: \ANEventConcept.id.uuidString
            )
            logger.oslog.debug("DataStore initialized with default container: \\(medications.count, privacy: .public) medications, \\(events.count, privacy: .public) events")
            return
        }

        logger.info("Using shared container at: \(sharedContainerURL.path)")

        // Initialize stores with shared container path using FileManager.Directory
        medicationsStore = Store<ANMedicationConcept>(
            storage: SQLiteStorageEngine(
                directory: FileManager.Directory(url: sharedContainerURL),
                databaseFilename: "medications"
            )!,
            cacheIdentifier: \ANMedicationConcept.id.uuidString
        )
        eventsStore = Store<ANEventConcept>(
            storage: SQLiteStorageEngine(
                directory: FileManager.Directory(url: sharedContainerURL),
                databaseFilename: "events"
            )!,
            cacheIdentifier: \ANEventConcept.id.uuidString
        )
        logger.oslog.debug("DataStore initialized: \\(medications.count, privacy: .public) medications, \\(events.count, privacy: .public) events")
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
        logger.info("Starting data export (redactNames: \(redactNames), redactNotes: \(redactNotes), includeSettings: \(includeSettings))")

        // Redact medication names if requested
        let exportMedications = redactNames ? medications.map { medication in
            var redacted = medication
            redacted.clinicalName = "[REDACTED]"
            redacted.nickname = medication.nickname != nil ? "[REDACTED]" : nil
            return redacted
        } : medications

        // Handle event redaction - redact medication names and/or notes as requested
        let exportEvents = events.map { event in
            var modifiedEvent = event

            // Redact medication names if requested (uses built-in redacted() for medication)
            if redactNames {
                modifiedEvent = event.redacted()
            }

            // Additionally redact notes if requested
            if redactNotes {
                modifiedEvent.note = nil
            }

            return modifiedEvent
        }

        logger.debug("Exporting \(exportMedications.count) medications and \(exportEvents.count) events")

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
            logger.info("Successfully exported \(data.count) bytes of data")
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
        logger.info("Starting data import (merge: \(mergeExisting), applySettings: \(applySettings), size: \(data.count) bytes)")

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
        for medication in importedData.medications {
            do {
                if mergeExisting, medications.contains(where: { $0.id == medication.id }) {
                    logger.debug("Skipping duplicate medication: \(medication.id.uuidString)")
                    continue
                }
                try await medicationsStore.insert(medication)
                medicationImportCount += 1
            } catch {
                logger.error("Failed to import medication \(medication.id.uuidString): \(error.localizedDescription)")
                // Continue with other medications
            }
        }

        // Import events with medication reference validation
        var eventImportCount = 0
        for var event in importedData.events {
            do {
                if mergeExisting, events.contains(where: { $0.id == event.id }) {
                    logger.debug("Skipping duplicate event: \(event.id)")
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
                        continue
                    }
                }

                try await eventsStore.insert(event)
                eventImportCount += 1
            } catch {
                logger.error("Failed to import event \(event.id): \(error.localizedDescription)")
                // Continue with other events
            }
        }

        logger.info("Import completed: \(medicationImportCount) medications, \(eventImportCount) events imported")

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

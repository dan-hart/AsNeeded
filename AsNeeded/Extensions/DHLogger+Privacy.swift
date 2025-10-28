// DHLogger+Privacy.swift
// Privacy-safe logging extensions for DHLogger to prevent logging sensitive user data

import DHLoggingKit
import Foundation

extension DHLogger {
    /// Logs a medication operation without exposing medication names
    /// - Parameters:
    ///   - operation: The operation being performed (e.g., "Adding", "Updating", "Deleting")
    ///   - id: The medication UUID
    ///   - details: Optional additional non-sensitive details
    func logMedicationOperation(_ operation: String, id: UUID, details: String? = nil) {
        if let details = details {
            info("\(operation) medication \(id.uuidString): \(details)")
        } else {
            info("\(operation) medication \(id.uuidString)")
        }
    }

    /// Logs an event operation without exposing medication names
    /// - Parameters:
    ///   - operation: The operation being performed
    ///   - eventType: The type of event
    ///   - medicationId: The associated medication UUID (optional)
    func logEventOperation(_ operation: String, eventType: String, medicationId: UUID?) {
        if let medicationId = medicationId {
            info("\(operation) event: \(eventType) for medication: \(medicationId.uuidString)")
        } else {
            info("\(operation) event: \(eventType) (no medication)")
        }
    }

    /// Logs a successful operation with a medication count
    /// - Parameters:
    ///   - operation: The operation that succeeded
    ///   - count: Number of medications involved
    func logMedicationCount(_ operation: String, count: Int) {
        info("\(operation): \(count) medications")
    }

    /// Logs an export operation with privacy-safe details
    /// - Parameters:
    ///   - medicationCount: Number of medications being exported
    ///   - eventCount: Number of events being exported
    ///   - includeSettings: Whether settings are included
    ///   - redactedMedications: Number of medications with names redacted
    ///   - redactedNotes: Number of items with notes redacted
    ///   - fileSize: Size of export file in bytes (optional)
    func logExportOperation(
        medicationCount: Int,
        eventCount: Int,
        includeSettings: Bool,
        redactedMedications: Int = 0,
        redactedNotes: Int = 0,
        fileSize: Int? = nil
    ) {
        var details = "Exporting \(medicationCount) medications, \(eventCount) events"

        if includeSettings {
            details += ", including settings"
        }

        if redactedMedications > 0 {
            details += ", \(redactedMedications) medication names redacted"
        }

        if redactedNotes > 0 {
            details += ", \(redactedNotes) notes redacted"
        }

        if let fileSize = fileSize {
            let sizeFormatted = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            details += ", file size: \(sizeFormatted)"
        }

        info(details)
    }

    /// Logs an import operation with privacy-safe details
    /// - Parameters:
    ///   - medicationCount: Number of medications being imported
    ///   - eventCount: Number of events being imported
    ///   - includeSettings: Whether settings are included
    ///   - beforeMedicationCount: Number of medications before import (optional)
    ///   - beforeEventCount: Number of events before import (optional)
    ///   - validationFailures: Number of items that failed validation (optional)
    ///   - duration: Import duration in seconds (optional)
    func logImportOperation(
        medicationCount: Int,
        eventCount: Int,
        includeSettings: Bool,
        beforeMedicationCount: Int? = nil,
        beforeEventCount: Int? = nil,
        validationFailures: Int = 0,
        duration: TimeInterval? = nil
    ) {
        var details = "Importing \(medicationCount) medications, \(eventCount) events"

        if includeSettings {
            details += ", including settings"
        }

        if let beforeMeds = beforeMedicationCount, let beforeEvents = beforeEventCount {
            let medDelta = medicationCount - beforeMeds
            let eventDelta = eventCount - beforeEvents
            details += " (Δ \(medDelta > 0 ? "+" : "")\(medDelta) meds, \(eventDelta > 0 ? "+" : "")\(eventDelta) events)"
        }

        if validationFailures > 0 {
            details += ", \(validationFailures) validation failures"
        }

        if let duration = duration {
            details += String(format: ", completed in %.2fs", duration)
        }

        info(details)
    }
}

// MARK: - Privacy Guidelines

/*
 PRIVACY LOGGING GUIDELINES:

 ❌ NEVER log:
 - Medication names (clinicalName, nickname, displayName)
 - Personal health information
 - Dose notes or user-entered text
 - Any user-identifiable information

 ✅ SAFE to log:
 - UUIDs (medication IDs, event IDs)
 - Counts (number of medications, events)
 - Operation types (add, update, delete)
 - System information (iOS version, device model)
 - Error messages (as long as they don't contain user data)
 - Timestamps

 When in doubt, use UUIDs instead of names.
 */

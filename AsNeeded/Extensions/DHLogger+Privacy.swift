// DHLogger+Privacy.swift
// Privacy-safe logging extensions for DHLogger to prevent logging sensitive user data

import DHLoggingKit
import Foundation

extension DHLogger {
    /// Returns a diagnostic error type without including localized descriptions that may contain user text or file paths.
    static func privacySafeErrorType(_ error: Error?) -> String {
        guard let error else { return "unknown" }
        return String(reflecting: type(of: error))
    }

    /// Logs an error without exposing localized descriptions, file paths, or user-entered data.
    func logPrivacySafeError(_ message: String, error underlyingError: Error?) {
        error("\(message): errorType=\(Self.privacySafeErrorType(underlyingError))")
    }

    /// Logs a warning without exposing localized descriptions, file paths, or user-entered data.
    func logPrivacySafeWarning(_ message: String, error underlyingError: Error?) {
        warning("\(message): errorType=\(Self.privacySafeErrorType(underlyingError))")
    }

    /// Logs a debug message without exposing localized descriptions, file paths, or user-entered data.
    func logPrivacySafeDebug(_ message: String, error underlyingError: Error?) {
        debug("\(message): errorType=\(Self.privacySafeErrorType(underlyingError))")
    }

    /// Logs a medication operation without exposing medication names or stable identifiers.
    /// - Parameters:
    ///   - operation: The operation being performed (e.g., "Adding", "Updating", "Deleting")
    ///   - id: The medication UUID. Accepted for call-site context, but intentionally not logged.
    ///   - details: Optional additional non-sensitive details
    func logMedicationOperation(_ operation: String, id _: UUID, details: String? = nil) {
        if let details = details {
            info("\(operation) medication record: \(details)")
        } else {
            info("\(operation) medication record")
        }
    }

    /// Logs an event operation without exposing medication names, event types, or stable identifiers.
    /// - Parameters:
    ///   - operation: The operation being performed
    ///   - eventType: The type of event. Accepted for call-site context, but intentionally not logged.
    ///   - medicationId: The associated medication UUID. Accepted for call-site context, but intentionally not logged.
    func logEventOperation(_ operation: String, eventType _: String, medicationId: UUID?) {
        if medicationId != nil {
            info("\(operation) event record: hasMedication=true")
        } else {
            info("\(operation) event record: hasMedication=false")
        }
    }

    /// Logs a dose logging operation without exposing medication names, notes, stable identifiers, or dose values.
    /// - Parameters:
    ///   - phase: The lifecycle phase being logged.
    ///   - source: The UI or integration source for the log request.
    ///   - operationID: Correlation ID shared across the UI, view model, and persistence logs.
    ///   - eventCountBefore: Optional aggregate event count before the operation.
    ///   - eventCountAfter: Optional aggregate event count after the operation.
    ///   - details: Optional non-sensitive diagnostic flags.
    func logDoseOperation(
        _ phase: String,
        source: String,
        operationID: UUID,
        eventCountBefore: Int? = nil,
        eventCountAfter: Int? = nil,
        details: String? = nil
    ) {
        var message = "\(phase) dose log: source=\(source), operationID=\(operationID.uuidString)"

        if let eventCountBefore {
            message += ", eventCountBefore=\(eventCountBefore)"
        }

        if let eventCountAfter {
            message += ", eventCountAfter=\(eventCountAfter)"
        }

        if let details {
            message += ", \(details)"
        }

        info(message)
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
 - Stable medication or event identifiers
 - Dose amounts, units, quantities, or timestamps tied to a medication event
 - Dose notes or user-entered text
 - Any user-identifiable information

 ✅ SAFE to log:
 - Ephemeral operation IDs generated only for a single log action
 - Aggregate counts (number of medications, events)
 - Operation types (add, update, delete)
 - Boolean diagnostic flags
 - System information (iOS version, device model)
 - Error messages (as long as they don't contain user data)

 When in doubt, log less.
 */

// ValidationUtility.swift
// Centralized validation logic for data integrity

import ANModelKit
import DHLoggingKit
import Foundation

public enum ValidationUtility {
    private static let logger = DHLogger(category: "ValidationUtility")

    // MARK: - Name Validation

    /// Validate if a medication name is likely valid
    public static func isValidMedicationName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic validation rules
        guard trimmed.count >= 2, trimmed.count <= 200 else {
            return false
        }

        // Check for invalid characters
        let invalidCharacterSet = CharacterSet(charactersIn: "@#$%^&*()+={}[]|\\:;\"<>?,/")
        if trimmed.rangeOfCharacter(from: invalidCharacterSet) != nil {
            return false
        }

        // Must contain at least one letter
        let letterSet = CharacterSet.letters
        return trimmed.rangeOfCharacter(from: letterSet) != nil
    }

    // MARK: - Medication Validation

    /// Validate a medication before saving
    public static func validateMedication(_ medication: ANMedicationConcept) -> ValidationResult {
        var errors: [ValidationError] = []

        // Validate clinical name
        if medication.clinicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyField(field: "Clinical Name"))
        } else if medication.clinicalName.count > 200 {
            errors.append(.fieldTooLong(field: "Clinical Name", maxLength: 200))
        } else if !ValidationUtility.isValidMedicationName(medication.clinicalName) {
            errors.append(.invalidFormat(field: "Clinical Name", reason: "Contains invalid characters"))
        }

        // Validate nickname if present
        if let nickname = medication.nickname,
           !nickname.isEmpty && nickname.count > 100
        {
            errors.append(.fieldTooLong(field: "Nickname", maxLength: 100))
        }

        // Validate dosage
        if let doseAmount = medication.prescribedDoseAmount {
            if doseAmount <= 0 {
                errors.append(.invalidValue(field: "Dose Amount", reason: "Must be greater than 0"))
            } else if doseAmount > 10000 {
                errors.append(.invalidValue(field: "Dose Amount", reason: "Exceeds maximum allowed value"))
            }
        }

        // Note: ANMedicationConcept doesn't have notes field, removed validation

        if errors.isEmpty {
            logger.debug("Medication validation passed for ID: \(medication.id)")
            return .success
        } else {
            logger.warning("Medication validation failed for ID: \(medication.id) - \(errors)")
            return .failure(errors)
        }
    }

    // MARK: - Event Validation

    /// Validate an event before saving
    public static func validateEvent(_ event: ANEventConcept) -> ValidationResult {
        var errors: [ValidationError] = []

        // Validate date
        if !DateUtility.isValidMedicationDate(event.date) {
            errors.append(.invalidValue(field: "Date", reason: "Date is outside valid range"))
        }

        // Validate medication reference
        if event.medication == nil && event.eventType == .doseTaken {
            errors.append(.missingRequiredField(field: "Medication"))
        }

        // Validate dose for dose taken events
        if event.eventType == .doseTaken {
            if let dose = event.dose {
                if dose.amount <= 0 {
                    errors.append(.invalidValue(field: "Dose Amount", reason: "Must be greater than 0"))
                } else if dose.amount > 1000 {
                    errors.append(.invalidValue(field: "Dose Amount", reason: "Exceeds reasonable dose amount"))
                }
            } else {
                errors.append(.missingRequiredField(field: "Dose"))
            }
        }

        // Note: ANEventConcept doesn't have notes field, removed validation

        if errors.isEmpty {
            logger.debug("Event validation passed for ID: \(event.id)")
            return .success
        } else {
            logger.warning("Event validation failed for ID: \(event.id) - \(errors)")
            return .failure(errors)
        }
    }

    // MARK: - Bulk Validation

    /// Validate multiple medications
    public static func validateMedications(_ medications: [ANMedicationConcept]) -> BulkValidationResult {
        var validItems: [ANMedicationConcept] = []
        var invalidItems: [(item: ANMedicationConcept, errors: [ValidationError])] = []

        for medication in medications {
            switch validateMedication(medication) {
            case .success:
                validItems.append(medication)
            case let .failure(errors):
                invalidItems.append((medication, errors))
            }
        }

        logger.info("Bulk validation: \(validItems.count) valid, \(invalidItems.count) invalid medications")

        return BulkValidationResult(
            validCount: validItems.count,
            invalidCount: invalidItems.count,
            invalidItems: invalidItems
        )
    }

    /// Validate multiple events
    public static func validateEvents(_ events: [ANEventConcept]) -> BulkValidationResult {
        var validItems: [ANEventConcept] = []
        var invalidItems: [(item: ANEventConcept, errors: [ValidationError])] = []

        for event in events {
            switch validateEvent(event) {
            case .success:
                validItems.append(event)
            case let .failure(errors):
                invalidItems.append((event, errors))
            }
        }

        logger.info("Bulk validation: \(validItems.count) valid, \(invalidItems.count) invalid events")

        return BulkValidationResult(
            validCount: validItems.count,
            invalidCount: invalidItems.count,
            invalidItems: invalidItems.map { ($0.item as Any, $0.errors) }
        )
    }

    // MARK: - Data Integrity

    /// Check for duplicate medications
    public static func findDuplicateMedications(in medications: [ANMedicationConcept]) -> [[ANMedicationConcept]] {
        var duplicates: [[ANMedicationConcept]] = []
        var processed = Set<UUID>()

        for medication in medications {
            if processed.contains(medication.id) { continue }

            let similar = medications.filter { other in
                other.id != medication.id &&
                    (other.clinicalName.lowercased() == medication.clinicalName.lowercased() ||
                        (other.nickname != nil && other.nickname == medication.nickname))
            }

            if !similar.isEmpty {
                var group = [medication]
                group.append(contentsOf: similar)
                duplicates.append(group)
                processed.insert(medication.id)
                similar.forEach { processed.insert($0.id) }
            }
        }

        if !duplicates.isEmpty {
            logger.warning("Found \(duplicates.count) groups of duplicate medications")
        }

        return duplicates
    }

    /// Validate data consistency
    public static func validateDataConsistency(medications: [ANMedicationConcept], events: [ANEventConcept]) -> ConsistencyCheckResult {
        var orphanedEvents: [ANEventConcept] = []
        var unusedMedications: [ANMedicationConcept] = []

        let medicationIds = Set(medications.map { $0.id })

        // Find orphaned events (events without valid medication reference)
        orphanedEvents = events.filter { event in
            if let medicationId = event.medication?.id {
                return !medicationIds.contains(medicationId)
            }
            return false
        }

        // Find unused medications (medications with no events)
        let usedMedicationIds = Set(events.compactMap { $0.medication?.id })
        unusedMedications = medications.filter { !usedMedicationIds.contains($0.id) }

        logger.info("Data consistency check: \(orphanedEvents.count) orphaned events, \(unusedMedications.count) unused medications")

        return ConsistencyCheckResult(
            isConsistent: orphanedEvents.isEmpty,
            orphanedEvents: orphanedEvents,
            unusedMedications: unusedMedications
        )
    }
}

// MARK: - Result Types

public enum ValidationResult {
    case success
    case failure([ValidationError])

    public var isValid: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    public var errors: [ValidationError] {
        switch self {
        case .success: return []
        case let .failure(errors): return errors
        }
    }
}

public enum ValidationError: LocalizedError {
    case emptyField(field: String)
    case fieldTooLong(field: String, maxLength: Int)
    case invalidFormat(field: String, reason: String)
    case invalidValue(field: String, reason: String)
    case missingRequiredField(field: String)
    case duplicateValue(field: String)

    public var errorDescription: String? {
        switch self {
        case let .emptyField(field):
            return "\(field) cannot be empty"
        case let .fieldTooLong(field, maxLength):
            return "\(field) exceeds maximum length of \(maxLength) characters"
        case let .invalidFormat(field, reason):
            return "\(field) has invalid format: \(reason)"
        case let .invalidValue(field, reason):
            return "\(field) has invalid value: \(reason)"
        case let .missingRequiredField(field):
            return "\(field) is required"
        case let .duplicateValue(field):
            return "\(field) already exists"
        }
    }
}

public struct BulkValidationResult {
    public let validCount: Int
    public let invalidCount: Int
    public let invalidItems: [(item: Any, errors: [ValidationError])]

    public var isAllValid: Bool { invalidCount == 0 }
    public var successRate: Double {
        let total = validCount + invalidCount
        return total > 0 ? Double(validCount) / Double(total) : 0
    }
}

public struct ConsistencyCheckResult {
    public let isConsistent: Bool
    public let orphanedEvents: [ANEventConcept]
    public let unusedMedications: [ANMedicationConcept]
}

// DHLogger+Privacy.swift
// Privacy-safe logging extensions for DHLogger to prevent logging sensitive user data

import Foundation
import DHLoggingKit

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
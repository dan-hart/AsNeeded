// DataStore.swift
// Centralized Boutique stores and high-level persistence operations.

import Foundation
import Boutique
import ANModelKit
import DHLoggingKit

@MainActor
public final class DataStore {
	public static let shared = DataStore()
	private let logger = DHLogger.data

	// Underlying Boutique stores
	public let medicationsStore: Store<ANMedicationConcept>
	public let eventsStore: Store<ANEventConcept>

	public var medications: [ANMedicationConcept] { medicationsStore.items }
	public var events: [ANEventConcept] { eventsStore.items }

	private init() {
		logger.info("Initializing DataStore with persistent storage")
		self.medicationsStore = Store<ANMedicationConcept>(
			storage: SQLiteStorageEngine.default(appendingPath: "medications.sqlite"),
			cacheIdentifier: \ANMedicationConcept.id.uuidString
		)
		self.eventsStore = Store<ANEventConcept>(
			storage: SQLiteStorageEngine.default(appendingPath: "events.sqlite"),
			cacheIdentifier: \ANEventConcept.id.uuidString
		)
		logger.oslog.debug("DataStore initialized: \\(medications.count, privacy: .public) medications, \\(events.count, privacy: .public) events")
	}
	
	// Test initializer using isolated test storage
	public init(testIdentifier: String) {
		let testId = UUID().uuidString
		self.medicationsStore = Store<ANMedicationConcept>(
			storage: SQLiteStorageEngine.default(appendingPath: "test_medications_\(testIdentifier)_\(testId).sqlite"),
			cacheIdentifier: \ANMedicationConcept.id.uuidString
		)
		self.eventsStore = Store<ANEventConcept>(
			storage: SQLiteStorageEngine.default(appendingPath: "test_events_\(testIdentifier)_\(testId).sqlite"),
			cacheIdentifier: \ANEventConcept.id.uuidString
		)
	}

	// MARK: - Medication Operations
	public func addMedication(_ med: ANMedicationConcept) async throws {
		logger.info("Adding medication: \(med.displayName)")
		do {
			try await medicationsStore.insert(med)
			logger.info("Successfully added medication: \(med.displayName)")
		} catch {
			logger.error("Failed to add medication \(med.displayName): \(error.localizedDescription)")
			throw error
		}
	}

	public func updateMedication(_ med: ANMedicationConcept) async throws {
		logger.info("Updating medication: \(med.displayName)")
		do {
			// Boutique has no explicit update; remove + insert to replace by id.
			try await medicationsStore.remove(med)
			try await medicationsStore.insert(med)
			logger.info("Successfully updated medication: \(med.displayName)")
		} catch {
			logger.error("Failed to update medication \(med.displayName): \(error.localizedDescription)")
			throw error
		}
	}

	public func deleteMedication(_ med: ANMedicationConcept) async throws {
		logger.info("Deleting medication: \(med.displayName)")
		do {
			// Also delete associated events
			let associatedEvents = events.filter { $0.medication?.id == med.id }
			logger.debug("Found \(associatedEvents.count) associated events to delete")
			
			for event in associatedEvents {
				try await eventsStore.remove(event)
			}
			
			try await medicationsStore.remove(med)
			logger.info("Successfully deleted medication: \(med.displayName) and \(associatedEvents.count) associated events")
		} catch {
			logger.error("Failed to delete medication \(med.displayName): \(error.localizedDescription)")
			throw error
		}
	}

	// MARK: - Events
	public func addEvent(_ event: ANEventConcept) async throws {
		logger.info("Adding event: \(event.eventType) for medication: \(event.medication?.displayName ?? "unknown")")
		do {
			try await eventsStore.insert(event)
			logger.info("Successfully added event: \(event.id)")
		} catch {
			logger.error("Failed to add event: \(error.localizedDescription)")
			throw error
		}
	}
	
	// MARK: - Data Management

	/// Export all data as JSON
	public func exportDataAsJSON(redactNames: Bool = false, redactNotes: Bool = false) async throws -> Data {
		logger.info("Starting data export (redactNames: \(redactNames), redactNotes: \(redactNotes))")
		
		// Redact medication names if requested
		let exportMedications = redactNames ? medications.map { medication in
			var redacted = medication
			redacted.clinicalName = "[REDACTED]"
			redacted.nickname = medication.nickname != nil ? "[REDACTED]" : nil
			return redacted
		} : medications
		
		// Redact event notes if requested
		let exportEvents = redactNotes ? events.map { event in
			var redacted = event
			redacted.note = nil  // Remove notes entirely
			return redacted
		} : events
		
		logger.debug("Exporting \(exportMedications.count) medications and \(exportEvents.count) events")
		
		let exportData = DataExport(
			medications: exportMedications,
			events: exportEvents,
			exportDate: Date(),
			appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
			dataVersion: "1.0"
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
	
	/// Import data from JSON, with options for merge or replace
	public func importDataFromJSON(_ data: Data, mergeExisting: Bool = false) async throws {
		logger.info("Starting data import (merge: \(mergeExisting), size: \(data.count) bytes)")
		
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
				if mergeExisting && medications.contains(where: { $0.id == medication.id }) {
					logger.debug("Skipping duplicate medication: \(medication.displayName)")
					continue
				}
				try await medicationsStore.insert(medication)
				medicationImportCount += 1
			} catch {
				logger.error("Failed to import medication \(medication.displayName): \(error.localizedDescription)")
				// Continue with other medications
			}
		}
		
		// Import events
		var eventImportCount = 0
		for event in importedData.events {
			do {
				if mergeExisting && events.contains(where: { $0.id == event.id }) {
					logger.debug("Skipping duplicate event: \(event.id)")
					continue
				}
				try await eventsStore.insert(event)
				eventImportCount += 1
			} catch {
				logger.error("Failed to import event \(event.id): \(error.localizedDescription)")
				// Continue with other events
			}
		}
		
		logger.info("Import completed: \(medicationImportCount) medications, \(eventImportCount) events imported")
	}
	
	/// Clear all data from both stores
	public func clearAllData() async throws {
		logger.warning("Clearing all data from stores")
		do {
			try await medicationsStore.removeAll()
			try await eventsStore.removeAll()
			logger.info("Successfully cleared all data")
		} catch {
			logger.error("Failed to clear data: \(error.localizedDescription)")
			throw error
		}
	}
}

/// Structure for data export/import
private struct DataExport: Codable {
	let medications: [ANMedicationConcept]
	let events: [ANEventConcept]
	let exportDate: Date
	let appVersion: String
	let dataVersion: String?
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
		case .versionMismatch(let expected, let actual):
			return "Data version mismatch: expected \(expected), got \(actual)"
		case .partialImport(let imported, let failed):
			return "Partial import: \(imported) items imported, \(failed) failed"
		}
	}
}

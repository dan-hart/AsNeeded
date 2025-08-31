// DataStore.swift
// Centralized Boutique stores and high-level persistence operations.

import Foundation
import Boutique
import ANModelKit

@MainActor
public final class DataStore {
	public static let shared = DataStore()

	// Underlying Boutique stores
	public let medicationsStore: Store<ANMedicationConcept>
	public let eventsStore: Store<ANEventConcept>

	public var medications: [ANMedicationConcept] { medicationsStore.items }
	public var events: [ANEventConcept] { eventsStore.items }

	private init() {
		self.medicationsStore = Store<ANMedicationConcept>(
			storage: SQLiteStorageEngine.default(appendingPath: "medications.sqlite"),
			cacheIdentifier: \ANMedicationConcept.id.uuidString
		)
		self.eventsStore = Store<ANEventConcept>(
			storage: SQLiteStorageEngine.default(appendingPath: "events.sqlite"),
			cacheIdentifier: \ANEventConcept.id.uuidString
		)
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
		try await medicationsStore.insert(med)
	}

	public func updateMedication(_ med: ANMedicationConcept) async throws {
		// Boutique has no explicit update; remove + insert to replace by id.
		try await medicationsStore.remove(med)
		try await medicationsStore.insert(med)
	}

	public func deleteMedication(_ med: ANMedicationConcept) async throws {
		try await medicationsStore.remove(med)
	}

	// MARK: - Events
	public func addEvent(_ event: ANEventConcept) async throws {
		try await eventsStore.insert(event)
	}
	
	// MARK: - Data Management

	/// Export all data as JSON
	public func exportDataAsJSON(redactNames: Bool = false) async throws -> Data {
		let exportMedications = redactNames ? medications.map { $0.redacted() } : medications
		let exportEvents = redactNames ? events.map { $0.redacted() } : events
		
		let exportData = DataExport(
			medications: exportMedications,
			events: exportEvents,
			exportDate: Date(),
			appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
		)
		
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = .prettyPrinted
		return try encoder.encode(exportData)
	}
	
	/// Import data from JSON, replacing all existing data
	public func importDataFromJSON(_ data: Data) async throws {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		
		let importedData = try decoder.decode(DataExport.self, from: data)
		
		// Clear existing data first
		try await clearAllData()
		
		// Import medications
		for medication in importedData.medications {
			try await addMedication(medication)
		}
		
		// Import events
		for event in importedData.events {
			try await addEvent(event)
		}
	}
	
	/// Clear all data from both stores
	public func clearAllData() async throws {
		try await medicationsStore.removeAll()
		try await eventsStore.removeAll()
	}
}

/// Structure for data export/import
private struct DataExport: Codable {
	let medications: [ANMedicationConcept]
	let events: [ANEventConcept]
	let exportDate: Date
	let appVersion: String
}

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
}

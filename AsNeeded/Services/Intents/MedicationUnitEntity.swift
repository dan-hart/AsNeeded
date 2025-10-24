// MedicationUnitEntity.swift
// App Intent entity for medication units

import ANModelKit
import AppIntents
import Foundation

@available(iOS 16.0, *)
struct MedicationUnitEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Medication Unit")
    static let defaultQuery = MedicationUnitQuery()

    var id: String
    var displayName: String
    var unit: ANUnitConcept

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    init(unit: ANUnitConcept) {
        self.unit = unit
        id = unit.rawValue
        displayName = unit.displayName
    }
}

@available(iOS 16.0, *)
struct MedicationUnitQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MedicationUnitEntity] {
        return ANUnitConcept.allCases.compactMap { unit in
            guard identifiers.contains(unit.rawValue) else { return nil }
            return MedicationUnitEntity(unit: unit)
        }
    }

    func entities(matching string: String) async throws -> [MedicationUnitEntity] {
        let searchTerm = string.lowercased()
        return ANUnitConcept.allCases.compactMap { unit in
            if unit.displayName.lowercased().contains(searchTerm) ||
                unit.abbreviation.lowercased().contains(searchTerm) ||
                unit.rawValue.lowercased().contains(searchTerm)
            {
                return MedicationUnitEntity(unit: unit)
            }
            return nil
        }
    }

    func suggestedEntities() async throws -> [MedicationUnitEntity] {
        // Return most common units
        return ANUnitConcept.commonUnits.map { MedicationUnitEntity(unit: $0) }
    }
}

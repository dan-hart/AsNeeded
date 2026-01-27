// MedicationEntity.swift
// App Intent entity for user's medications

import ANModelKit
import AppIntents
import Foundation

@available(iOS 16.0, *)
struct MedicationEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Medication")
    static let defaultQuery = MedicationQuery()

    var id: String
    var displayName: String
    var medication: ANMedicationConcept

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    init(medication: ANMedicationConcept) {
        self.medication = medication
        id = medication.id.uuidString
        displayName = medication.displayName
    }
}

@available(iOS 16.0, *)
struct MedicationQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [MedicationEntity] {
        let medications = DataStore.shared.medications
        return medications.compactMap { medication in
            guard identifiers.contains(medication.id.uuidString) else { return nil }
            return MedicationEntity(medication: medication)
        }
    }

    @MainActor
    func entities(matching string: String) async throws -> [MedicationEntity] {
        let medications = DataStore.shared.medications
        let searchTerm = string.lowercased()

        return medications.compactMap { medication in
            let clinicalNameMatches = medication.clinicalName.lowercased().contains(searchTerm)
            let nicknameMatches = medication.nickname?.lowercased().contains(searchTerm) == true

            if clinicalNameMatches || nicknameMatches {
                return MedicationEntity(medication: medication)
            }
            return nil
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [MedicationEntity] {
        // Return all user medications, most recently used first
        let medications = DataStore.shared.medications.sorted { med1, med2 in
            // Sort by last event date if available, otherwise by creation date
            let events = DataStore.shared.events
            let med1LastEvent = events.filter { $0.medication?.id == med1.id }.max(by: { $0.date < $1.date })
            let med2LastEvent = events.filter { $0.medication?.id == med2.id }.max(by: { $0.date < $1.date })

            if let date1 = med1LastEvent?.date, let date2 = med2LastEvent?.date {
                return date1 > date2
            } else if med1LastEvent != nil {
                return true
            } else if med2LastEvent != nil {
                return false
            } else {
                return med1.clinicalName < med2.clinicalName
            }
        }

        return medications.map { MedicationEntity(medication: $0) }
    }
}

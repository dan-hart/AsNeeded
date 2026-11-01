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
	var dataStore: DataStore?

	init() {}

	init(dataStore: DataStore) { self.dataStore = dataStore }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [MedicationEntity] {
        let medications = try await (dataStore ?? .shared).prepareForAccess().medications
        let requestedIDs = Set(identifiers.compactMap(UUID.init(uuidString:)))
        return medications.compactMap { medication in
            guard requestedIDs.contains(medication.id) else { return nil }
            return MedicationEntity(medication: medication)
        }
    }

    @MainActor
    func entities(matching string: String) async throws -> [MedicationEntity] {
        let medications = try await (dataStore ?? .shared).prepareForAccess().medications
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
		let snapshot = try await (dataStore ?? .shared).prepareForAccess()
		// Precompute from one loaded snapshot; sorting never rereads mutable storage.
		var lastEventDates: [UUID: Date] = [:]
		for event in snapshot.events {
			guard let id = event.medication?.id else { continue }
			lastEventDates[id] = max(lastEventDates[id] ?? .distantPast, event.date)
		}
		let medications = snapshot.medications.sorted { left, right in
			let leftDate = lastEventDates[left.id] ?? .distantPast
			let rightDate = lastEventDates[right.id] ?? .distantPast
			if leftDate != rightDate { return leftDate > rightDate }
			return left.clinicalName < right.clinicalName
		}

        return medications.map { MedicationEntity(medication: $0) }
    }
}

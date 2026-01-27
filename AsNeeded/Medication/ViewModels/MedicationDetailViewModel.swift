// MedicationDetailViewModel.swift
// View model for medication detail operations via DataStore.

import ANModelKit
import DHLoggingKit
import Foundation

@MainActor
final class MedicationDetailViewModel: ObservableObject {
    private let dataStore: DataStore
    private let logger = DHLogger(category: "MedicationDetailViewModel")

    @Published var isLoading = false
    @Published var errorMessage: String?

    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore
        logger.debug("MedicationDetailViewModel initialized")
    }

    func save(updated medication: ANMedicationConcept) async {
        logger.info("Saving medication: \(medication.displayName)")
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await dataStore.updateMedication(medication)
            logger.info("Successfully saved medication: \(medication.displayName)")
        } catch {
            logger.error("Failed to save medication: \(error.localizedDescription)")
            errorMessage = "Failed to save medication: \(error.localizedDescription)"
        }
    }

    func delete(_ medication: ANMedicationConcept) async {
        logger.info("Deleting medication: \(medication.displayName)")
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await dataStore.deleteMedication(medication)
            logger.info("Successfully deleted medication: \(medication.displayName)")
        } catch {
            logger.error("Failed to delete medication: \(error.localizedDescription)")
            errorMessage = "Failed to delete medication: \(error.localizedDescription)"
        }
    }

    func log(event: ANEventConcept) async {
        logger.info("Logging event: \(event.eventType) for \(event.medication?.displayName ?? "unknown")")
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await dataStore.addEvent(event)
            logger.info("Successfully logged event: \(event.id)")
        } catch {
            logger.error("Failed to log event: \(error.localizedDescription)")
            errorMessage = "Failed to log event: \(error.localizedDescription)"
        }
    }
}

// MedicationDetailViewModel.swift
// View model for medication detail operations via DataStore.

import ANModelKit
import DHLoggingKit
import Foundation

@MainActor
final class MedicationDetailViewModel: ObservableObject {
    private let dataStore: DataStore
    private let logger = DHLogger(category: "MedicationDetailViewModel")
    private var activeDoseLogOperationID: UUID?

    @Published var isLoading = false
    @Published var errorMessage: String?

    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore
        logger.debug("MedicationDetailViewModel initialized")
    }

    func save(updated medication: ANMedicationConcept) async {
        logger.logMedicationOperation("Saving", id: medication.id)
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await dataStore.updateMedication(medication)
            await MedicationLiveActivityManager.refreshFromDataStore(dataStore: dataStore)
            logger.logMedicationOperation("Successfully saved", id: medication.id)
        } catch {
            logger.logPrivacySafeError("Failed to save medication", error: error)
            errorMessage = "Failed to save medication: \(error.localizedDescription)"
        }
    }

    func delete(_ medication: ANMedicationConcept) async {
        logger.logMedicationOperation("Deleting", id: medication.id)
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await dataStore.deleteMedication(medication)
            await MedicationLiveActivityManager.refreshFromDataStore(dataStore: dataStore)
            logger.logMedicationOperation("Successfully deleted", id: medication.id)
        } catch {
            logger.logPrivacySafeError("Failed to delete medication", error: error)
            errorMessage = "Failed to delete medication: \(error.localizedDescription)"
        }
    }

    func logDose(
        medication: ANMedicationConcept,
        dose: ANDoseConcept,
        event: ANEventConcept,
        source: String,
        operationID: UUID = UUID()
    ) async -> Bool {
        guard activeDoseLogOperationID == nil else {
            logger.warning("Ignored dose log while another operation is in flight: activeOperationID=\(activeDoseLogOperationID?.uuidString ?? "unknown"), newOperationID=\(operationID.uuidString)")
            return false
        }

        activeDoseLogOperationID = operationID
        defer { activeDoseLogOperationID = nil }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let eventCountBefore = dataStore.events.count
        var updatedMedication = medication
        if let quantity = updatedMedication.quantity, dose.amount > 0 {
            updatedMedication.quantity = quantity - dose.amount
        }

        var eventToSave = event
        if eventToSave.medication?.id != medication.id {
            logger.warning("Correcting mismatched dose log medication: source=\(source), operationID=\(operationID.uuidString), eventHadDifferentMedication=true")
        }
        eventToSave.medication = medication

        logger.logDoseOperation(
            "Starting",
            source: source,
            operationID: operationID,
            eventCountBefore: eventCountBefore,
            details: quantityDetails(quantityWasPresent: medication.quantity != nil)
        )

        do {
            try await dataStore.updateMedication(updatedMedication)
            try await dataStore.addEvent(eventToSave)
            await MedicationLiveActivityManager.refreshFromDataStore(dataStore: dataStore)
            logger.logDoseOperation(
                "Succeeded",
                source: source,
                operationID: operationID,
                eventCountBefore: eventCountBefore,
                eventCountAfter: dataStore.events.count
            )
            return true
        } catch {
            logger.error("Failed dose log: source=\(source), operationID=\(operationID.uuidString), errorType=\(DHLogger.privacySafeErrorType(error))")
            errorMessage = "Failed to log dose: \(error.localizedDescription)"
            return false
        }
    }

    func log(event: ANEventConcept) async {
        logger.logEventOperation("Logging", eventType: event.eventType.rawValue, medicationId: event.medication?.id)
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await dataStore.addEvent(event)
            await MedicationLiveActivityManager.refreshFromDataStore(dataStore: dataStore)
            logger.info("Successfully logged event record")
        } catch {
            logger.logPrivacySafeError("Failed to log event", error: error)
            errorMessage = "Failed to log event: \(error.localizedDescription)"
        }
    }

    private func quantityDetails(quantityWasPresent: Bool) -> String {
        "quantityUpdated=\(quantityWasPresent)"
    }
}

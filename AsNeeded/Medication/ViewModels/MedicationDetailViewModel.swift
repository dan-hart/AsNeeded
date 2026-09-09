// MedicationDetailViewModel.swift
// View model for medication detail operations via DataStore.

import ANModelKit
import DHLoggingKit
import Foundation

/// Persists a dose event during `logDose`. Injectable so tests can fail the event write after the
/// medication update has already succeeded.
typealias DoseEventWrite = @MainActor (_ event: ANEventConcept) async throws -> Void

@MainActor
final class MedicationDetailViewModel: ObservableObject {
    private let dataStore: DataStore
    private let logger = DHLogger(category: "MedicationDetailViewModel")
	private let addDoseEvent: DoseEventWrite
    private var activeDoseLogOperationID: UUID?

    @Published var isLoading = false
    @Published var errorMessage: String?

	init(dataStore: DataStore = .shared, addDoseEvent: DoseEventWrite? = nil) {
        self.dataStore = dataStore
		self.addDoseEvent = addDoseEvent ?? { event in
			try await dataStore.addEvent(event)
		}
        logger.debug("MedicationDetailViewModel initialized")
    }

    func save(updated medication: ANMedicationConcept) async {
        logger.logMedicationOperation("Saving", id: medication.id)
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await dataStore.updateMedication(medication)
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
		} catch {
			logger.error("Failed dose log: source=\(source), operationID=\(operationID.uuidString), stage=updateMedication, errorType=\(DHLogger.privacySafeErrorType(error))")
			errorMessage = "Failed to log dose: \(error.localizedDescription)"
			return false
		}

		do {
			try await addDoseEvent(eventToSave)
			logger.logDoseOperation(
				"Succeeded",
				source: source,
				operationID: operationID,
				eventCountBefore: eventCountBefore,
				eventCountAfter: dataStore.events.count
			)
			return true
		} catch {
			logger.error("Failed dose log: source=\(source), operationID=\(operationID.uuidString), stage=addEvent, errorType=\(DHLogger.privacySafeErrorType(error))")
			await rollBackMedicationUpdate(to: medication, source: source, operationID: operationID)
			errorMessage = "Failed to log dose: \(error.localizedDescription)"
			return false
		}
    }

	/// Restores the pre-dose medication after the event write fails so a retry does not subtract the dose twice.
	private func rollBackMedicationUpdate(
		to originalMedication: ANMedicationConcept,
		source: String,
		operationID: UUID
	) async {
		do {
			try await dataStore.updateMedication(originalMedication)
			logger.logDoseOperation(
				"Rolled back medication update for",
				source: source,
				operationID: operationID,
				details: "reason=eventWriteFailed"
			)
		} catch {
			logger.error("Failed to roll back medication update: source=\(source), operationID=\(operationID.uuidString), errorType=\(DHLogger.privacySafeErrorType(error))")
		}
	}

    func log(event: ANEventConcept) async {
        logger.logEventOperation("Logging", eventType: event.eventType.rawValue, medicationId: event.medication?.id)
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await dataStore.addEvent(event)
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

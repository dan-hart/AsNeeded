// MedicationListViewModel.swift
// View model for listing, adding, and deleting medications via DataStore.

import ANModelKit
import DHLoggingKit
import Foundation
import SwiftUI

/// Persists a quick log. The returned flags describe what remains persisted once the closure finishes:
/// a medication update that was rolled back after a failed event write reports `updateSuccess == false`.
typealias QuickLogPersistence = @MainActor (
	_ updatedMedication: ANMedicationConcept,
	_ event: ANEventConcept
) async -> (updateSuccess: Bool, eventSuccess: Bool)

/// Reverts a quick log by removing its event and, when provided, restoring the medication quantity.
/// Returns `false` when the undo could not be fully applied.
typealias QuickLogUndoPersistence = @MainActor (
	_ event: ANEventConcept,
	_ restoredMedication: ANMedicationConcept?
) async -> Bool

/// Primitive store writes behind quick-log persistence. Tests can replace individual writes with
/// failing ones while the compensating logic in `MedicationListViewModel` stays under test.
struct QuickLogWrites {
	var storedMedication: @MainActor (UUID) -> ANMedicationConcept?
	var updateMedication: @MainActor (ANMedicationConcept) async throws -> Void
	var addEvent: @MainActor (ANEventConcept) async throws -> Void
	var removeEvent: @MainActor (ANEventConcept) async throws -> Void

	@MainActor
	static func live(dataStore: DataStore) -> QuickLogWrites {
		QuickLogWrites(
			storedMedication: { medicationID in
				dataStore.medications.first { $0.id == medicationID }
			},
			updateMedication: { medication in
				try await dataStore.updateMedication(medication)
			},
			addEvent: { event in
				try await dataStore.addEvent(event, shouldRecordForReview: false)
			},
			removeEvent: { event in
				try await dataStore.eventsStore.remove(event)
			}
		)
	}
}

@MainActor
final class MedicationListViewModel: ObservableObject {
    // MARK: - Properties
    private let dataStore: DataStore
    private let logger = DHLogger.ui
    private let hapticsManager = HapticsManager.shared
    private let refillProfileStore = MedicationRefillProfileStore.shared
    private let feedbackService = QuickLogFeedbackService()
    private let statusSummaryService = MedicationStatusSummaryService()
    private let scheduleQuickLogToastDismissal: (@escaping @MainActor @Sendable () -> Void) -> Void
	private let quickLogPersistence: QuickLogPersistence
	private let quickLogUndoPersistence: QuickLogUndoPersistence
	private let acknowledgeDeliveredReminders: @MainActor (UUID) async -> Void

    @AppStorage(UserDefaultsKeys.medicationOrder) private var medicationOrder: [String] = []
    @AppStorage(UserDefaultsKeys.hideSupportBanners) private var hideSupportBanners = false

    // MARK: - Published Properties
    @Published var showArchivedMedications: Bool = false
    @Published var editMode: EditMode = .inactive
    @Published var showAddSheet = false
    @Published var editMedication: ANMedicationConcept?
    @Published var logMedication: ANMedicationConcept?
    @Published var pendingDelete: ANMedicationConcept?
    @Published var showSupportToast = false
    @Published var showSupportView = false
    @Published var showQuickLogToast = false
    @Published var quickLogMedicationName = ""
    @Published var quickLogDoseAmount: Double = 0
    @Published var quickLogDoseUnit = ""
    @Published var quickLogAccentColor: Color = .accent
    @Published var quickLogFeedback: QuickLogFeedbackService.Feedback?
    @Published private(set) var quickLogToastGeneration: UUID?
    @Published var isLoading = true

    // MARK: - Computed Properties
    var items: [ANMedicationConcept] { dataStore.medications }

    var displayedMedications: [ANMedicationConcept] {
        showArchivedMedications ? items : items.active
    }

    var sortedMedications: [ANMedicationConcept] {
        let items = displayedMedications
        if medicationOrder.isEmpty {
            return items
        }

        let itemsById = Dictionary(uniqueKeysWithValues: items.map { ($0.id.uuidString, $0) })
        let orderSet = Set(medicationOrder)

        var sorted: [ANMedicationConcept] = []
        sorted.reserveCapacity(items.count)

        for id in medicationOrder {
            if let med = itemsById[id] {
                sorted.append(med)
            }
        }

        for item in items {
            if !orderSet.contains(item.id.uuidString) {
                sorted.append(item)
            }
        }

        return sorted
    }

    // MARK: - Initialization
    init(
        dataStore: DataStore = .shared,
        scheduleQuickLogToastDismissal: @escaping (@escaping @MainActor @Sendable () -> Void) -> Void = { action in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                action()
            }
        },
		quickLogPersistence: QuickLogPersistence? = nil,
		quickLogUndoPersistence: QuickLogUndoPersistence? = nil,
		acknowledgeDeliveredReminders: @escaping @MainActor (UUID) async -> Void = { medicationID in
			await NotificationManager.shared.acknowledgeDeliveredReminders(for: medicationID)
		}
    ) {
        self.dataStore = dataStore
        self.scheduleQuickLogToastDismissal = scheduleQuickLogToastDismissal
		let writes = QuickLogWrites.live(dataStore: dataStore)
		self.quickLogPersistence = quickLogPersistence ?? Self.makeQuickLogPersistence(writes: writes)
		self.quickLogUndoPersistence = quickLogUndoPersistence ?? Self.makeQuickLogUndoPersistence(writes: writes)
		self.acknowledgeDeliveredReminders = acknowledgeDeliveredReminders

        if medicationOrder.isEmpty && !items.isEmpty {
            medicationOrder = items.map { $0.id.uuidString }
        }

        Task { [weak self] in
            await self?.finishInitialLoad()
        }
    }

    private func finishInitialLoad() async {
        do {
            try await dataStore.medicationsStore.itemsHaveLoaded()
        } catch {
            logger.logPrivacySafeError("Failed to load medications store", error: error)
        }

        isLoading = false

        if medicationOrder.isEmpty && !items.isEmpty {
            medicationOrder = items.map { $0.id.uuidString }
        }
    }

	// MARK: - Quick Log Persistence
	/// Writes the medication first, then the event. If the event write fails, the medication that was
	/// stored before the update is written back so a retry does not decrement the quantity twice.
	static func makeQuickLogPersistence(writes: QuickLogWrites) -> QuickLogPersistence {
		let logger = DHLogger.ui
		return { updatedMedication, event in
			let originalMedication = writes.storedMedication(updatedMedication.id)

			do {
				try await writes.updateMedication(updatedMedication)
			} catch {
				logger.logPrivacySafeError("Failed to update medication", error: error)
				return (updateSuccess: false, eventSuccess: false)
			}

			do {
				try await writes.addEvent(event)
				return (updateSuccess: true, eventSuccess: true)
			} catch {
				logger.logPrivacySafeError("Failed to add event", error: error)
			}

			guard let originalMedication else {
				logger.error("Unable to roll back medication update after event write failure: originalMedicationFound=false")
				return (updateSuccess: true, eventSuccess: false)
			}

			do {
				try await writes.updateMedication(originalMedication)
				logger.warning("Rolled back medication update after event write failure")
				return (updateSuccess: false, eventSuccess: false)
			} catch {
				logger.logPrivacySafeError("Failed to roll back medication update after event write failure", error: error)
				return (updateSuccess: true, eventSuccess: false)
			}
		}
	}

	/// Removes the event first, then restores the medication. If the restore fails, the event is
	/// re-added so the store never holds a decremented quantity without its dose event.
	static func makeQuickLogUndoPersistence(writes: QuickLogWrites) -> QuickLogUndoPersistence {
		let logger = DHLogger.ui
		return { event, restoredMedication in
			do {
				try await writes.removeEvent(event)
			} catch {
				logger.logPrivacySafeError("Failed to remove quick log event", error: error)
				return false
			}

			guard let restoredMedication else {
				return true
			}

			do {
				try await writes.updateMedication(restoredMedication)
				return true
			} catch {
				logger.logPrivacySafeError("Failed to restore medication after quick log undo", error: error)
			}

			do {
				try await writes.addEvent(event)
				logger.warning("Re-added quick log event after medication restore failure")
			} catch {
				logger.logPrivacySafeError("Failed to re-add quick log event after medication restore failure", error: error)
			}
			return false
		}
	}

    // MARK: - Data Operations
    func add(_ med: ANMedicationConcept) async -> Bool {
        do {
            try await dataStore.addMedication(med)
            appendToMedicationOrderIfNeeded(med)
            return true
        } catch {
            logger.logPrivacySafeError("Failed to add medication", error: error)
            return false
        }
    }

    func update(_ med: ANMedicationConcept) async -> Bool {
        do {
            try await dataStore.updateMedication(med)
            return true
        } catch {
            logger.logPrivacySafeError("Failed to update medication", error: error)
            return false
        }
    }

    func delete(_ med: ANMedicationConcept) async -> Bool {
        do {
            try await dataStore.deleteMedication(med)
            var order = medicationOrder
            order.removeAll { $0 == med.id.uuidString }
            medicationOrder = order
            return true
        } catch {
            logger.logPrivacySafeError("Failed to delete medication", error: error)
            return false
        }
    }

    func addEvent(_ event: ANEventConcept, shouldRecordForReview: Bool = true) async -> Bool {
        do {
            try await dataStore.addEvent(event, shouldRecordForReview: shouldRecordForReview)
            return true
        } catch {
            logger.logPrivacySafeError("Failed to add event", error: error)
            return false
        }
    }

    func moveMedications(from source: IndexSet, to destination: Int) {
        var items = sortedMedications
        items.move(fromOffsets: source, toOffset: destination)
        medicationOrder = items.map { $0.id.uuidString }
    }

    func deleteMedications(at offsets: IndexSet) {
        for index in offsets {
            // Using the renamed subscript(safe: index)
            guard let med = sortedMedications[doesExistAt: index] else { continue }
            Task { _ = await delete(med) }
        }
    }

    func toggleEditMode() {
        withAnimation {
            editMode = editMode == .inactive ? .active : .inactive
            hapticsManager.selectionChanged()
        }
    }
    
    func toggleArchivedMedications() {
        withAnimation {
            showArchivedMedications.toggle()
            hapticsManager.selectionChanged()
        }
    }

    func logDose(
        med: ANMedicationConcept,
        dose: ANDoseConcept,
        event: ANEventConcept,
        source: String = "list_sheet",
        operationID: UUID = UUID()
    ) async -> Bool {
        let eventCountBefore = dataStore.events.count
        var updated = med
        if let quantity = updated.quantity, dose.amount > 0 {
            updated.quantity = max(0, quantity - dose.amount)
        }

        var eventToSave = event
        if eventToSave.medication?.id != med.id {
            logger.warning("Correcting mismatched list dose log medication: source=\(source), operationID=\(operationID.uuidString), eventHadDifferentMedication=true")
        }
        eventToSave.medication = med

        logger.logDoseOperation(
            "Starting",
            source: source,
            operationID: operationID,
            eventCountBefore: eventCountBefore,
            details: quantityDetails(quantityWasPresent: med.quantity != nil)
        )

        // Sequential, compensating writes: if the event write fails the quantity is restored.
        let (updateSuccess, eventSuccess) = await quickLogPersistence(updated, eventToSave)

        if updateSuccess && eventSuccess {
            // Sheet logs count toward review eligibility (quick logs from the row intentionally do not).
            AppReviewManager.shared.recordMedicationEvent()
            logMedication = nil
            logger.logDoseOperation(
                "Succeeded",
                source: source,
                operationID: operationID,
                eventCountBefore: eventCountBefore,
                eventCountAfter: dataStore.events.count
            )
            if hideSupportBanners {
                showQuickLogToast(med: med, dose: dose)
            } else {
                triggerSupportToast()
            }
            return true
        }

        logger.error("Failed list dose log: source=\(source), operationID=\(operationID.uuidString), updateSuccess=\(updateSuccess), eventSuccess=\(eventSuccess)")
        return false
    }

    func quickLog(medication: ANMedicationConcept) async -> Bool {
        let operationID = UUID()
        let loggedAt = Date()
        let dose = ANDoseConcept(
            amount: medication.prescribedDoseAmount ?? 1,
            unit: medication.prescribedUnit ?? .unit
        )
        let eventCountBefore = dataStore.events.count
        var updatedMed = medication
        if let quantity = updatedMed.quantity, dose.amount > 0 {
            updatedMed.quantity = quantity - dose.amount
        }

        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: loggedAt,
            note: nil
        )

        logger.logDoseOperation(
            "Starting",
            source: "list_quick_log",
            operationID: operationID,
            eventCountBefore: eventCountBefore,
            details: quantityDetails(quantityWasPresent: medication.quantity != nil)
        )

		let (updateSuccess, eventSuccess) = await quickLogPersistence(updatedMed, event)

        if updateSuccess, eventSuccess {
			await acknowledgeDeliveredReminders(medication.id)
            hapticsManager.doseLogged()
            let feedback = feedbackService.feedback(
                medication: medication,
                dose: dose,
                loggedEvent: event
            )
            showQuickLogToast(med: medication, dose: dose, feedback: feedback)
            logger.logDoseOperation(
                "Succeeded",
                source: "list_quick_log",
                operationID: operationID,
                eventCountBefore: eventCountBefore,
                eventCountAfter: dataStore.events.count
            )
        } else {
            logger.error("Failed quick dose log: source=list_quick_log, operationID=\(operationID.uuidString), updateSuccess=\(updateSuccess), eventSuccess=\(eventSuccess)")
        }
        
        return updateSuccess && eventSuccess
    }

    func undoLastQuickLog() async -> Bool {
        guard let feedback = quickLogFeedback,
              let toastGeneration = quickLogToastGeneration,
              let undoEventID = feedback.undoEventID,
              let event = dataStore.events.first(where: { $0.id == undoEventID })
        else {
            return false
        }

		var restoredMedication: ANMedicationConcept?
		if let dose = event.dose,
		   let medicationID = event.medication?.id,
		   let medication = dataStore.medications.first(where: { $0.id == medicationID })
		{
			var updated = medication
			if let quantity = updated.quantity {
				updated.quantity = quantity + dose.amount
			}
			restoredMedication = updated
		}

		guard await quickLogUndoPersistence(event, restoredMedication) else {
			logger.error("Failed to undo quick log")
			return false
		}

		dismissQuickLogToast(generation: toastGeneration)
		return true
    }

    func dismissQuickLogToast() {
        guard let generation = quickLogToastGeneration else {
            return
        }

        dismissQuickLogToast(generation: generation)
    }

    private func dismissQuickLogToast(generation: UUID) {
        guard quickLogToastGeneration == generation else {
            return
        }

        quickLogToastGeneration = nil
        quickLogFeedback = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showQuickLogToast = false
        }
    }

    func statusSummary(for medication: ANMedicationConcept) -> MedicationStatusSummaryService.Summary {
        statusSummaryService.summary(
            for: medication,
            events: dataStore.events,
            profile: refillProfileStore.profile(for: medication.id)
        )
    }

    private func showQuickLogToast(
        med: ANMedicationConcept,
        dose: ANDoseConcept,
        feedback: QuickLogFeedbackService.Feedback? = nil
    ) {
        let generation = UUID()
        quickLogMedicationName = med.displayName
        quickLogDoseAmount = dose.amount
        quickLogDoseUnit = dose.unit.abbreviation
        quickLogAccentColor = med.displayColor
        quickLogFeedback = feedback
        quickLogToastGeneration = generation

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showQuickLogToast = true
        }

        scheduleQuickLogToastDismissal { [weak self] in
            self?.dismissQuickLogToast(generation: generation)
        }
    }

    private func triggerSupportToast() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showSupportToast = true
            }

            try? await Task.sleep(nanoseconds: 6_000_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showSupportToast = false
            }
        }
    }

    private func quantityDetails(quantityWasPresent: Bool) -> String {
        "quantityUpdated=\(quantityWasPresent)"
    }

    private func appendToMedicationOrderIfNeeded(_ medication: ANMedicationConcept) {
        let id = medication.id.uuidString
        var order = medicationOrder
        if !order.contains(id) {
            order.append(id)
            medicationOrder = order
        }
    }
}

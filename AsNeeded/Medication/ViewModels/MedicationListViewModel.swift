// MedicationListViewModel.swift
// View model for listing, adding, and deleting medications via DataStore.

import ANModelKit
import DHLoggingKit
import Foundation
import SwiftUI

@MainActor
final class MedicationListViewModel: ObservableObject {
    // MARK: - Properties
    private let dataStore: DataStore
    private let logger = DHLogger.ui
    private let hapticsManager = HapticsManager.shared
    private let refillProfileStore = MedicationRefillProfileStore.shared
    private let feedbackService = QuickLogFeedbackService()
    private let statusSummaryService = MedicationStatusSummaryService()

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
    init(dataStore: DataStore = .shared) {
        self.dataStore = dataStore

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

    // MARK: - Data Operations
    func add(_ med: ANMedicationConcept) async -> Bool {
        do {
            try await dataStore.addMedication(med)
            appendToMedicationOrderIfNeeded(med)
            await MedicationLiveActivityManager.refreshFromDataStore(dataStore: dataStore)
            return true
        } catch {
            logger.logPrivacySafeError("Failed to add medication", error: error)
            return false
        }
    }

    func update(_ med: ANMedicationConcept) async -> Bool {
        do {
            try await dataStore.updateMedication(med)
            await MedicationLiveActivityManager.refreshFromDataStore(dataStore: dataStore)
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
            await MedicationLiveActivityManager.refreshFromDataStore(dataStore: dataStore)
            return true
        } catch {
            logger.logPrivacySafeError("Failed to delete medication", error: error)
            return false
        }
    }

    func addEvent(_ event: ANEventConcept, shouldRecordForReview: Bool = true) async -> Bool {
        do {
            try await dataStore.addEvent(event, shouldRecordForReview: shouldRecordForReview)
            await MedicationLiveActivityManager.refreshFromDataStore(dataStore: dataStore)
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
            updated.quantity = quantity - dose.amount
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

        async let updateResult = update(updated)
        async let eventResult = addEvent(eventToSave)

        let (updateSuccess, eventSuccess) = await (updateResult, eventResult)

        if updateSuccess && eventSuccess {
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

        async let updateResult = update(updatedMed)
        async let eventResult = addEvent(event, shouldRecordForReview: false)

        let (updateSuccess, eventSuccess) = await (updateResult, eventResult)

        if updateSuccess, eventSuccess {
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
              let undoEventID = feedback.undoEventID,
              let event = dataStore.events.first(where: { $0.id == undoEventID })
        else {
            return false
        }

        do {
            try await dataStore.eventsStore.remove(event)

            if let dose = event.dose,
               let medicationID = event.medication?.id,
               let medication = dataStore.medications.first(where: { $0.id == medicationID })
            {
                var updated = medication
                if let quantity = updated.quantity {
                    updated.quantity = quantity + dose.amount
                }
                try await dataStore.updateMedication(updated)
            }

            await MedicationLiveActivityManager.refreshFromDataStore(dataStore: dataStore)
            quickLogFeedback = nil
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showQuickLogToast = false
            }
            return true
        } catch {
            logger.logPrivacySafeError("Failed to undo quick log", error: error)
            return false
        }
    }

    func dismissQuickLogToast() {
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
        quickLogMedicationName = med.displayName
        quickLogDoseAmount = dose.amount
        quickLogDoseUnit = dose.unit.abbreviation
        quickLogAccentColor = med.displayColor
        quickLogFeedback = feedback

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showQuickLogToast = true
        }

        Task {
            let toastDuration: UInt64 = 3_000_000_000
            try? await Task.sleep(nanoseconds: toastDuration)
            await MainActor.run {
                guard self.quickLogFeedback?.undoEventID == feedback?.undoEventID else {
                    return
                }
                self.quickLogFeedback = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.showQuickLogToast = false
                }
            }
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

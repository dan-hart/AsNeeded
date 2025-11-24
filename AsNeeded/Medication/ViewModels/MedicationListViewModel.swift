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
    }

    // MARK: - Data Operations
    func add(_ med: ANMedicationConcept) async -> Bool {
        do {
            try await dataStore.addMedication(med)
            return true
        } catch {
            logger.error("Failed to add medication: \(error.localizedDescription)")
            return false
        }
    }

    func update(_ med: ANMedicationConcept) async -> Bool {
        do {
            try await dataStore.updateMedication(med)
            return true
        } catch {
            logger.error("Failed to update medication: \(error.localizedDescription)")
            return false
        }
    }

    func delete(_ med: ANMedicationConcept) async -> Bool {
        do {
            try await dataStore.deleteMedication(med)
            medicationOrder.removeAll { $0 == med.id.uuidString }
            return true
        } catch {
            logger.error("Failed to delete medication: \(error.localizedDescription)")
            return false
        }
    }

    func addEvent(_ event: ANEventConcept, shouldRecordForReview: Bool = true) async -> Bool {
        do {
            try await dataStore.addEvent(event, shouldRecordForReview: shouldRecordForReview)
            return true
        } catch {
            logger.error("Failed to add event: \(error.localizedDescription)")
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

    func logDose(med: ANMedicationConcept, dose: ANDoseConcept, event: ANEventConcept) async {
        var updated = med
        if let quantity = updated.quantity, dose.amount > 0 {
            updated.quantity = quantity - dose.amount
        }

        async let updateResult = update(updated)
        async let eventResult = addEvent(event)

        let (updateSuccess, eventSuccess) = await (updateResult, eventResult)

        if updateSuccess && eventSuccess {
            logMedication = nil
            if hideSupportBanners {
                showQuickLogToast(med: med, dose: dose)
            } else {
                triggerSupportToast()
            }
        }
    }

    func quickLog(medication: ANMedicationConcept) async -> Bool {
        let dose = ANDoseConcept(
            amount: medication.prescribedDoseAmount ?? 1,
            unit: medication.prescribedUnit ?? .unit
        )

        var updatedMed = medication
        if let quantity = updatedMed.quantity, dose.amount > 0 {
            updatedMed.quantity = quantity - dose.amount
        }

        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: updatedMed,
            dose: dose,
            date: Date(),
            note: nil
        )

        async let updateResult = update(updatedMed)
        async let eventResult = addEvent(event, shouldRecordForReview: false)

        let (updateSuccess, eventSuccess) = await (updateResult, eventResult)

        if updateSuccess, eventSuccess {
            hapticsManager.doseLogged()
            showQuickLogToast(med: medication, dose: dose)
        }
        
        return updateSuccess && eventSuccess
    }

    private func showQuickLogToast(med: ANMedicationConcept, dose: ANDoseConcept) {
        quickLogMedicationName = med.displayName
        quickLogDoseAmount = dose.amount
        quickLogDoseUnit = dose.unit.abbreviation
        quickLogAccentColor = med.displayColor

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showQuickLogToast = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
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
}

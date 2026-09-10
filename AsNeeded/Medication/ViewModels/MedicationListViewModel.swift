// MedicationListViewModel.swift
// View model for listing, adding, and deleting medications via DataStore.

import ANModelKit
import Combine
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
    private let statusSummaryService = MedicationStatusSummaryService()
	/// Shared quick-log core (compensating writes, haptics, feedback, toast state).
	let quickLogCoordinator: QuickLogCoordinator
	private var quickLogCoordinatorSubscription: AnyCancellable?

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
    @Published var isLoading = true

	// MARK: - Quick Log Toast State
	// Forwarded from the coordinator; its `objectWillChange` is re-published so views observing this
	// view model refresh when the toast changes.
	var showQuickLogToast: Bool { quickLogCoordinator.showQuickLogToast }
	var quickLogMedicationName: String { quickLogCoordinator.quickLogMedicationName }
	var quickLogDoseAmount: Double { quickLogCoordinator.quickLogDoseAmount }
	var quickLogDoseUnit: String { quickLogCoordinator.quickLogDoseUnit }
	var quickLogAccentColor: Color { quickLogCoordinator.quickLogAccentColor }
	var quickLogFeedback: QuickLogFeedbackService.Feedback? { quickLogCoordinator.quickLogFeedback }
	var quickLogToastGeneration: UUID? { quickLogCoordinator.quickLogToastGeneration }

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
		self.quickLogCoordinator = QuickLogCoordinator(
			dataStore: dataStore,
			scheduleToastDismissal: scheduleQuickLogToastDismissal,
			persistence: quickLogPersistence,
			undoPersistence: quickLogUndoPersistence,
			acknowledgeDeliveredReminders: acknowledgeDeliveredReminders
		)
		quickLogCoordinatorSubscription = quickLogCoordinator.objectWillChange.sink { [weak self] _ in
			self?.objectWillChange.send()
		}

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
	/// Kept for callers and tests that build persistence through the view model; see `QuickLogCoordinator`.
	static func makeQuickLogPersistence(writes: QuickLogWrites) -> QuickLogPersistence {
		QuickLogCoordinator.makeQuickLogPersistence(writes: writes)
	}

	/// Kept for callers and tests that build undo persistence through the view model; see `QuickLogCoordinator`.
	static func makeQuickLogUndoPersistence(writes: QuickLogWrites) -> QuickLogUndoPersistence {
		QuickLogCoordinator.makeQuickLogUndoPersistence(writes: writes)
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

	// MARK: - Dose Logging
    func logDose(
        med: ANMedicationConcept,
        dose: ANDoseConcept,
        event: ANEventConcept,
        source: String = "list_sheet",
        operationID: UUID = UUID()
    ) async -> Bool {
		let success = await quickLogCoordinator.logDose(
			medication: med,
			dose: dose,
			event: event,
			source: source,
			operationID: operationID
		)
		guard success else {
			return false
		}

		logMedication = nil
		if hideSupportBanners {
			quickLogCoordinator.presentToast(medication: med, dose: dose)
		} else {
			triggerSupportToast()
		}
		return true
    }

    func quickLog(medication: ANMedicationConcept) async -> Bool {
		await quickLogCoordinator.quickLog(medication: medication, source: "list_quick_log")
    }

    func undoLastQuickLog() async -> Bool {
		await quickLogCoordinator.undoLastQuickLog()
    }

    func dismissQuickLogToast() {
		quickLogCoordinator.dismissQuickLogToast()
    }

    func statusSummary(for medication: ANMedicationConcept) -> MedicationStatusSummaryService.Summary {
        statusSummaryService.summary(
            for: medication,
            events: dataStore.events,
            profile: refillProfileStore.profile(for: medication.id)
        )
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

    private func appendToMedicationOrderIfNeeded(_ medication: ANMedicationConcept) {
        let id = medication.id.uuidString
        var order = medicationOrder
        if !order.contains(id) {
            order.append(id)
            medicationOrder = order
        }
    }
}

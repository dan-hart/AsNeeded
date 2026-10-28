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
	private let undoPersistence: (UUID) async throws -> Void
	private var undoingEventIDs: Set<UUID> = []
	private var nextConfirmationSequence = 0
	private var latestPresentedSequence = 0
	private var committedChangesTask: Task<Void, Never>?
	private var confirmationDismissTask: Task<Void, Never>?
    private let logger = DHLogger.ui
    private let hapticsManager = HapticsManager.shared
    private let safetyProfileStore = MedicationSafetyProfileStore.shared
    private let guidanceService = MedicationDoseGuidanceService()
    private let feedbackService = QuickLogFeedbackService()
    private let statusSummaryService = MedicationStatusSummaryService()

    @AppStorage(UserDefaultsKeys.medicationOrder) private var medicationOrder: [String] = []

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
	@Published var confirmationIncludesSupport = false
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
    init(dataStore: DataStore = .shared, undoPersistence: ((UUID) async throws -> Void)? = nil) {
        self.dataStore = dataStore
		self.undoPersistence = undoPersistence ?? { eventID in try await dataStore.deleteEvents(ids: [eventID]) }

        if medicationOrder.isEmpty && !items.isEmpty {
            medicationOrder = items.map { $0.id.uuidString }
        }

		let snapshots = dataStore.committedSnapshots()
		committedChangesTask = Task { [weak self] in
			for await _ in snapshots {
				guard !Task.isCancelled else { return }
				self?.objectWillChange.send()
			}
		}

        Task { [weak self] in
            await self?.finishInitialLoad()
        }
    }

	deinit {
		committedChangesTask?.cancel()
		confirmationDismissTask?.cancel()
	}

    private func finishInitialLoad() async {
        do {
            try await dataStore.prepareForAccess()
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
            return true
        } catch {
            logger.logPrivacySafeError("Failed to add medication", error: error)
            return false
        }
    }

    func update(_ med: ANMedicationConcept, original: ANMedicationConcept? = nil) async -> Bool {
        do {
            try await dataStore.updateMedication(med, original: original)
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
		guard let med = dataStore.medications.first(where: { $0.id == med.id }) else {
			logger.warning("Skipped dose log for a medication that is no longer available")
			return false
		}
        let confirmationSequence = allocateConfirmationSequence()
        let eventCountBefore = dataStore.events.count

        var eventToSave = event
        if eventToSave.medication?.id != med.id {
            logger.warning("Correcting mismatched list dose log medication: source=\(source), operationID=\(operationID.uuidString), eventHadDifferentMedication=true")
        }
        eventToSave.medication = med
		eventToSave.dose = dose

        logger.logDoseOperation(
            "Starting",
            source: source,
            operationID: operationID,
            eventCountBefore: eventCountBefore,
            details: quantityDetails(quantityWasPresent: med.quantity != nil)
        )

		let saved: Bool
		do { try await dataStore.recordDose(eventToSave); saved = true }
		catch { logger.logPrivacySafeError("Dose save failed", error: error); saved = false }
		let (updateSuccess, eventSuccess) = (saved, saved)

        if updateSuccess && eventSuccess {
            logMedication = nil
            logger.logDoseOperation(
                "Succeeded",
                source: source,
                operationID: operationID,
                eventCountBefore: eventCountBefore,
                eventCountAfter: dataStore.events.count
            )
			presentDoseConfirmation(med: med, dose: dose, event: eventToSave, sequence: confirmationSequence)
            return true
        }

        logger.error("Failed list dose log: source=\(source), operationID=\(operationID.uuidString), updateSuccess=\(updateSuccess), eventSuccess=\(eventSuccess)")
        return false
    }

    func quickLog(medication: ANMedicationConcept) async -> Bool {
		guard let medication = dataStore.medications.first(where: { $0.id == medication.id }) else {
			logger.warning("Skipped quick log for a medication that is no longer available")
			return false
		}
        let confirmationSequence = allocateConfirmationSequence()
        let operationID = UUID()
        let loggedAt = Date()
        let dose = ANDoseConcept(
            amount: medication.prescribedDoseAmount ?? 1,
            unit: medication.prescribedUnit ?? .unit
        )
        let assessment = guidanceService.assessment(
            for: medication,
            proposedDose: dose,
            at: loggedAt,
            events: dataStore.events,
            profile: safetyProfileStore.profile(for: medication.id)
        )

        let eventCountBefore = dataStore.events.count

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

		let saved: Bool
		do { try await dataStore.recordDose(event, shouldRecordForReview: false); saved = true }
		catch { logger.logPrivacySafeError("Quick dose save failed", error: error); saved = false }
		let (updateSuccess, eventSuccess) = (saved, saved)

        if updateSuccess, eventSuccess {
            let feedback = feedbackService.feedback(
                medication: medication,
                dose: dose,
                loggedEvent: event,
                assessment: assessment,
				nextDoseDate: guidanceService.nextEligibleDate(
					for: medication,
					at: loggedAt,
					events: dataStore.events,
					profile: safetyProfileStore.profile(for: medication.id)
				),
                at: loggedAt
            )
            showQuickLogToast(med: medication, dose: dose, feedback: feedback, sequence: confirmationSequence)
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

    func undoLastQuickLog(eventID: UUID? = nil) async -> Bool {
        guard let undoEventID = eventID ?? quickLogFeedback?.undoEventID,
              let event = dataStore.events.first(where: { $0.id == undoEventID }),
			  !undoingEventIDs.contains(undoEventID)
        else {
            return false
        }

		undoingEventIDs.insert(undoEventID)
		defer { undoingEventIDs.remove(undoEventID) }
        do {
			try await undoPersistence(event.id)
			// The visible toast may have been replaced or dismissed while the write awaited.
			if quickLogFeedback?.undoEventID == undoEventID {
				dismissQuickLogToast()
			}
            return true
        } catch {
            logger.logPrivacySafeError("Failed to undo quick log", error: error)
            return false
        }
    }

    func dismissQuickLogToast() {
		confirmationDismissTask?.cancel()
		confirmationDismissTask = nil
		confirmationIncludesSupport = false
        quickLogFeedback = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showQuickLogToast = false
        }
    }

	/// Confirm an already-persisted regular dose without saving it a second time.
	func presentDoseConfirmation(med: ANMedicationConcept, dose: ANDoseConcept, event: ANEventConcept, sequence: Int? = nil) {
		let now = Date()
		let assessment = guidanceService.assessment(
			for: med, proposedDose: dose, at: event.date,
			events: dataStore.events.filter { $0.id != event.id },
			profile: safetyProfileStore.profile(for: med.id)
		)
		let feedback = feedbackService.feedback(
			medication: med, dose: dose, loggedEvent: event, assessment: assessment,
			nextDoseDate: guidanceService.nextEligibleDate(for: med, at: now, events: dataStore.events, profile: safetyProfileStore.profile(for: med.id)),
			at: now
		)
		showQuickLogToast(med: med, dose: dose, feedback: feedback,
			sequence: sequence ?? allocateConfirmationSequence(), includesSupport: true)
	}

    func statusSummary(for medication: ANMedicationConcept) -> MedicationStatusSummaryService.Summary {
        statusSummaryService.summary(
            for: medication,
            events: dataStore.events,
            profile: safetyProfileStore.profile(for: medication.id)
        )
    }

	private func allocateConfirmationSequence() -> Int {
		nextConfirmationSequence += 1
		return nextConfirmationSequence
	}

    private func showQuickLogToast(
        med: ANMedicationConcept,
        dose: ANDoseConcept,
        feedback: QuickLogFeedbackService.Feedback? = nil,
		sequence: Int,
		includesSupport: Bool = false
    ) {
		guard sequence > latestPresentedSequence else { return }
		latestPresentedSequence = sequence
        quickLogMedicationName = med.displayName
        quickLogDoseAmount = dose.amount
        quickLogDoseUnit = dose.unit.abbreviation
        quickLogAccentColor = med.displayColor
        quickLogFeedback = feedback
		confirmationIncludesSupport = includesSupport

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showQuickLogToast = true
        }

		confirmationDismissTask?.cancel()
		confirmationDismissTask = Task { [weak self] in
			do { try await Task.sleep(for: .seconds(4)) }
			catch { return }
			guard !Task.isCancelled, let self,
				self.latestPresentedSequence == sequence else { return }
			self.dismissQuickLogToast()
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

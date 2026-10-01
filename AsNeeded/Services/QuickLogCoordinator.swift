// QuickLogCoordinator.swift
// Shared quick-log and sheet-log core: compensating persistence, haptics, feedback, and toast state.

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

/// Schedules the automatic dismissal of a quick-log toast. Tests inject a scheduler that records the action.
typealias QuickLogToastDismissalScheduler = (@escaping @MainActor @Sendable () -> Void) -> Void

/// Primitive store writes behind quick-log persistence. Tests can replace individual writes with
/// failing ones while the compensating logic in `QuickLogCoordinator` stays under test.
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
				// Review eligibility is recorded explicitly by the coordinator for sheet logs only.
				try await dataStore.addEvent(event, shouldRecordForReview: false)
			},
			removeEvent: { event in
				try await dataStore.eventsStore.remove(event)
			}
		)
	}
}

/// Owns everything a screen needs to log a dose with compensating writes and confirm it with a toast.
///
/// **Responsibilities:**
/// - Quick log of the default dose (`quickLog(medication:source:)`) with haptics and undo feedback
/// - Sheet-based logging (`logDose(medication:dose:event:source:operationID:)`) that counts toward review eligibility
/// - Undo of the last quick log and toast state with generation-guarded auto-dismissal
///
/// **Use Cases:**
/// - `MedicationListViewModel` (row tap/hold on the Medication tab)
/// - `MedicationHistoryViewModel` (floating Log Dose button on the History tab)
@MainActor
final class QuickLogCoordinator: ObservableObject {
	// MARK: - Properties
	private let dataStore: DataStore
	private let logger = DHLogger.ui
	private let hapticsManager = HapticsManager.shared
	private let feedbackService = QuickLogFeedbackService()
	private let scheduleToastDismissal: QuickLogToastDismissalScheduler
	/// Quantity removed by the most recent successful quick log; nil once undone.
	private var lastQuickLogQuantityDelta: Double?
	private let persistence: QuickLogPersistence
	private let undoPersistence: QuickLogUndoPersistence
	private let acknowledgeDeliveredReminders: @MainActor (UUID) async -> Void
	private let recordEventForReview: @MainActor () -> Void

	// MARK: - Published Properties
	@Published var showQuickLogToast = false
	@Published var quickLogMedicationName = ""
	@Published var quickLogDoseAmount: Double = 0
	@Published var quickLogDoseUnit = ""
	@Published var quickLogAccentColor: Color = .accent
	@Published var quickLogFeedback: QuickLogFeedbackService.Feedback?
	@Published private(set) var quickLogToastGeneration: UUID?

	// MARK: - Initialization
	init(
		dataStore: DataStore = .shared,
		scheduleToastDismissal: @escaping QuickLogToastDismissalScheduler = { action in
			Task { @MainActor in
				try? await Task.sleep(nanoseconds: 3_000_000_000)
				action()
			}
		},
		persistence: QuickLogPersistence? = nil,
		undoPersistence: QuickLogUndoPersistence? = nil,
		acknowledgeDeliveredReminders: @escaping @MainActor (UUID) async -> Void = { medicationID in
			await NotificationManager.shared.acknowledgeDeliveredReminders(for: medicationID)
		},
		recordEventForReview: @escaping @MainActor () -> Void = {
			AppReviewManager.shared.recordMedicationEvent()
		}
	) {
		self.dataStore = dataStore
		self.scheduleToastDismissal = scheduleToastDismissal
		let writes = QuickLogWrites.live(dataStore: dataStore)
		self.persistence = persistence ?? Self.makeQuickLogPersistence(writes: writes)
		self.undoPersistence = undoPersistence ?? Self.makeQuickLogUndoPersistence(writes: writes)
		self.acknowledgeDeliveredReminders = acknowledgeDeliveredReminders
		self.recordEventForReview = recordEventForReview
	}

	// MARK: - Persistence Factories
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

	// MARK: - Logging
	/// Logs the medication's default dose (prescribed amount and unit) with compensating writes.
	/// On success, delivered reminders are acknowledged, success haptics play, and the undo toast is shown.
	/// Quick logs intentionally do not count toward review eligibility.
	func quickLog(medication: ANMedicationConcept, source: String = "quick_log") async -> Bool {
		let operationID = UUID()
		let loggedAt = Date()
		let dose = ANDoseConcept(
			amount: medication.prescribedDoseAmount ?? 1,
			unit: medication.prescribedUnit ?? .unit
		)
		let eventCountBefore = dataStore.events.count
		var updatedMedication = medication
		// Track the quantity actually removed so undo restores exactly that, even when the clamp applied.
		var appliedQuantityDelta: Double = 0
		if let quantity = updatedMedication.quantity, dose.amount > 0 {
			let newQuantity = max(0, quantity - dose.amount)
			appliedQuantityDelta = quantity - newQuantity
			updatedMedication.quantity = newQuantity
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
			source: source,
			operationID: operationID,
			eventCountBefore: eventCountBefore,
			details: quantityDetails(quantityWasPresent: medication.quantity != nil)
		)

		let (updateSuccess, eventSuccess) = await persistence(updatedMedication, event)

		guard updateSuccess, eventSuccess else {
			logger.error("Failed quick dose log: source=\(source), operationID=\(operationID.uuidString), updateSuccess=\(updateSuccess), eventSuccess=\(eventSuccess)")
			return false
		}

		lastQuickLogQuantityDelta = appliedQuantityDelta
		await acknowledgeDeliveredReminders(medication.id)
		hapticsManager.doseLogged()
		let feedback = feedbackService.feedback(
			medication: medication,
			dose: dose,
			loggedEvent: event
		)
		presentToast(medication: medication, dose: dose, feedback: feedback)
		logger.logDoseOperation(
			"Succeeded",
			source: source,
			operationID: operationID,
			eventCountBefore: eventCountBefore,
			eventCountAfter: dataStore.events.count
		)
		return true
	}

	/// Logs a dose chosen in a sheet with the same compensating writes as a quick log.
	/// The quantity is clamped at zero and, on success, the event counts toward review eligibility.
	/// Callers decide which confirmation to show; this method does not present a toast.
	func logDose(
		medication: ANMedicationConcept,
		dose: ANDoseConcept,
		event: ANEventConcept,
		source: String,
		operationID: UUID = UUID()
	) async -> Bool {
		let eventCountBefore = dataStore.events.count
		var updatedMedication = medication
		if let quantity = updatedMedication.quantity, dose.amount > 0 {
			updatedMedication.quantity = max(0, quantity - dose.amount)
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

		let (updateSuccess, eventSuccess) = await persistence(updatedMedication, eventToSave)

		guard updateSuccess, eventSuccess else {
			logger.error("Failed dose log: source=\(source), operationID=\(operationID.uuidString), updateSuccess=\(updateSuccess), eventSuccess=\(eventSuccess)")
			return false
		}

		// Sheet logs count toward review eligibility (quick logs intentionally do not).
		recordEventForReview()
		logger.logDoseOperation(
			"Succeeded",
			source: source,
			operationID: operationID,
			eventCountBefore: eventCountBefore,
			eventCountAfter: dataStore.events.count
		)
		return true
	}

	// MARK: - Undo
	/// Removes the last quick-logged event and restores its quantity, then dismisses the toast.
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
				// Restore what the log removed, not the nominal dose, so a clamped log undoes cleanly.
				updated.quantity = quantity + (lastQuickLogQuantityDelta ?? dose.amount)
			}
			restoredMedication = updated
		}

		guard await undoPersistence(event, restoredMedication) else {
			logger.error("Failed to undo quick log")
			return false
		}

		lastQuickLogQuantityDelta = nil
		dismissQuickLogToast(generation: toastGeneration)
		return true
	}

	// MARK: - Toast
	/// Shows the quick-log toast for a logged dose. A new generation supersedes any pending auto-dismissal.
	func presentToast(
		medication: ANMedicationConcept,
		dose: ANDoseConcept,
		feedback: QuickLogFeedbackService.Feedback? = nil
	) {
		let generation = UUID()
		quickLogMedicationName = medication.displayName
		quickLogDoseAmount = dose.amount
		quickLogDoseUnit = dose.unit.abbreviation
		quickLogAccentColor = medication.displayColor
		quickLogFeedback = feedback
		quickLogToastGeneration = generation

		withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
			showQuickLogToast = true
		}

		scheduleToastDismissal { [weak self] in
			self?.dismissQuickLogToast(generation: generation)
		}
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

	// MARK: - Helpers
	private func quantityDetails(quantityWasPresent: Bool) -> String {
		"quantityUpdated=\(quantityWasPresent)"
	}
}

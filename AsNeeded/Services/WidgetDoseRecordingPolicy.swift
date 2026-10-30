import ANModelKit
import Foundation

/// Use the app's model-aware guidance inside the widget's atomic save boundary.
enum WidgetDoseRecordingPolicy {
	static func canLogDose(medication: ANMedicationConcept, events: [ANEventConcept],
		at date: Date = .now, profile: MedicationSafetyProfile) -> Bool {
		var snapshot = MedicationPersistenceSnapshot(medications: [medication], events: events)
		do {
			try recordDose(medicationID: medication.id, in: &snapshot, at: date, profile: profile)
			return true
		} catch { return false }
	}

	static func recordDose(medicationID: UUID, in snapshot: inout MedicationPersistenceSnapshot,
		at date: Date, profile: MedicationSafetyProfile) throws {
		guard let medication = snapshot.medications.first(where: { $0.id == medicationID && !$0.isArchived }) else {
			throw WidgetLogError.medicationUnavailable
		}
		// The first dose has no history to assess, but must still fit its saved quantity limit.
		if let maximum = medication.maximumDailyDoseAmount ?? profile.maxDailyAmount {
			guard let amount = medication.prescribedDoseAmount, amount.isFinite, amount > 0,
				medication.prescribedUnit != nil, maximum.isFinite, maximum > 0, amount <= maximum else {
				throw WidgetLogError.reviewInApp
			}
		}
		switch MedicationDoseGuidanceService().availability(for: medication, at: date, events: snapshot.events, profile: profile) {
		case .unavailable:
			throw WidgetLogError.reviewInApp
		case let .eligible(next) where next > date:
			throw WidgetLogError.reviewInApp
		default:
			break
		}
		try snapshot.recordDose(ANEventConcept(eventType: .doseTaken, medication: medication,
			dose: ANDoseConcept(amount: medication.prescribedDoseAmount ?? 1, unit: medication.prescribedUnit ?? .unit), date: date))
	}
}

@MainActor
struct WidgetDoseRecorder {
	let commit: (UUID, Date) async throws -> Void
	let reconcile: (UUID) async -> Void

	func recordDose(medicationID: UUID, at date: Date = .now) async throws {
		try await commit(medicationID, date)
		// Never report a failed dose after it committed: notification errors are handled separately.
		await reconcile(medicationID)
	}
}

enum WidgetLogError: LocalizedError, Equatable {
	case medicationUnavailable
	case reviewInApp

	var errorDescription: String? {
		switch self {
		case .medicationUnavailable:
			String(localized: "This medication is no longer available. Open AsNeeded to choose a medication.")
		case .reviewInApp:
			String(localized: "Open AsNeeded to review your saved dose limits and history before logging this dose.")
		}
	}
}

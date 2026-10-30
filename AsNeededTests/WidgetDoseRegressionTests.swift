import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Widget dose review regressions")
struct WidgetDoseRegressionTests {
	private let now = Date(timeIntervalSince1970: 1_800_000_000)

	@Test("Migrated model interval still requires review after legacy fields are cleared")
	func migratedInterval() throws {
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet,
			prescribedDoseAmount: 1, minimumHoursBetweenDoses: 4)
		let event = ANEventConcept(eventType: .doseTaken, medication: med,
			dose: ANDoseConcept(amount: 1, unit: .tablet), date: now.addingTimeInterval(-3600))
		var snapshot = MedicationPersistenceSnapshot(medications: [med], events: [event])
		#expect(throws: WidgetLogError.reviewInApp) {
			try WidgetDoseRecordingPolicy.recordDose(medicationID: med.id, in: &snapshot, at: now, profile: .empty)
		}
		#expect(snapshot.events.count == 1)
		#expect(snapshot.medications.first?.quantity == 10)
	}

	@Test("Rolling quantity and indeterminate units block silent widget logging", arguments: [true, false])
	func rollingQuantity(_ matchingUnit: Bool) {
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet,
			prescribedDoseAmount: 2, maximumDailyDoseAmount: 4)
		let event = ANEventConcept(eventType: .doseTaken, medication: med,
			dose: ANDoseConcept(amount: 4, unit: matchingUnit ? .tablet : .milligram), date: now.addingTimeInterval(-3600))
		var snapshot = MedicationPersistenceSnapshot(medications: [med], events: [event])
		#expect(throws: WidgetLogError.reviewInApp) {
			try WidgetDoseRecordingPolicy.recordDose(medicationID: med.id, in: &snapshot, at: now, profile: .empty)
		}
		#expect(snapshot.events.count == 1)
		#expect(snapshot.medications.first?.quantity == 10)
	}

	@Test("First dose and medications without limits can still be recorded", arguments: [true, false])
	func firstDose(_ configured: Bool) throws {
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet,
			prescribedDoseAmount: 2, minimumHoursBetweenDoses: configured ? 4 : nil)
		var snapshot = MedicationPersistenceSnapshot(medications: [med], events: [])
		try WidgetDoseRecordingPolicy.recordDose(medicationID: med.id, in: &snapshot, at: now, profile: .empty)
		#expect(snapshot.events.count == 1)
		#expect(snapshot.medications.first?.quantity == 8)
	}

	@Test("A first dose cannot bypass its quantity maximum or missing dose information",
		arguments: ["too large", "missing amount", "missing unit", "nonfinite"])
	func firstDoseMaximum(_ variant: String) {
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10,
			prescribedUnit: variant == "missing unit" ? nil : .tablet,
			prescribedDoseAmount: variant == "missing amount" ? nil : variant == "nonfinite" ? .infinity : variant == "missing unit" ? 2 : 10,
			maximumDailyDoseAmount: 4)
		var snapshot = MedicationPersistenceSnapshot(medications: [med], events: [])
		#expect(!WidgetDoseRecordingPolicy.canLogDose(medication: med, events: [], at: now, profile: .empty))
		#expect(throws: WidgetLogError.reviewInApp) {
			try WidgetDoseRecordingPolicy.recordDose(medicationID: med.id, in: &snapshot, at: now, profile: .empty)
		}
		#expect(snapshot.events.isEmpty)
		#expect(snapshot.medications.first?.quantity == 10)
	}

	@Test("Legacy-only quantity limits also constrain the first widget dose")
	func legacyFirstDoseMaximum() {
		let med = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet, prescribedDoseAmount: 10)
		#expect(!WidgetDoseRecordingPolicy.canLogDose(medication: med, events: [], at: now,
			profile: MedicationSafetyProfile(maxDailyAmount: 4)))
	}

	@Test("First-dose logging remains available without reporting known eligibility")
	func firstDoseAvailability() {
		let med = ANMedicationConcept(clinicalName: "Synthetic", prescribedUnit: .tablet,
			prescribedDoseAmount: 2, maximumDailyDoseAmount: 4)
		#expect(WidgetDoseRecordingPolicy.canLogDose(medication: med, events: [], at: now, profile: .empty))
		#expect(!MedicationDoseGuidanceService().canTakeNow(medication: med, at: now, events: []))
	}

	@Test("The saved window permits logging at its exact boundary")
	func exactBoundary() throws {
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet,
			prescribedDoseAmount: 1, minimumHoursBetweenDoses: 4)
		let event = ANEventConcept(eventType: .doseTaken, medication: med,
			dose: ANDoseConcept(amount: 1, unit: .tablet), date: now.addingTimeInterval(-4 * 3600))
		var snapshot = MedicationPersistenceSnapshot(medications: [med], events: [event])
		try WidgetDoseRecordingPolicy.recordDose(medicationID: med.id, in: &snapshot, at: now, profile: .empty)
		#expect(snapshot.events.count == 2)
		#expect(snapshot.medications.first?.quantity == 9)
	}

	@Test("Archived and deleted medications cannot be logged", arguments: [true, false])
	func unavailableMedication(_ archived: Bool) {
		var med = ANMedicationConcept(clinicalName: "Synthetic")
		med.isArchived = archived
		var snapshot = MedicationPersistenceSnapshot(medications: archived ? [med] : [], events: [])
		#expect(throws: WidgetLogError.medicationUnavailable) {
			try WidgetDoseRecordingPolicy.recordDose(medicationID: med.id, in: &snapshot, at: now, profile: .empty)
		}
		#expect(snapshot.events.isEmpty)
	}

	@Test("Only a successful commit triggers post-save effects, after the dose is durable", arguments: [true, false])
	func postCommitEffects(_ succeeds: Bool) async throws {
		enum Failure: Error { case injected }
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet)
		try await store.addMedication(med)
		var reconciled = false
		let recorder = WidgetDoseRecorder(commit: { id, date in
			if !succeeds { throw Failure.injected }
			try await store.recordDose(ANEventConcept(eventType: .doseTaken, medication: med,
				dose: ANDoseConcept(amount: 1, unit: .tablet), date: date))
		}, reconcile: { id in
			#expect(id == med.id)
			#expect(store.events.count == 1)
			#expect(store.medications.first?.quantity == 9)
			reconciled = true
		})
		do {
			try await recorder.recordDose(medicationID: med.id, at: now)
			#expect(succeeds)
		} catch { #expect(!succeeds) }
		#expect(reconciled == succeeds)
	}
}

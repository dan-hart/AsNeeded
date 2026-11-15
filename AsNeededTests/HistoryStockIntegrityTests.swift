import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("Core data integrity: History stock", .tags(.coreDataIntegrity, .persistence, .unit, .critical))
struct HistoryStockIntegrityTests {
	@Test("Date and note edits preserve the exact persisted fractional quantity")
	func metadataEditsPreserveFractionalStock() throws {
		let quantity = 0.3
		let medication = ANMedicationConcept(clinicalName: "Synthetic stock", quantity: quantity, prescribedUnit: .tablet)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication,
			dose: ANDoseConcept(amount: 0.1, unit: .tablet), date: Date(timeIntervalSince1970: 1_700_000_000))
		var snapshot = MedicationPersistenceSnapshot(medications: [medication], events: [event])
		let newDate = event.date.addingTimeInterval(-60)

		try snapshot.editEvent(id: event.id) { $0.date = newDate }
		#expect(snapshot.medications.first?.quantity?.bitPattern == quantity.bitPattern)
		try snapshot.editEvent(id: event.id) { $0.note = "Updated note" }
		#expect(snapshot.medications.first?.quantity?.bitPattern == quantity.bitPattern)
		#expect(snapshot.events.first?.dose == event.dose)
		#expect(snapshot.events.first?.date == newDate)
		#expect(snapshot.events.first?.note == "Updated note")
	}

	@Test("Replacing a saved dose adjusts stock by the net change only once")
	func repeatedDoseEditAdjustsStockOnce() throws {
		let medication = ANMedicationConcept(clinicalName: "Synthetic stock", quantity: 10, prescribedUnit: .tablet)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication,
			dose: ANDoseConcept(amount: 2, unit: .tablet), date: Date(timeIntervalSince1970: 1_700_000_000))
		var snapshot = MedicationPersistenceSnapshot(medications: [medication], events: [])
		try snapshot.recordDose(event)
		#expect(snapshot.medications.first?.quantity == 8)

		for _ in 0..<2 {
			try snapshot.editEvent(id: event.id) { $0.dose?.amount = 3.5 }
			#expect(snapshot.medications.first?.quantity == 6.5)
			#expect(snapshot.events.map(\.id) == [event.id])
			#expect(snapshot.events.first?.dose?.id == event.dose?.id)
			#expect(snapshot.events.first?.dose?.amount == 3.5)
		}
	}

	@Test("Editing the note on a legacy dose preserves stock and the original amount", arguments: [nil as Double?, 0, -0.5])
	func legacyDoseMetadataEditPreservesStock(_ amount: Double?) throws {
		let medication = ANMedicationConcept(clinicalName: "Synthetic stock", quantity: 10, prescribedUnit: .tablet)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication,
			dose: amount.map { ANDoseConcept(amount: $0, unit: .tablet) }, date: Date(timeIntervalSince1970: 1_700_000_000))
		var snapshot = MedicationPersistenceSnapshot(medications: [medication], events: [event])

		try snapshot.editEvent(id: event.id) { $0.note = "Reconciled legacy entry" }
		#expect(snapshot.medications == [medication])
		#expect(snapshot.events.first?.dose == event.dose)
		#expect(snapshot.events.first?.note == "Reconciled legacy entry")
	}

	@MainActor
	@Test("A stock unit change retires old effects across a change back, a backup restore, and another launch")
	func stockUnitChangeRetiresHistoricalEffects() async throws {
		let sourceDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let restoredDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer {
			try? FileManager.default.removeItem(at: sourceDirectory)
			try? FileManager.default.removeItem(at: restoredDirectory)
		}
		let sourcePreferences = try IsolatedTestPreferences()
		let source = DataStore(storageDirectory: sourceDirectory, defaults: sourcePreferences.defaults, defaultsDomainName: sourcePreferences.name)
		let medication = ANMedicationConcept(clinicalName: "Synthetic stock", quantity: 10, prescribedUnit: .tablet)
		let date = Date(timeIntervalSince1970: 1_700_000_000)
		let oldMatching = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 2, unit: .tablet), date: date)
		let oldUnmatched = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 2, unit: .milligram), date: date)
		let oldUnedited = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 2, unit: .milligram), date: date)
		try await source.addMedication(medication)
		try await source.recordDose(oldMatching)
		try await source.recordDose(oldUnmatched)
		try await source.recordDose(oldUnedited)
		#expect(source.medications.first?.quantity == 8)

		var updated = try #require(source.medications.first)
		updated.prescribedUnit = .milligram
		updated.prescribedDoseAmount = 5
		updated.quantity = 40
		try await source.updateMedication(updated)
		try await source.editEvent(id: oldMatching.id) { $0.dose?.amount = 3 }
		try await source.editEvent(id: oldUnmatched.id) { $0.dose?.unit = .tablet }
		#expect(source.medications.first?.quantity == 40)
		try await source.deleteEvents(ids: [oldUnmatched.id, oldUnedited.id])
		#expect(source.medications.first?.quantity == 40)

		let widget = MedicationPersistenceTransactions(directory: sourceDirectory,
			medicationsStore: source.medicationsStore, eventsStore: source.eventsStore)
		try await widget.perform { snapshot in
			try WidgetDoseRecordingPolicy.recordDose(medicationID: medication.id, in: &snapshot, at: date, profile: MedicationSafetyProfile())
		}
		let afterWidget = try await source.prepareForAccess()
		#expect(afterWidget.medications.first?.quantity == 35)
		let recent = try #require(afterWidget.events.first { $0.id != oldMatching.id })
		try await source.deleteEvents(ids: [recent.id])
		#expect(source.medications.first?.quantity == 40)

		updated.prescribedUnit = .tablet
		updated.quantity = 10
		try await source.updateMedication(updated)
		let backup = try await source.exportDataAsJSON(redactNames: true)
		let restoredPreferences = try IsolatedTestPreferences()
		let restored = DataStore(storageDirectory: restoredDirectory, defaults: restoredPreferences.defaults, defaultsDomainName: restoredPreferences.name)
		try await restored.importDataFromJSON(backup)
		let reopened = DataStore(storageDirectory: restoredDirectory, defaults: restoredPreferences.defaults, defaultsDomainName: restoredPreferences.name)
		let imported = try await reopened.prepareForAccess()
		#expect(imported.events.first?.dose?.amount == 3)
		#expect(imported.stockExcludedEventIDs == [oldMatching.id])
		try await reopened.deleteEvents(ids: [oldMatching.id])
		let final = try await restored.prepareForAccess()
		#expect(final.events.isEmpty)
		#expect(final.medications.first?.quantity == 10)
	}


	@MainActor
	@Test("Merging older doses into existing stock preserves the effect of locally recorded doses")
	func mergeDoesNotCreateStockCredit() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: directory) }
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let medication = ANMedicationConcept(clinicalName: "Synthetic stock", quantity: 10, prescribedUnit: .tablet)
		let date = Date(timeIntervalSince1970: 1_700_000_000)
		let local = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 2, unit: .tablet), date: date)
		let incoming = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 5, unit: .tablet), date: date)
		try await store.addMedication(medication)
		try await store.recordDose(local)
		let archive = DataExport(medications: [medication], events: [local, incoming], exportDate: date,
			appVersion: "1.2.0", dataVersion: "1.0", settings: nil)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		try await store.importDataFromJSON(encoder.encode(archive), mergeExisting: true)

		#expect(store.medications.first?.quantity == 8)
		try await store.deleteEvents(ids: [local.id, incoming.id])
		#expect(store.medications.first?.quantity == 10)
		#expect(store.events.isEmpty)
	}


	@Test("Re-enabling stock tracking does not reactivate effects from before tracking stopped")
	func restartingStockTrackingDoesNotReattachOldDoses() throws {
		let medication = ANMedicationConcept(clinicalName: "Synthetic stock", quantity: 10, prescribedUnit: .tablet)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication,
			dose: ANDoseConcept(amount: 2, unit: .tablet), date: Date(timeIntervalSince1970: 1_700_000_000))
		var snapshot = MedicationPersistenceSnapshot(medications: [medication], events: [])
		try snapshot.recordDose(event)
		#expect(snapshot.medications.first?.quantity == 8)

		var untracked = medication
		untracked.quantity = nil
		snapshot.replaceMedication(untracked, at: 0)
		try snapshot.editEvent(id: event.id) { $0.dose?.amount = 3 }
		snapshot.replaceMedication(medication, at: 0)
		snapshot.deleteEvents(ids: [event.id])
		#expect(snapshot.medications.first?.quantity == 10)
		#expect(snapshot.events.isEmpty)
	}

}

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct DataImportIntegrityTests {
	@Test("Merge validation uses retained medication values instead of skipped duplicate snapshots")
	func skippedDuplicateCannotValidateMissingReference() async throws {
		let current = ANMedicationConcept(clinicalName: "Current example", quantity: 10)
		var stale = current
		stale.clinicalName = "Old example"
		let unresolved = ANMedicationConcept(clinicalName: "Old example")
		let event = ANEventConcept(eventType: .doseTaken, medication: unresolved, date: Date())
		let store = DataStore(testIdentifier: UUID().uuidString)
		try await store.addMedication(current)
		let data = try encode(medications: [stale], events: [event])
		await #expect(throws: DataImportError.self) { try await store.importDataFromJSON(data, mergeExisting: true) }
		#expect(store.medications == [current])
		#expect(store.events.isEmpty)
	}

	@Test("An import with unresolved medication references fails before replacing existing records")
	func unresolvedReferencePreservesExistingData() async throws {
		let existing = ANMedicationConcept(clinicalName: "Existing example", quantity: 10)
		let missing = ANMedicationConcept(clinicalName: "Missing example")
		let existingEvent = ANEventConcept(eventType: .doseTaken, medication: existing, date: Date())
		let invalidEvent = ANEventConcept(eventType: .doseTaken, medication: missing, date: Date())
		let store = DataStore(testIdentifier: UUID().uuidString)
		try await store.addMedication(existing)
		try await store.addEvent(existingEvent, shouldRecordForReview: false)
		let data = try encode(medications: [], events: [invalidEvent])
		await #expect(throws: DataImportError.self) { try await store.importDataFromJSON(data) }
		#expect(store.medications.map(\.id) == [existing.id])
		#expect(store.events.map(\.id) == [existingEvent.id])
	}

	@Test("Ambiguous name-only history references fail without guessing a medication")
	func ambiguousReferenceFailsBeforeImport() async throws {
		let first = ANMedicationConcept(clinicalName: "Matching example")
		let second = ANMedicationConcept(clinicalName: "Matching example")
		let unrelatedID = ANMedicationConcept(clinicalName: "Matching example")
		let event = ANEventConcept(eventType: .doseTaken, medication: unrelatedID, date: Date())
		let store = DataStore(testIdentifier: UUID().uuidString)
		let data = try encode(medications: [first, second], events: [event])
		await #expect(throws: DataImportError.self) { try await store.importDataFromJSON(data) }
		#expect(store.medications.isEmpty)
		#expect(store.events.isEmpty)
	}

	@Test("Import keeps an event attached to its exact medication ID when names match")
	func matchingNamesDoNotReassignHistory() async throws {
		let first = ANMedicationConcept(clinicalName: "Example medication", quantity: 10)
		let second = ANMedicationConcept(clinicalName: "Example medication", quantity: 20)
		let event = ANEventConcept(eventType: .doseTaken, medication: second, dose: ANDoseConcept(amount: 0.5, unit: .unit), date: Date())
		let store = DataStore(testIdentifier: UUID().uuidString)
		try await store.importDataFromJSON(encode(medications: [first, second], events: [event]))
		#expect(store.medications.count == 2)
		#expect(store.events.count == 1)
		#expect(store.events.first?.medication?.id == second.id)
		#expect(store.events.first?.dose?.amount == 0.5)
	}

	@Test("A history-only merge retains references to medications already on the device")
	func historyOnlyMergePreservesExistingReference() async throws {
		let medication = ANMedicationConcept(clinicalName: "Example medication", quantity: 10)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .unit), date: Date())
		let store = DataStore(testIdentifier: UUID().uuidString)
		try await store.addMedication(medication)
		try await store.importDataFromJSON(encode(medications: [], events: [event]), mergeExisting: true)
		#expect(store.medications.map(\.id) == [medication.id])
		#expect(store.events.map(\.id) == [event.id])
		#expect(store.events.first?.medication?.id == medication.id)
	}

	private func encode(medications: [ANMedicationConcept], events: [ANEventConcept]) throws -> Data {
		let export = DataExport(medications: medications, events: events, exportDate: Date(), appVersion: "1.1.2", dataVersion: "1.0", settings: nil)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return try encoder.encode(export)
	}
}

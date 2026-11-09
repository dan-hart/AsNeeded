import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct DataImportIntegrityTests {
	private let date = Date(timeIntervalSince1970: 1_790_000_000)

	enum Damage: CaseIterable {
		case truncated, conflictingMedicationID, conflictingEventID, danglingReference
		case wrongQuantityType, oversizedQuantity
	}

	@Test("Damaged exports leave committed records and preferences intact", arguments: Damage.allCases, [false, true])
	func damagedImport(_ damage: Damage, merge: Bool) async throws {
		let preferences = try IsolatedTestPreferences()
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: directory) }
		let store = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let original = ANMedicationConcept(clinicalName: "Retained example", quantity: 3.5)
		let originalEvent = ANEventConcept(eventType: .doseTaken, medication: original, date: date, note: "Retained example note")
		try await store.addMedication(original)
		try await store.addEvent(originalEvent, shouldRecordForReview: false)
		preferences.defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		let before = try await store.prepareForAccess()

		let data = try damagedData(damage)
		await #expect(throws: DataImportError.self) { try await store.importDataFromJSON(data, mergeExisting: merge, applySettings: true) }
		let reader = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let after = try await reader.prepareForAccess()
		#expect(after.medications == before.medications)
		#expect(after.events == before.events)
		#expect(preferences.defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
	}

	@Test("A large valid backup preserves full notes and collapses identical records")
	func largeValidBackup() async throws {
		let medication = ANMedicationConcept(clinicalName: "Synthetic example", quantity: -0.25)
		let note = String(repeating: "Synthetic note. ", count: 16_384)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, date: date, note: note)
		let data = try encode(medications: [medication, medication], events: [event, event], dataVersion: nil)
		#expect(data.count > 256 * 1024)
		let store = DataStore(testIdentifier: UUID().uuidString)
		try await store.importDataFromJSON(data)
		let snapshot = try await store.prepareForAccess()
		#expect(snapshot.medications == [medication])
		#expect(snapshot.events == [event])
	}

	@Test("A zero dose written by older Watch clients remains recoverable")
	func legacyZeroDose() async throws {
		let medication = ANMedicationConcept(clinicalName: "Synthetic example")
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0, unit: .tablet), date: date)
		let store = DataStore(testIdentifier: UUID().uuidString)
		try await store.importDataFromJSON(encode(medications: [medication], events: [event], dataVersion: nil))
		#expect(try await store.prepareForAccess().events == [event])
	}

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

	private func damagedData(_ damage: Damage) throws -> Data {
		let medication = ANMedicationConcept(clinicalName: "Incoming example", quantity: 314_159.25)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .unit), date: date)
		var medications = [medication]
		var events = [event]
		switch damage {
		case .conflictingMedicationID:
			var conflicting = medication
			conflicting.quantity = 12.25
			medications.append(conflicting)
		case .conflictingEventID:
			var conflicting = event
			conflicting.date += 60
			events.append(conflicting)
		case .danglingReference:
			events[0].medication = ANMedicationConcept(clinicalName: "Missing example")
		case .truncated, .wrongQuantityType, .oversizedQuantity:
			break
		}
		var settings = AppSettings()
		settings.hapticsEnabled = false
		let data = try encode(medications: medications, events: events, settings: settings)
		switch damage {
		case .truncated:
			return Data(data.dropLast())
		case .wrongQuantityType, .oversizedQuantity:
			let json = String(decoding: data, as: UTF8.self)
			let invalid = damage == .wrongQuantityType ? #""0.25""# : String(repeating: "9", count: 64 * 1024)
			return Data(json.replacingOccurrences(of: "314159.25", with: invalid).utf8)
		default:
			return data
		}
	}

	private func encode(medications: [ANMedicationConcept], events: [ANEventConcept], dataVersion: String? = "1.0", settings: AppSettings? = nil) throws -> Data {
		let export = DataExport(medications: medications, events: events, exportDate: date, appVersion: "1.1.2", dataVersion: dataVersion, settings: settings)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return try encoder.encode(export)
	}
}

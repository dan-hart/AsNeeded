// DataMigrationManagerTests.swift
// Exercise the production discovery, merge, verification and archival flow in disposable directories.

import ANModelKit
@testable import AsNeeded
import Boutique
import Foundation
import Testing

@Suite("DataMigrationManager Tests", .tags(.migration, .persistence, .unit))
@MainActor
struct DataMigrationManagerTests {
	@Test("Recovering legacy records preserves newer current medications and history")
	func recoveryPreservesCurrentEdits() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let legacy = ANMedicationConcept(clinicalName: "Legacy example", quantity: 192)
		var current = legacy
		current.quantity = 30
		current.nickname = "Edited example"
		current.minimumHoursBetweenDoses = 4
		let missing = ANMedicationConcept(clinicalName: "Missing example", quantity: 12.5)
		let oldEvent = ANEventConcept(eventType: .doseTaken, medication: legacy, dose: ANDoseConcept(amount: 2, unit: .unit), date: Date(timeIntervalSince1970: 1_700_000_000), note: "Old example note")
		var editedEvent = oldEvent
		editedEvent.medication = current
		editedEvent.dose = ANDoseConcept(amount: 0.5, unit: .unit)
		editedEvent.date = oldEvent.date.addingTimeInterval(3600)
		editedEvent.note = "Edited example note"
		let missingEvent = ANEventConcept(eventType: .doseTaken, medication: missing, dose: ANDoseConcept(amount: 0.5, unit: .unit), date: oldEvent.date)
		try await fixture.seed([legacy, missing], directory: fixture.documents.appendingPathComponent("medications.sqlite"), name: "data")
		try await fixture.seed([oldEvent, missingEvent], directory: fixture.documents.appendingPathComponent("events.sqlite"), name: "data")
		try await fixture.seed([current], directory: fixture.current, name: "medications")
		try await fixture.seed([editedEvent], directory: fixture.current, name: "events")
		try await fixture.manager.migrateIfNeeded()
		try await fixture.manager.migrateIfNeeded()
		let medications = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		let events = try await fixture.read(ANEventConcept.self, directory: fixture.current, name: "events")
		#expect(Set(medications.map(\.id)) == Set([current.id, missing.id]))
		#expect(medications.first { $0.id == current.id } == current)
		#expect(Set(events.map(\.id)) == Set([editedEvent.id, missingEvent.id]))
		#expect(events.first { $0.id == editedEvent.id } == editedEvent)
		let retainedEvent = try #require(events.first { $0.id == editedEvent.id })
		#expect(retainedEvent.dose == editedEvent.dose)
		#expect(retainedEvent.date == editedEvent.date)
		#expect(retainedEvent.note == editedEvent.note)
		#expect(retainedEvent.medication?.quantity == current.quantity)
		#expect(fixture.manager.findArchivedLegacyDatabases().medications != nil)
		#expect(fixture.manager.findArchivedLegacyDatabases().events != nil)
	}

	@Test("An empty SQLite neighbor from an older reader cannot hide legacy records", arguments: ["sqlite", "db", ""])
	func emptyNeighborDoesNotHideLegacyData(fileExtension: String) async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Recovery example", quantity: 12.5)
		try await fixture.seed([medication], directory: fixture.support, name: "medications")
		let original = fixture.support.appendingPathComponent("medications.sqlite3")
		let legacy = fixture.support.appendingPathComponent(fileExtension.isEmpty ? "medications" : "medications.\(fileExtension)")
		for suffix in ["", "-wal", "-shm"] {
			let source = URL(fileURLWithPath: original.path + suffix)
			if FileManager.default.fileExists(atPath: source.path) {
				try FileManager.default.moveItem(at: source, to: URL(fileURLWithPath: legacy.path + suffix))
			}
		}
		// Older readers manufactured this empty database while opening the wrong filename.
		try await fixture.seed([ANMedicationConcept](), directory: fixture.support, name: "medications")
		try await fixture.manager.migrateIfNeeded()
		let result = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		#expect(result == [medication])
		#expect(!FileManager.default.fileExists(atPath: legacy.path))
	}

	@Test("Fresh installs and current-only installs preserve current data", arguments: [false, true])
	func noLegacyData(hasCurrentData: Bool) async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Current example", quantity: 12.5)
		if hasCurrentData { try await fixture.seed([medication], directory: fixture.current, name: "medications") }
		try await fixture.manager.migrateIfNeeded()
		let medications = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		#expect(medications.map(\.id) == (hasCurrentData ? [medication.id] : []))
		#expect(fixture.manager.findArchivedLegacyDatabases().medications == nil)
	}

	@Test("Legacy medications, notes and fractional doses survive upgrade and repeated launches")
	func upgradePreservesRecordsAndLaterEdits() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Legacy example", quantity: 12.5)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .unit), date: Date(timeIntervalSince1970: 1_700_000_000), note: "Example note")
		try await fixture.seed([medication], directory: fixture.documents.appendingPathComponent("medications.sqlite"), name: "data")
		try await fixture.seed([event], directory: fixture.documents.appendingPathComponent("events.sqlite"), name: "data")
		try await fixture.manager.migrateIfNeeded()
		let medications = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		let events = try await fixture.read(ANEventConcept.self, directory: fixture.current, name: "events")
		#expect(medications == [medication])
		#expect(events.map(\.id) == [event.id])
		#expect(events.first?.note == "Example note")
		#expect(events.first?.dose == event.dose)
		#expect(events.first?.date == event.date)
		let archived = fixture.manager.findArchivedLegacyDatabases()
		#expect(archived.medications != nil)
		#expect(archived.events != nil)
		#expect(!FileManager.default.fileExists(atPath: fixture.documents.appendingPathComponent("medications.sqlite").path))

		var edited = medication
		edited.quantity = 7.25
		try await fixture.seed([edited], directory: fixture.current, name: "medications")
		// New instances model subsequent launches; stale legacy values must never replay.
		try await fixture.manager.migrateIfNeeded()
		try await fixture.manager.migrateIfNeeded()
		let relaunched = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		let relaunchedEvents = try await fixture.read(ANEventConcept.self, directory: fixture.current, name: "events")
		#expect(relaunched == [edited])
		#expect(relaunchedEvents.count == 1)
		#expect(relaunchedEvents.first?.id == event.id)
	}

	@Test("Mixed legacy and current data deduplicates IDs without dropping distinct records")
	func mixedStoresPreserveIDs() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let legacy = ANMedicationConcept(clinicalName: "Legacy example", quantity: 12.5)
		let current = ANMedicationConcept(clinicalName: "Current example", quantity: 4)
		try await fixture.seed([legacy], directory: fixture.documents.appendingPathComponent("medications.sqlite"), name: "data")
		try await fixture.seed([legacy, current], directory: fixture.current, name: "medications")
		try await fixture.manager.migrateIfNeeded()
		let result = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		#expect(Set(result.map(\.id)) == Set([legacy.id, current.id]))
		#expect(result.count == 2)
		#expect(result.first { $0.id == current.id }?.quantity == 4)
	}

	@Test("Flat legacy filenames migrate actual records and archive only database artifacts", arguments: ["sqlite3", "sqlite", "db", ""])
	func flatFilesMigrate(fileExtension: String) async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Flat example", quantity: 12.5)
		try await fixture.seed([medication], directory: fixture.support, name: "medications")
		let original = fixture.support.appendingPathComponent("medications.sqlite3")
		let legacy = fixture.support.appendingPathComponent(fileExtension.isEmpty ? "medications" : "medications.\(fileExtension)")
		if original != legacy {
			for suffix in ["", "-wal", "-shm"] {
				let source = URL(fileURLWithPath: original.path + suffix)
				if FileManager.default.fileExists(atPath: source.path) {
					try FileManager.default.moveItem(at: source, to: URL(fileURLWithPath: legacy.path + suffix))
				}
			}
		}
		let sentinel = fixture.support.appendingPathComponent("unrelated.txt")
		try Data("unrelated fixture".utf8).write(to: sentinel)
		try await fixture.manager.migrateIfNeeded()
		let result = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		#expect(result == [medication])
		#expect(try Data(contentsOf: sentinel) == Data("unrelated fixture".utf8))
		#expect(!FileManager.default.fileExists(atPath: legacy.path))
		let archive = try #require(fixture.manager.findArchivedLegacyDatabases().medications)
		#expect(FileManager.default.fileExists(atPath: archive.appendingPathComponent(legacy.lastPathComponent).path))
	}

	@Test("Failed destination writes retain legacy data for a successful retry")
	func failureDoesNotArchiveSource() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Retry example", quantity: 12.5)
		let legacy = fixture.documents.appendingPathComponent("medications.sqlite")
		try await fixture.seed([medication], directory: legacy, name: "data")
		// A file at the destination blocks writes deterministically, without chmod or shared data.
		try FileManager.default.removeItem(at: fixture.current)
		try Data("blocked destination".utf8).write(to: fixture.current)
		await #expect(throws: (any Error).self) { try await fixture.manager.migrateIfNeeded() }
		#expect(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("data.sqlite3").path))
		#expect(fixture.manager.findArchivedLegacyDatabases().medications == nil)
		try FileManager.default.removeItem(at: fixture.current)
		try FileManager.default.createDirectory(at: fixture.current, withIntermediateDirectories: true)
		try await fixture.manager.migrateIfNeeded()
		let result = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		#expect(result == [medication])
		#expect(fixture.manager.findArchivedLegacyDatabases().medications != nil)
	}

	@Test("Corrupt legacy data fails without changing current records or archiving the source")
	func corruptionDoesNotChangeCurrentRecords() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Current example", quantity: 7.25)
		try await fixture.seed([medication], directory: fixture.current, name: "medications")
		let source = fixture.support.appendingPathComponent("medications.db")
		let original = Data("invalid database fixture".utf8)
		try original.write(to: source)
		await #expect(throws: (any Error).self) { try await fixture.manager.migrateIfNeeded() }
		#expect(try Data(contentsOf: source) == original)
		#expect(fixture.manager.findArchivedLegacyDatabases().medications == nil)
		let result = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		#expect(result == [medication])
	}

	@Test("Dry run previews the merge without moving or writing records")
	func dryRunPreservesSourceAndDestination() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Preview example", quantity: 12.5)
		try await fixture.seed([medication], directory: fixture.documents.appendingPathComponent("medications.sqlite"), name: "data")
		let report = await fixture.manager.dryRun()
		guard case .dryRunComplete = report.status else { Issue.record("Expected a successful dry run"); return }
		#expect(report.foundLegacyMedications == 1)
		#expect(report.postMergeMedications == 1)
		#expect(report.currentMedications == 0)
		#expect(fixture.manager.findArchivedLegacyDatabases().medications == nil)
		#expect(!FileManager.default.fileExists(atPath: fixture.current.appendingPathComponent("medications.sqlite3").path))
	}

	@Test("Migration preserves a large legacy medication set")
	func largeDataset() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanup() }
		let medications = (0..<1000).map { ANMedicationConcept(clinicalName: "Example \($0)", quantity: Double($0) + 0.5) }
		try await fixture.seed(medications, directory: fixture.documents.appendingPathComponent("medications.sqlite"), name: "data")
		try await fixture.manager.migrateIfNeeded()
		let result = try await fixture.read(ANMedicationConcept.self, directory: fixture.current, name: "medications")
		#expect(Set(result.map(\.id)) == Set(medications.map(\.id)))
		#expect(result.count == 1000)
	}

	@MainActor
	private struct Fixture {
		let root: URL
		let documents: URL
		let support: URL
		let current: URL
		let suite: String
		let defaults: UserDefaults

		var manager: DataMigrationManager {
			DataMigrationManager(documentsURL: documents, applicationSupportURL: support, appGroupURL: current, defaults: defaults)
		}

		init() throws {
			let identifier = UUID().uuidString
			root = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
			documents = root.appendingPathComponent("Documents")
			support = root.appendingPathComponent("Application Support")
			current = root.appendingPathComponent("App Group")
			suite = "DataMigrationManagerTests.\(identifier)"
			defaults = try #require(UserDefaults(suiteName: suite))
			for directory in [documents, support, current] {
				try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
			}
		}

		func cleanup() {
			try? FileManager.default.removeItem(at: root)
			defaults.removePersistentDomain(forName: suite)
		}

		func seed<T: Codable & Identifiable & Sendable>(_ items: [T], directory: URL, name: String) async throws where T.ID == UUID {
			let storage = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: name))
			let store = try await Store<T>(storage: storage, cacheIdentifier: \T.id.uuidString)
			try await store.insert(items)
		}

		func read<T: Codable & Identifiable & Sendable>(_ type: T.Type, directory: URL, name: String) async throws -> [T] where T.ID == UUID {
			let storage = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: name))
			let store = try await Store<T>(storage: storage, cacheIdentifier: \T.id.uuidString)
			return store.items
		}
	}
}

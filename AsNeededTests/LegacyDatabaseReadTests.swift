import ANModelKit
@testable import AsNeeded
import Boutique
import Foundation
import SQLite3
import Testing

@MainActor
struct LegacyDatabaseReadTests {
	@Test("Legacy reads retain a record stored only in the WAL sidecar")
	func uncheckpointedRecordSurvivesCopy() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let source = directory.appendingPathComponent("medications.sqlite3")
		let baseline = ANMedicationConcept(clinicalName: "Checkpointed example", quantity: 1)
		try await writeFixture(baseline, directory: directory)
		var handle: OpaquePointer?
		try #require(sqlite3_open(source.path, &handle) == SQLITE_OK)
		let connection = try #require(handle)
		defer {
			sqlite3_exec(connection, "ROLLBACK;", nil, nil, nil)
			sqlite3_close(connection)
		}
		// Only configure fixture journaling with SQLite; Boutique writes the records.
		// Pin a read snapshot so closing the writer cannot checkpoint the new record.
		try #require(sqlite3_exec(connection, "PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0; BEGIN; SELECT count(*) FROM sqlite_master;", nil, nil, nil) == SQLITE_OK)
		let medication = ANMedicationConcept(clinicalName: "WAL example", quantity: 12.5)
		try await writeFixture(medication, directory: directory)
		let wal = try Data(contentsOf: URL(fileURLWithPath: source.path + "-wal"))
		#expect(wal.count > 32)
		#expect(wal.range(of: Data(medication.id.uuidString.utf8)) != nil)

		let control = directory.appendingPathComponent("main-only.sqlite3")
		try FileManager.default.copyItem(at: source, to: control)
		let withoutSidecars = try await DataMigrationManager().loadLegacyItems(from: control, type: ANMedicationConcept.self)
		#expect(withoutSidecars == [baseline], "Control proves the new record has not reached the main file")
		let recovered = try await DataMigrationManager().loadLegacyItems(from: source, type: ANMedicationConcept.self)
		#expect(Set(recovered.map(\.id)) == Set([baseline.id, medication.id]))
		#expect(recovered.first { $0.id == medication.id }?.quantity == 12.5)
		#expect(try Data(contentsOf: URL(fileURLWithPath: source.path + "-wal")) == wal, "Reading leaves the original WAL intact")
	}

	@Test("Unreadable legacy files fail without replacing or creating source data")
	func unreadableSourceIsNotTreatedAsEmpty() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let source = directory.appendingPathComponent("medications.db")
		let original = Data("invalid database fixture".utf8)
		try original.write(to: source)
		await #expect(throws: MigrationError.self) {
			_ = try await DataMigrationManager().loadLegacyItems(from: source, type: ANMedicationConcept.self)
		}
		#expect(try Data(contentsOf: source) == original)
		#expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("medications.sqlite3").path))
	}

	@Test("Legacy readers preserve records for every discovered filename", arguments: ["sqlite3", "sqlite", "db", ""])
	func readsDiscoveredFilename(fileExtension: String) async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let medication = ANMedicationConcept(clinicalName: "Example medication", quantity: 12.5)
		try await writeFixture(medication, directory: directory)

		let original = directory.appendingPathComponent("medications.sqlite3")
		let discovered = directory.appendingPathComponent(fileExtension.isEmpty ? "medications" : "medications.\(fileExtension)")
		if original != discovered {
			for suffix in ["", "-wal", "-shm"] {
				let source = URL(fileURLWithPath: original.path + suffix)
				if FileManager.default.fileExists(atPath: source.path) {
					try FileManager.default.moveItem(at: source, to: URL(fileURLWithPath: discovered.path + suffix))
				}
			}
		}

		let items = try await DataMigrationManager().loadLegacyItems(from: discovered, type: ANMedicationConcept.self)
		#expect(items.map(\.id) == [medication.id])
		#expect(items.first?.quantity == 12.5)
		#expect(FileManager.default.fileExists(atPath: discovered.path), "Source remains available until verified archival")
		if original != discovered {
			#expect(!FileManager.default.fileExists(atPath: original.path), "Reading must not manufacture a neighboring empty database")
		}
	}

	private func writeFixture(_ medication: ANMedicationConcept, directory: URL) async throws {
		let storage = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: "medications"))
		let store = try await Store<ANMedicationConcept>(storage: storage, cacheIdentifier: \ANMedicationConcept.id.uuidString)
		try await store.insert(medication)
	}
}

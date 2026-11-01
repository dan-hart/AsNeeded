import ANModelKit
@testable import AsNeeded
import Boutique
import Foundation
import Testing

@MainActor
struct MigrationBackupIntegrityTests {
	@Test("Restoring the oldest retained backup survives safety-backup cleanup")
	func restoringOldestBackupSurvivesRetentionCleanup() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
		let manager = BackupManager(appGroupURL: directory, now: { fixedDate })
		var medication = ANMedicationConcept(clinicalName: "Retention example", quantity: 0.5)
		let original = medication
		var oldest: URL?
		for index in 0..<StorageConstants.maxBackupRetention {
			medication.quantity = Double(index) + 0.5
			try await write([medication], directory: directory)
			let result = await manager.createPreMigrationBackup()
			#expect(result.success)
			let path = try #require(result.backupPath)
			try FileManager.default.setAttributes([.creationDate: fixedDate.addingTimeInterval(Double(index))], ofItemAtPath: path.path)
			if index == 0 { oldest = path }
		}
		let restorePath = try #require(oldest)
		let restored = try await manager.restoreFromBackup(at: restorePath)
		#expect(restored)
		let result = try await read(directory: directory)
		#expect(result == [original])
	}

	@Test("Restore stops before replacement when the safety backup fails")
	func failedSafetyBackupPreservesCurrentRecords() async throws {
		let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let current = root.appendingPathComponent("current")
		let backup = root.appendingPathComponent("source")
		defer { try? FileManager.default.removeItem(at: root) }
		let original = ANMedicationConcept(clinicalName: "Current example", quantity: 12.5)
		try await write([original], directory: current)
		try await write([ANMedicationConcept(clinicalName: "Backup example")], directory: backup)
		try Data("blocked backup folder".utf8).write(to: current.appendingPathComponent(StorageConstants.backupDirectoryName))
		await #expect(throws: (any Error).self) { _ = try await BackupManager(appGroupURL: current).restoreFromBackup(at: backup) }
		let retained = try await read(directory: current)
		#expect(retained == [original])
	}

	@Test("An empty backup cannot report a successful restore")
	func emptyBackupFails() async throws {
		let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: root) }
		let backup = root.appendingPathComponent("empty")
		try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
		await #expect(throws: MigrationBackupError.self) { _ = try await BackupManager(appGroupURL: root).restoreFromBackup(at: backup) }
	}

	@Test("Two backups in the same second preserve both snapshots")
	func sameSecondBackupsRemainIndependent() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let original = ANMedicationConcept(clinicalName: "Original example", quantity: 12.5)
		try await write([original], directory: directory)
		let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
		let manager = BackupManager(appGroupURL: directory, now: { fixedDate })
		let first = await manager.createPreMigrationBackup()
		#expect(first.success)
		let firstPath = try #require(first.backupPath)
		var updated = original
		updated.quantity = 7.25
		try await write([updated], directory: directory)
		let second = await manager.createPreMigrationBackup()
		#expect(second.success)
		let secondPath = try #require(second.backupPath)
		#expect(firstPath != secondPath)
		let firstItems = try await read(directory: firstPath)
		let secondItems = try await read(directory: secondPath)
		#expect(firstItems == [original])
		#expect(secondItems == [updated])
	}

	private func write(_ medications: [ANMedicationConcept], directory: URL) async throws {
		let storage = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: StorageConstants.medicationsDBName))
		let store = try await Store<ANMedicationConcept>(storage: storage, cacheIdentifier: \ANMedicationConcept.id.uuidString)
		try await store.insert(medications)
	}

	private func read(directory: URL) async throws -> [ANMedicationConcept] {
		let storage = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: StorageConstants.medicationsDBName))
		let store = try await Store<ANMedicationConcept>(storage: storage, cacheIdentifier: \ANMedicationConcept.id.uuidString)
		return store.items
	}
}

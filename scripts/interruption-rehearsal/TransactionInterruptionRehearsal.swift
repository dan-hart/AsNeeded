// Copied into the test target of a disposable simulator checkout only.
#if targetEnvironment(simulator)
import ANModelKit
@testable import AsNeeded
import Darwin
import Foundation
import Testing

@MainActor
struct TransactionInterruptionRehearsal {
	private enum Scenario: String, CaseIterable {
		case dose, undo, importing

		var checkpoint: PersistenceTransactionPhase {
			switch self {
			case .dose: .afterMedications
			case .undo: .beforeCommit
			case .importing: .beforeCommit
			}
		}

		var preferencesName: String { "AsNeededInterruptionRehearsal.\(rawValue)" }
	}

	@Test func interruptDose() async throws { try await interrupt(.dose) }
	@Test func interruptUndo() async throws { try await interrupt(.undo) }
	@Test func interruptImport() async throws { try await interrupt(.importing) }

	@Test func recoverAfterInterruption() async throws {
		for scenario in Scenario.allCases {
			let directory = try scenarioDirectory(scenario)
			let firstRecovery = directory.appendingPathComponent("recovered")
			let journal = directory.appendingPathComponent(MedicationPersistenceTransactions.journalName)
			try #require(FileManager.default.fileExists(atPath: directory.appendingPathComponent("interrupted").path))
			try #require(FileManager.default.fileExists(atPath: journal.path) != FileManager.default.fileExists(atPath: firstRecovery.path))
			let before = try decode(Data(contentsOf: directory.appendingPathComponent("before.json")))
			let store = try makeStore(scenario, directory: directory)
			let after = try decode(await store.exportDataAsJSON(includeSettings: true))
			#expect(after.medications == before.medications)
			#expect(after.events == before.events)
			#expect(after.settings?.hapticsEnabled == before.settings?.hapticsEnabled)
			#expect(!FileManager.default.fileExists(atPath: journal.path))
			try Data().write(to: firstRecovery, options: .atomic)
		}
	}

	private func interrupt(_ scenario: Scenario) async throws {
		let directory = try scenarioDirectory(scenario)
		try #require(!FileManager.default.fileExists(atPath: directory.path))
		let seed = try makeStore(scenario, directory: directory)
		let defaults = try #require(UserDefaults(suiteName: scenario.preferencesName))
		defaults.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		let medication = ANMedicationConcept(clinicalName: "Synthetic medication", quantity: 10.5, prescribedUnit: .tablet)
		try await seed.addMedication(medication)
		let dose = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date(timeIntervalSince1970: 1_700_000_000))
		if scenario != .dose { try await seed.recordDose(dose) }
		let snapshot = try await seed.exportDataAsJSON(includeSettings: true)
		try snapshot.write(to: directory.appendingPathComponent("before.json"), options: .atomic)

		let store = try makeStore(scenario, directory: directory) { phase in
			guard phase == scenario.checkpoint else { return }
			try #require(FileManager.default.fileExists(atPath: directory.appendingPathComponent(MedicationPersistenceTransactions.journalName).path))
			try Data(String(getpid()).utf8).write(to: directory.appendingPathComponent("interrupted"), options: .atomic)
			// The harness expects the hosted test to exit at this durable write boundary.
			kill(getpid(), SIGKILL)
			Issue.record("The interrupted process unexpectedly survived SIGKILL")
		}
		switch scenario {
		case .dose:
			try await store.recordDose(dose)
		case .undo:
			try await store.deleteEvents(ids: [dose.id])
		case .importing:
			var preferences = AppSettings()
			preferences.hapticsEnabled = true
			let replacement = DataExport(medications: [ANMedicationConcept(clinicalName: "Replacement fixture", quantity: 2)],
				events: [], exportDate: dose.date, appVersion: "1.2.0", dataVersion: "1.0", settings: preferences)
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			try await store.importDataFromJSON(encoder.encode(replacement), applySettings: true)
		}
		Issue.record("The transaction completed without hitting its interruption checkpoint")
	}

	private func scenarioDirectory(_ scenario: Scenario) throws -> URL {
		try #require(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == "AsNeeded Transaction Interruption Rehearsal")
		return URL.documentsDirectory.appendingPathComponent("AsNeededTransactionRehearsal").appendingPathComponent(scenario.rawValue)
	}

	private func makeStore(_ scenario: Scenario, directory: URL,
		fault: @escaping (PersistenceTransactionPhase) throws -> Void = { _ in }) throws -> DataStore {
		let defaults = try #require(UserDefaults(suiteName: scenario.preferencesName))
		return DataStore(storageDirectory: directory, defaults: defaults, defaultsDomainName: scenario.preferencesName,
			navigationManager: NavigationManager(defaults: defaults), transactionFault: fault)
	}

	private func decode(_ data: Data) throws -> DataExport {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try decoder.decode(DataExport.self, from: data)
	}
}
#endif

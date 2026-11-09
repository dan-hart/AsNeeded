import ANModelKit
@testable import AsNeeded
import CryptoKit
import Foundation
import Testing

@MainActor
struct UpgradeFixtureTests {
	@Test("Frozen synthetic upgrade exports match their manifest")
	func fixtureManifest() throws {
		let manifest = try JSONDecoder().decode(UpgradeFixtureManifest.self, from: UpgradeFixtureLibrary.data("upgrade-fixture-manifest"))
		#expect(manifest.libraryVersion == 1)
		#expect(manifest.fixtures.map(\.name).sorted() == UpgradeFixtureLibrary.names.sorted())
		for fixture in manifest.fixtures {
			let data = try UpgradeFixtureLibrary.data(fixture.name)
			let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
			#expect(digest == fixture.sha256)
			#expect(fixture.synthetic)
			#expect(!fixture.historicalReleaseCapture)
			#expect(try UpgradeFixtureLibrary.decode(data).dataVersion == fixture.dataVersion)
		}
	}

	@Test("Older export shapes preserve exact records through import, reopen and re-export", arguments: UpgradeFixtureLibrary.names)
	func importReopenAndReexport(_ name: String) async throws {
		let fixture = try UpgradeFixtureStorage()
		defer { fixture.cleanup() }
		let data = try UpgradeFixtureLibrary.data(name)
		let expected = try UpgradeFixtureLibrary.decode(data)
		fixture.defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		fixture.defaults.set(true, forKey: UserDefaultsKeys.hideSupportBanners)
		try await fixture.makeStore().importDataFromJSON(data, applySettings: true)
		let reopened = fixture.makeStore()
		let snapshot = try await reopened.prepareForAccess()
		#expect(snapshot.medications == expected.medications)
		#expect(snapshot.events == expected.events)
		#expect(snapshot.medications.first?.isArchived == false, "Absent older archive flag defaults to active")
		#expect(snapshot.medications.map(\.quantity) == [12.25, 7.75])
		#expect(snapshot.events.map { $0.dose?.amount } == [0.5, 1.25])
		#expect(snapshot.events.map { $0.dose?.unit } == [.tablet, .milliliter])
		#expect(fixture.defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled) == (expected.settings?.hapticsEnabled ?? true))
		#expect(fixture.defaults.bool(forKey: UserDefaultsKeys.hideSupportBanners), "Omitted settings remain unchanged")
		if let settings = expected.settings {
			#expect(fixture.defaults.string(forKey: UserDefaultsKeys.historySelectedMedicationID) == settings.historySelectedMedicationID)
			#expect(fixture.defaults.storedMedicationOrder == settings.medicationOrder)
			#expect(fixture.defaults.string(forKey: UserDefaultsKeys.selectedFontFamily) == settings.selectedFontFamily)
		}
		let reexported = try UpgradeFixtureLibrary.decode(await reopened.exportDataAsJSON(includeSettings: true))
		#expect(reexported.medications == expected.medications)
		#expect(reexported.events == expected.events)
		#expect(reexported.dataVersion == "1.0")
		#expect(reexported.settings?.hapticsEnabled == (expected.settings?.hapticsEnabled ?? true))
	}

	@Test("Repeat replacement is stable and repeated merges preserve current edits", arguments: UpgradeFixtureLibrary.names)
	func repeatedImports(_ name: String) async throws {
		let fixture = try UpgradeFixtureStorage()
		defer { fixture.cleanup() }
		let data = try UpgradeFixtureLibrary.data(name)
		let expected = try UpgradeFixtureLibrary.decode(data)
		let store = fixture.makeStore()
		try await store.importDataFromJSON(data)
		try await store.importDataFromJSON(data)
		#expect(store.medications == expected.medications)
		#expect(store.events == expected.events)
		var edited = try #require(store.medications.first)
		edited.quantity = 3.25
		try await store.updateMedication(edited)
		let local = ANMedicationConcept(clinicalName: "Synthetic local record", quantity: 9.5)
		try await store.addMedication(local)
		for _ in 0..<2 { try await store.importDataFromJSON(data, mergeExisting: true) }
		let reopened = fixture.makeStore()
		let result = try await reopened.prepareForAccess()
		#expect(Set(result.medications.map(\.id)) == Set(expected.medications.map(\.id) + [local.id]))
		#expect(result.medications.first(where: { $0.id == edited.id }) == edited)
		#expect(Set(result.events.map(\.id)) == Set(expected.events.map(\.id)))
		#expect(result.events.count == expected.events.count)
		// Existing event snapshots are retained during merge; they are not rewritten to the edited medication.
		#expect(result.events == expected.events)
	}

	@Test("Fixture import failures restore records and preferences, including on next-open recovery", arguments: [false, true])
	func failedImportRecovery(_ interruptedRollback: Bool) async throws {
		let fixture = try UpgradeFixtureStorage()
		defer { fixture.cleanup() }
		let originalData = try UpgradeFixtureLibrary.data(UpgradeFixtureLibrary.names[0])
		let original = try UpgradeFixtureLibrary.decode(originalData)
		let initial = fixture.makeStore()
		try await initial.importDataFromJSON(originalData)
		var edited = try #require(initial.medications.first)
		edited.quantity = 2.75
		try await initial.updateMedication(edited)
		fixture.defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled)
		fixture.defaults.set("System", forKey: UserDefaultsKeys.selectedFontFamily)
		let baseline = try await initial.prepareForAccess()
		let failing = fixture.makeStore { phase in
			if phase == .beforeCommit || (interruptedRollback && phase == .beforeRollback) { throw UpgradeFixtureFailure.injected }
		}
		let incoming = try UpgradeFixtureLibrary.data(UpgradeFixtureLibrary.names[1])
		await #expect(throws: (any Error).self) { try await failing.importDataFromJSON(incoming, applySettings: true) }
		let journal = fixture.directory.appendingPathComponent(MedicationPersistenceTransactions.journalName)
		#expect(FileManager.default.fileExists(atPath: journal.path) == interruptedRollback)
		let reopened = fixture.makeStore()
		let recovered = try await reopened.prepareForAccess()
		#expect(recovered.medications == baseline.medications)
		#expect(recovered.events == original.events)
		#expect(fixture.defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
		#expect(fixture.defaults.string(forKey: UserDefaultsKeys.selectedFontFamily) == "System")
		#expect(!FileManager.default.fileExists(atPath: journal.path))
		try await reopened.importDataFromJSON(incoming, applySettings: true)
		#expect(reopened.medications == original.medications)
		#expect(!fixture.defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
		let secondOpen = fixture.makeStore()
		#expect(try await secondOpen.prepareForAccess().medications == original.medications)
	}
}

private enum UpgradeFixtureFailure: Error { case injected }

private enum UpgradeFixtureLibrary {
	static let names = ["upgrade-export-v1-no-settings", "upgrade-export-v1-sparse-settings"]

	static func data(_ name: String) throws -> Data {
		let bundle = Bundle(for: UpgradeFixtureBundleAnchor.self)
		// Synchronized Xcode groups may copy resources flat or preserve folder structure.
		let url = try #require(bundle.url(forResource: name, withExtension: "json")
			?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/Upgrades")
			?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Upgrades"))
		return try Data(contentsOf: url)
	}

	static func decode(_ data: Data) throws -> DataExport {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try decoder.decode(DataExport.self, from: data)
	}
}

private final class UpgradeFixtureBundleAnchor {}

private struct UpgradeFixtureManifest: Decodable {
	let libraryVersion: Int
	let fixtures: [Entry]
	struct Entry: Decodable {
		let name: String
		let sha256: String
		let dataVersion: String
		let synthetic: Bool
		let historicalReleaseCapture: Bool
	}
}

@MainActor
private struct UpgradeFixtureStorage {
	let directory = FileManager.default.temporaryDirectory.appendingPathComponent("UpgradeFixtures-\(UUID().uuidString)")
	let suite = "UpgradeFixtures-\(UUID().uuidString)"
	let defaults: UserDefaults

	init() throws {
		defaults = try #require(UserDefaults(suiteName: suite))
	}

	func makeStore(fault: @escaping (PersistenceTransactionPhase) throws -> Void = { _ in }) -> DataStore {
		DataStore(storageDirectory: directory, defaults: defaults, defaultsDomainName: suite,
			navigationManager: NavigationManager(defaults: defaults), transactionFault: fault)
	}

	func cleanup() {
		defaults.removePersistentDomain(forName: suite)
		try? FileManager.default.removeItem(at: directory)
	}
}

// This file is copied into the test target of disposable checkouts only.
#if targetEnvironment(simulator)
import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct ReleaseUpgradeRehearsal {
	private static let simulatorName = "AsNeeded 1.2 Upgrade Rehearsal"

	@Test("Tagged 1.2 storage survives an in-place 1.3 simulator upgrade")
	func verifyUpgrade() async throws {
		let environment = ProcessInfo.processInfo.environment
		try #require(environment["SIMULATOR_DEVICE_NAME"] == Self.simulatorName)
		let version = try #require(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
		let container = try #require(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.codedbydan.AsNeeded"))
		let marker = container.appendingPathComponent("AsNeededUpgradeRehearsal.json")
		let firstLaunch = container.appendingPathComponent("AsNeededUpgradeRehearsalFirstLaunch")
		let seed = try fixtureData()
		let expected = try decode(seed)
		let medication = try #require(expected.medications.first)
		let store = DataStore.shared

		if version == "1.2.0" {
			try #require(Bundle.main.infoDictionary?["CFBundleVersion"] as? String == "324")
			try #require(!FileManager.default.fileExists(atPath: marker.path))
			let empty = try await store.prepareForAccess()
			try #require(empty.medications.isEmpty && empty.events.isEmpty)
			try await store.importDataFromJSON(seed, applySettings: true)
			UserDefaults.standard.set(false, forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
			try #require(MedicationNotificationUrgencyStore.shared.save(true, for: medication.id))
			let export = try await store.exportDataAsJSON(includeSettings: true)
			let baseline = try decode(export)
			try #require(baseline.medications == expected.medications && baseline.events == expected.events)
			checkPreferences(baseline, against: expected)
			#expect(baseline.settings?.showMedicationNamesInNotifications == false)
			try export.write(to: marker, options: .atomic)
			return
		}

		try #require(version == "1.3.0")
		let baselineData = try Data(contentsOf: marker)
		let baseline = try decode(baselineData)
		try #require(baseline.appVersion == "1.2.0")
		try #require(baseline.medications == expected.medications && baseline.events == expected.events)
		let export = try await store.exportDataAsJSON(includeSettings: true)
		let current = try decode(export)
		try #require(current.medications == baseline.medications && current.events == baseline.events)
		checkPreferences(current, against: baseline)
		#expect(current.settings?.showMedicationNamesInNotifications == false)
		#expect(MedicationNotificationUrgencyStore.shared.preference(for: medication.id) == true)

		if FileManager.default.fileExists(atPath: firstLaunch.path) {
			try await verifyBackupRestore(baselineData, expected: baseline)
		} else {
			try Data().write(to: firstLaunch, options: .atomic)
		}
	}

	private func fixtureData() throws -> Data {
		let bundle = Bundle(for: RehearsalBundleAnchor.self)
		let url = try #require(bundle.url(forResource: "upgrade-rehearsal-seed", withExtension: "json"))
		return try Data(contentsOf: url)
	}

	private func decode(_ data: Data) throws -> DataExport {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try decoder.decode(DataExport.self, from: data)
	}

	private func checkPreferences(_ result: DataExport, against expected: DataExport) {
		#expect(result.dataVersion == expected.dataVersion)
		#expect(result.settings?.selectedFontFamily == expected.settings?.selectedFontFamily)
		#expect(result.settings?.hapticsEnabled == expected.settings?.hapticsEnabled)
		#expect(result.settings?.medicationOrder == expected.settings?.medicationOrder)
		#expect(result.settings?.historySelectedMedicationID == expected.settings?.historySelectedMedicationID)
	}

	private func verifyBackupRestore(_ data: Data, expected: DataExport) async throws {
		let suite = "AsNeededRehearsalRestore-\(UUID())"
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer {
			defaults.removePersistentDomain(forName: suite)
			try? FileManager.default.removeItem(at: directory)
		}
		let restore = DataStore(storageDirectory: directory, defaults: defaults, defaultsDomainName: suite,
			navigationManager: NavigationManager(defaults: defaults))
		try await restore.importDataFromJSON(data, applySettings: true)
		let reopened = DataStore(storageDirectory: directory, defaults: defaults, defaultsDomainName: suite,
			navigationManager: NavigationManager(defaults: defaults))
		let restored = try decode(await reopened.exportDataAsJSON(includeSettings: true))
		#expect(restored.medications == expected.medications)
		#expect(restored.events == expected.events)
		checkPreferences(restored, against: expected)
		#expect(restored.settings?.showMedicationNamesInNotifications == false)
	}
}

private final class RehearsalBundleAnchor {}
#endif

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct MedicationOrderCompatibilityTests {
	@Test("Native and UI-written order both survive app initialization and backup export", arguments: [false, true])
	func preservesOrder(_ writtenByUI: Bool) async throws {
		let preferences = try IsolatedTestPreferences()
		let defaults = preferences.defaults
		let first = ANMedicationConcept(clinicalName: "Synthetic first medication")
		let second = ANMedicationConcept(clinicalName: "Synthetic second medication")
		// A malformed duplicate ID must not create a duplicate SwiftUI row.
		let order = [second.id.uuidString, second.id.uuidString, first.id.uuidString]
		if writtenByUI {
			defaults.set(order.rawValue, forKey: UserDefaultsKeys.medicationOrder)
		} else {
			defaults.set(order, forKey: UserDefaultsKeys.medicationOrder)
		}

		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(preferences.name)
		defer { try? FileManager.default.removeItem(at: directory) }
		let store = DataStore(storageDirectory: directory, defaults: defaults, defaultsDomainName: preferences.name,
			navigationManager: NavigationManager(defaults: defaults))
		try await store.addMedication(first)
		try await store.addMedication(second)
		let list = MedicationListViewModel(dataStore: store, defaults: defaults)
		#expect(list.sortedMedications.map(\.id) == [second.id, first.id])
		let payload = try await store.exportDataAsJSON(includeSettings: true)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let exported = try decoder.decode(DataExport.self, from: payload)
		#expect(exported.settings?.medicationOrder == order)
	}
}

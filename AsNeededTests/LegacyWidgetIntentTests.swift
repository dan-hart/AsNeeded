import ANModelKit
import AppIntents
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Cached widget intent compatibility")
struct LegacyWidgetIntentTests {
	private final class NavigationRecorder {
		var ids: [UUID] = []
	}

	@Test("The cached logging intent opens the exact review form without recording a dose")
	func opensReview() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let medication = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet)
		try await store.addMedication(medication)
		let navigation = NavigationRecorder()
		let intent = LogDoseWidgetIntent(navigate: { id in navigation.ids.append(id) })
		intent.medicationID = medication.id.uuidString
		let result = try await intent.perform()
		let url = try #require(result.value)
		#expect(WidgetNavigationRoute(url: url) == .logDose(medication.id))
		#expect(LogDoseWidgetIntent.openAppWhenRun)
		#expect(navigation.ids == [medication.id])
		#expect(store.events.isEmpty)
		#expect(store.medications.first?.quantity == 10)
	}

	@Test("Invalid cached identifiers cannot open a different medication")
	func invalidIdentity() async {
		let intent = LogDoseWidgetIntent()
		intent.medicationID = "invalid"
		await #expect(throws: WidgetLogError.medicationUnavailable) { try await intent.perform() }
	}
}

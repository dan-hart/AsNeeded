import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Widget scoped app navigation")
struct WidgetScopedNavigationTests {
	@Test("Navigation resolves only the exact active medication", arguments: [true, false])
	func availableSelection(_ archived: Bool) throws {
		let preferences = try IsolatedTestPreferences()
		let manager = NavigationManager(defaults: preferences.defaults)
		var first = ANMedicationConcept(clinicalName: "Synthetic A")
		first.isArchived = archived
		let other = ANMedicationConcept(clinicalName: "Synthetic B")
		#expect(manager.applyWidgetRoute(.trends(first.id, days: 7), medications: [first, other]) == !archived)
		#expect(manager.widgetTrendsScope?.medicationID == (archived ? nil : first.id))
		#expect(manager.showWidgetUnavailable == archived)
		#expect(preferences.defaults.string(forKey: UserDefaultsKeys.trendsSelectedMedicationID) == nil)
	}

	@Test("Trends navigation and toolbar changes leave the saved medication selection alone")
	func transientTrends() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let first = ANMedicationConcept(clinicalName: "Synthetic A")
		let second = ANMedicationConcept(clinicalName: "Synthetic B")
		try await store.addMedication(first)
		try await store.addMedication(second)
		let model = MedicationTrendsViewModel(dataStore: store, defaults: preferences.defaults, selectedMedicationID: first.id, transientSelection: true)
		let saved = model.selectedMedicationIDString
		#expect(model.selectedMedicationID == first.id)
		model.selectedMedicationID = second.id
		#expect(model.selectedMedicationIDString == saved)
		#expect(model.selectedMedicationID == second.id)
		try await store.deleteMedication(second)
		await model.refreshAfterForeground()
		model.ensureValidSelection()
		#expect(model.selectedMedication == nil)
		#expect(model.selectedMedicationID == second.id)
	}

	@Test("Detail, History and dose links dispatch UI destinations without writing data")
	func destinations() throws {
		let preferences = try IsolatedTestPreferences()
		let manager = NavigationManager(defaults: preferences.defaults)
		let med = ANMedicationConcept(clinicalName: "Synthetic")
		#expect(manager.applyWidgetRoute(.medication(med.id), medications: [med]))
		#expect(manager.pendingMedicationDetail == med.id.uuidString)
		#expect(manager.applyWidgetRoute(.logDose(med.id), medications: [med]))
		#expect(manager.pendingLogMedicationID == med.id.uuidString)
		#expect(manager.pendingMedicationDetail == nil)
		#expect(manager.applyWidgetRoute(.history(med.id), medications: [med]))
		#expect(manager.historyTargetMedicationID == med.id.uuidString)
		let previousHistoryRequest = manager.historyRequestID
		#expect(manager.applyWidgetRoute(.history(med.id), medications: [med]))
		#expect(manager.historyRequestID != previousHistoryRequest)
		#expect(manager.applyWidgetRoute(.logDose(nil), medications: [med]))
		#expect(manager.shouldShowLogDoseChooser)
	}
	@Test("New destinations cancel older queued forms and choosers")
	func supersededRequests() throws {
		let preferences = try IsolatedTestPreferences()
		let manager = NavigationManager(defaults: preferences.defaults)
		let first = ANMedicationConcept(clinicalName: "Synthetic A")
		let second = ANMedicationConcept(clinicalName: "Synthetic B")
		for destination: WidgetNavigationRoute in [.medication(second.id), .history(second.id), .trends(second.id, days: 7), .medications] {
			#expect(manager.applyWidgetRoute(.logDose(first.id), medications: [first, second]))
			#expect(manager.applyWidgetRoute(destination, medications: [first, second]))
			#expect(manager.pendingLogMedicationID == nil)
			#expect(!manager.shouldShowLogDoseChooser)
			#expect(manager.applyWidgetRoute(.logDose(nil), medications: [first, second]))
			#expect(manager.applyWidgetRoute(destination, medications: [first, second]))
			#expect(!manager.shouldShowLogDoseChooser)
		}
		#expect(manager.applyWidgetRoute(.medication(first.id), medications: [first, second]))
		#expect(manager.applyWidgetRoute(.logDose(second.id), medications: [first, second]))
		#expect(manager.pendingMedicationDetail == nil)
		#expect(manager.pendingLogMedicationID == second.id.uuidString)
		#expect(!manager.applyWidgetRoute(.medication(UUID()), medications: [first, second]))
		#expect(manager.pendingLogMedicationID == nil)
	}

	@Test("Normal History navigation retains archived records; widget entry remains active-only")
	func archivedHistory() throws {
		let preferences = try IsolatedTestPreferences()
		let manager = NavigationManager(defaults: preferences.defaults)
		var med = ANMedicationConcept(clinicalName: "Archived synthetic")
		med.isArchived = true
		manager.navigateToHistory(medicationID: med.id.uuidString)
		#expect(manager.historyTargetMedicationID == med.id.uuidString)
		#expect(!manager.showWidgetUnavailable)
		#expect(!manager.applyWidgetRoute(.history(med.id), medications: [med]))
		#expect(manager.historyTargetMedicationID == nil)
	}

}

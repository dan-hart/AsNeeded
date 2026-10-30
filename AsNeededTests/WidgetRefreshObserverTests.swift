import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct WidgetRefreshObserverTests {
	@Test("Stable reads do not spend reloads; doses, edits and deletion refresh widgets")
	func committedChanges() {
		var reloads = 0
		let observer = WidgetRefreshObserver { reloads += 1 }
		var med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10)
		let initial = MedicationPersistenceSnapshot(medications: [med], events: [])
		observer.receive(initial)
		observer.receive(initial)
		#expect(reloads == 1)
		let dose = ANEventConcept(eventType: .doseTaken, medication: med, dose: ANDoseConcept(amount: 1, unit: .tablet))
		observer.receive(MedicationPersistenceSnapshot(medications: [med], events: [dose]))
		#expect(reloads == 2)
		med.nickname = "Renamed"
		observer.receive(MedicationPersistenceSnapshot(medications: [med], events: [dose]))
		#expect(reloads == 3)
		observer.receive(MedicationPersistenceSnapshot(medications: [], events: []))
		#expect(reloads == 4)
	}
	@Test("The store reload hook follows committed state and ignores failed saves")
	func realCommitBoundary() async throws {
		enum Failure: Error { case injected }
		let preferences = try IsolatedTestPreferences()
		var reloads = 0
		var fail = false
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
			defaults: preferences.defaults, defaultsDomainName: preferences.name, transactionFault: { phase in
				if fail, phase == .beforeCommit { throw Failure.injected }
			}, widgetReload: { reloads += 1 })
		_ = try await store.prepareForAccess()
		let initial = reloads
		let med = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet)
		try await store.addMedication(med)
		#expect(reloads == initial + 1)
		_ = try await store.prepareForAccess()
		#expect(reloads == initial + 1)
		fail = true
		await #expect(throws: Failure.injected) {
			try await store.recordDose(ANEventConcept(eventType: .doseTaken, medication: med,
				dose: ANDoseConcept(amount: 1, unit: .tablet)))
		}
		#expect(reloads == initial + 1)
		#expect(store.events.isEmpty)
		#expect(store.medications.first?.quantity == 10)
	}

	@Test("Profile-only changes refresh timing even when medication and event arrays are unchanged")
	func profileChanges() throws {
		let preferences = try IsolatedTestPreferences()
		var reloads = 0
		let observer = WidgetRefreshObserver { reloads += 1 }
		let snapshot = MedicationPersistenceSnapshot(medications: [], events: [])
		observer.receive(snapshot)
		observer.receive(snapshot, profileData: Data([1]))
		observer.receive(snapshot, profileData: Data([1]))
		observer.receive(snapshot)
		#expect(reloads == 3)
		var saves = 0
		let profiles = MedicationSafetyProfileStore(defaults: preferences.defaults, mirrorToSharedDefaults: false,
			widgetReload: { saves += 1 })
		let id = UUID()
		profiles.save(MedicationSafetyProfile(minimumHoursBetweenDoses: 4), for: id)
		profiles.save(.empty, for: id)
		#expect(saves == 2)
	}

}

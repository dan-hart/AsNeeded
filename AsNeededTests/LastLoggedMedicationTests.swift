import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Last logged medication", .tags(.persistence, .unit))
struct LastLoggedMedicationTests {
	@Test("A backdated new dose becomes the target and an older retry cannot replace it")
	func recordingOrderAndRestart() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		try await fixture.seed()
		try await fixture.store.recordDose(fixture.recent)
		try await fixture.store.recordDose(fixture.backdated)
		try await fixture.store.recordDose(fixture.recent)
		#expect(fixture.store.lastLoggedMedication?.id == fixture.second.id)
		#expect(fixture.defaults.stringArray(forKey: UserDefaultsKeys.lastLoggedDoseEventIDs)?.first == fixture.backdated.id.uuidString)
		let restarted = DataStore(storageDirectory: fixture.directory, defaults: fixture.defaults, defaultsDomainName: fixture.suite)
		try await restarted.prepareForAccess()
		#expect(restarted.lastLoggedMedication?.id == fixture.second.id)
		#expect(restarted.events.count == 2)
	}

	@Test("Undo preserves recording order when earlier saves were backdated")
	func undoBackdatedRecordingOrder() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		try await fixture.seed()
		try await fixture.store.recordDose(fixture.recent)
		try await fixture.store.recordDose(fixture.backdated)
		let third = ANEventConcept(eventType: .doseTaken, medication: fixture.first, dose: fixture.recent.dose, date: fixture.recent.date)
		try await fixture.store.recordDose(third)
		try await fixture.store.deleteEvents(ids: [third.id])
		#expect(fixture.store.lastLoggedMedication?.id == fixture.second.id)
	}

	@Test("Failed commit rolls back the target along with history and stock")
	func failedCommit() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		try await fixture.seed()
		try await fixture.store.recordDose(fixture.recent)
		fixture.failCommit = true
		do {
			try await fixture.store.recordDose(fixture.backdated)
			Issue.record("Expected persistence failure")
		} catch {}
		#expect(fixture.store.lastLoggedMedication?.id == fixture.first.id)
		#expect(fixture.defaults.stringArray(forKey: UserDefaultsKeys.lastLoggedDoseEventIDs)?.first == fixture.recent.id.uuidString)
		#expect(fixture.store.events.count == 1)
		#expect(fixture.store.medications.first { $0.id == fixture.second.id }?.quantity == 10)
	}

	@Test("Restart recovers recording recency after an interrupted commit")
	func interruptedCommit() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		try await fixture.seed()
		try await fixture.store.recordDose(fixture.recent)
		fixture.cancelCommit = true
		do {
			try await fixture.store.recordDose(fixture.backdated)
			Issue.record("Expected interrupted persistence")
		} catch {}
		let restarted = DataStore(storageDirectory: fixture.directory, defaults: fixture.defaults, defaultsDomainName: fixture.suite)
		try await restarted.prepareForAccess()
		#expect(restarted.lastLoggedMedication?.id == fixture.first.id)
		#expect(fixture.defaults.stringArray(forKey: UserDefaultsKeys.lastLoggedDoseEventIDs)?.first == fixture.recent.id.uuidString)
		#expect(restarted.events.map(\.id) == [fixture.recent.id])
	}

	@Test("Undo, archive and deletion resolve only remaining active current medications")
	func unavailableTargets() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		try await fixture.seed()
		#expect(fixture.store.lastLoggedMedication == nil)
		try await fixture.store.recordDose(fixture.recent)
		try await fixture.store.recordDose(fixture.backdated)
		try await fixture.store.deleteEvents(ids: [fixture.backdated.id])
		#expect(fixture.store.lastLoggedMedication?.id == fixture.first.id)
		var changed = fixture.first
		changed.clinicalName = "Current name"
		try await fixture.store.updateMedication(changed)
		#expect(fixture.store.lastLoggedMedication?.clinicalName == "Current name")
		changed.isArchived = true
		try await fixture.store.updateMedication(changed)
		#expect(fixture.store.lastLoggedMedication == nil)
		try await fixture.store.deleteMedication(changed)
		#expect(fixture.store.lastLoggedMedication == nil)
	}

	@Test("Upgrade fallback chooses latest valid dose history and excludes orphaned records")
	func upgradeFallback() {
		let current = ANMedicationConcept(clinicalName: "Current")
		let missing = ANMedicationConcept(clinicalName: "Deleted")
		let valid = ANEventConcept(eventType: .doseTaken, medication: current, date: Date(timeIntervalSince1970: 100))
		let orphan = ANEventConcept(eventType: .doseTaken, medication: missing, date: Date(timeIntervalSince1970: 200))
		#expect(LastLoggedMedicationResolver.resolve(medications: [current], events: [valid, orphan], lastLoggedEventIDs: [])?.id == current.id)
		#expect(LastLoggedMedicationResolver.resolve(medications: [current], events: [valid, orphan], lastLoggedEventIDs: [UUID()])?.id == current.id)
	}

	@Test("Recency is removed on reset and never transferred as app settings")
	func localPreferencePolicy() {
		let key = UserDefaultsKeys.lastLoggedDoseEventIDs
		#expect(UserDefaultsKeys.allKeys.contains(key))
		#expect(UserDefaultsKeys.keysToRemove.contains(key))
		#expect(UserDefaultsKeys.keysToNeverExport.contains(key))
		#expect(!UserDefaultsKeys.safeToExportKeys.contains(key))
	}

	private enum Failure: Error { case injected }
	@MainActor
	private final class Fixture {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LastLogged-\(UUID().uuidString)")
		let suite = "LastLogged-\(UUID().uuidString)"
		let defaults: UserDefaults
		let first = ANMedicationConcept(clinicalName: "First", quantity: 10, prescribedUnit: .tablet)
		let second = ANMedicationConcept(clinicalName: "Second", quantity: 10, prescribedUnit: .tablet)
		var failCommit = false
		var cancelCommit = false
		lazy var recent = ANEventConcept(eventType: .doseTaken, medication: first, dose: ANDoseConcept(amount: 1, unit: .tablet), date: Date(timeIntervalSince1970: 200))
		lazy var backdated = ANEventConcept(eventType: .doseTaken, medication: second, dose: ANDoseConcept(amount: 1, unit: .tablet), date: Date(timeIntervalSince1970: 100))
		lazy var store = DataStore(storageDirectory: directory, defaults: defaults, defaultsDomainName: suite, transactionFault: { phase in
			if self.cancelCommit, phase == .beforeCommit { throw CancellationError() }
			if self.failCommit, phase == .beforeCommit { throw Failure.injected }
		})
		init() throws { defaults = try #require(UserDefaults(suiteName: suite)) }
		func seed() async throws {
			try await store.addMedication(first)
			try await store.addMedication(second)
		}
		func cleanUp() {
			defaults.removePersistentDomain(forName: suite)
			try? FileManager.default.removeItem(at: directory)
		}
	}
}

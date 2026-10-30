import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Reminder persistence integration", .tags(.service, .notifications, .unit))
struct ReminderPersistenceIntegrationTests {
	@Test("Cleanup follows committed removal only", arguments: ["delete", "clear", "replace"])
	func cleanupAfterCommit(operation: String) async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		try await fixture.store.addMedication(fixture.medication)
		fixture.failCommit = true
		do {
			try await fixture.remove(operation)
			Issue.record("Expected injected persistence failure")
		} catch {}
		#expect(fixture.removed.isEmpty)
		#expect(fixture.store.medications.map(\.id) == [fixture.medication.id])
		fixture.failCommit = false
		try await fixture.remove(operation)
		#expect(fixture.removed == [Set([fixture.medication.id])])
		#expect(fixture.store.medications.isEmpty)
	}

	@Test("Delivered reminders are acknowledged after dose commit and successful retry")
	func acknowledgeAfterCommit() async throws {
		let fixture = try Fixture()
		defer { fixture.cleanUp() }
		try await fixture.store.addMedication(fixture.medication)
		let event = ANEventConcept(eventType: .doseTaken, medication: fixture.medication, dose: ANDoseConcept(amount: 1, unit: .tablet), date: Date(timeIntervalSince1970: 2_000_000_000))
		fixture.failCommit = true
		do {
			try await fixture.store.recordDose(event)
			Issue.record("Expected injected persistence failure")
		} catch {}
		#expect(fixture.acknowledged.isEmpty)
		fixture.failCommit = false
		try await fixture.store.recordDose(event)
		try await fixture.store.recordDose(event)
		#expect(fixture.acknowledged == [fixture.medication.id, fixture.medication.id])
		#expect(fixture.store.events.count == 1)
		#expect(fixture.store.medications.first?.quantity == 9)
	}

	private enum Failure: Error { case expected }
	@MainActor
	private final class Fixture {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReminderPersistence-\(UUID().uuidString)")
		let suite = "ReminderPersistence-\(UUID().uuidString)"
		let defaults: UserDefaults
		let medication = ANMedicationConcept(clinicalName: "Synthetic", quantity: 10, prescribedUnit: .tablet)
		var failCommit = false
		var removed: [Set<UUID>] = []
		var acknowledged: [UUID] = []
		lazy var store = DataStore(storageDirectory: directory, defaults: defaults, defaultsDomainName: suite, transactionFault: { phase in
			if self.failCommit, phase == .beforeCommit { throw Failure.expected }
		}, notificationCleanup: { ids in
			if !ids.isEmpty { self.removed.append(ids) }
		}, reminderAcknowledgement: { self.acknowledged.append($0) })
		init() throws { defaults = try #require(UserDefaults(suiteName: suite)) }
		func cleanUp() {
			defaults.removePersistentDomain(forName: suite)
			try? FileManager.default.removeItem(at: directory)
		}
		func remove(_ operation: String) async throws {
			switch operation {
			case "delete": try await store.deleteMedication(medication)
			case "clear": try await store.clearUserData()
			default:
				let export = DataExport(medications: [], events: [], exportDate: Date(timeIntervalSince1970: 2_000_000_000), appVersion: "1.2.0", dataVersion: "1.0", settings: nil)
				let encoder = JSONEncoder()
				encoder.dateEncodingStrategy = .iso8601
				try await store.importDataFromJSON(encoder.encode(export))
			}
		}
	}
}

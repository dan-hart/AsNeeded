import ANModelKit
@testable import AsNeeded
import Foundation
import Boutique
import Testing

@MainActor
struct AtomicPersistenceTests {
	@Test("A failed dose event write restores stock and permits one clean retry")
	func failedDoseSaveRestoresBothStores() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Atomic example", quantity: 10.5, prescribedUnit: .tablet)
		try await fixture.store.addMedication(medication)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		let viewModel = MedicationDetailViewModel(dataStore: fixture.store)
		let dose = try #require(event.dose)
		fixture.fault.phase = .afterMedications
		#expect(await viewModel.logDose(medication: medication, dose: dose, event: event, source: "atomic_test") == false)
		#expect(fixture.store.medications.first?.quantity == 10.5)
		#expect(fixture.store.events.isEmpty)
		#expect(await viewModel.logDose(medication: medication, dose: dose, event: event, source: "atomic_test"))
		#expect(await viewModel.logDose(medication: medication, dose: dose, event: event, source: "atomic_test"))
		#expect(fixture.store.medications.first?.quantity == 10)
		#expect(fixture.store.events.map(\.id) == [event.id])
	}

	@Test("A failed replacing import restores records and preferences")
	func failedImportRestoresOriginalSnapshot() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let original = ANMedicationConcept(clinicalName: "Original example", quantity: 12.5)
		let oldEvent = ANEventConcept(eventType: .doseTaken, medication: original, date: Date(), note: "Retained example note")
		try await fixture.store.addMedication(original)
		try await fixture.store.addEvent(oldEvent, shouldRecordForReview: false)
		fixture.defaults.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		let incoming = ANMedicationConcept(clinicalName: "Imported example", quantity: 1)
		var settings = AppSettings()
		settings.hapticsEnabled = true
		let export = DataExport(medications: [incoming], events: [], exportDate: Date(), appVersion: "1.1.2", dataVersion: "1.0", settings: settings)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let data = try encoder.encode(export)
		fixture.fault.phase = .beforeCommit
		await #expect(throws: (any Error).self) { try await fixture.store.importDataFromJSON(data, applySettings: true) }
		#expect(fixture.store.medications == [original])
		#expect(fixture.store.events.map(\.id) == [oldEvent.id])
		#expect(fixture.store.events.first?.note == oldEvent.note)
		#expect(fixture.defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled) == false)
	}

	@Test("An interrupted write is recovered even by a reader with an unchanged old cache")
	func interruptedSaveRecoversAcrossInstances() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Interrupted example", quantity: 10.5, prescribedUnit: .tablet)
		try await fixture.store.addMedication(medication)
		let reader = DataStore(storageDirectory: fixture.directory, defaults: fixture.defaults, sharedDefaults: fixture.sharedDefaults, defaultsDomainName: fixture.suite, sharedDefaultsDomainName: fixture.suite + ".shared")
		try await reader.prepareForAccess()
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		fixture.fault.cancelAt = .afterMedications
		await #expect(throws: (any Error).self) { try await fixture.store.recordDose(event) }
		#expect(FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent(MedicationPersistenceTransactions.journalName).path))
		let restored = try await reader.prepareForAccess()
		#expect(restored.medications == [medication])
		#expect(restored.events.isEmpty)
		let reopened = DataStore(storageDirectory: fixture.directory, defaults: fixture.defaults, defaultsDomainName: fixture.suite)
		#expect(try await reopened.prepareForAccess().medications == [medication])
		try await reader.recordDose(event)
		try await reader.recordDose(event)
		#expect(reader.medications.first?.quantity == 10)
		#expect(reader.events.map(\.id) == [event.id])
	}

	@Test("Failed rollback retains the journal until the next successful recovery")
	func failedRollbackRemainsRecoverable() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Recovery example", quantity: 10.5, prescribedUnit: .tablet)
		try await fixture.store.addMedication(medication)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		fixture.fault.phases = [.afterMedications, .beforeRollback]
		await #expect(throws: PersistenceTransactionError.self) { try await fixture.store.recordDose(event) }
		let journal = fixture.directory.appendingPathComponent(MedicationPersistenceTransactions.journalName)
		#expect(FileManager.default.fileExists(atPath: journal.path))
		#expect(fixture.store.medications.first?.quantity == 10.5, "Visible state remains the pre-save snapshot")
		try await fixture.store.prepareForAccess()
		#expect(fixture.store.medications == [medication])
		#expect(fixture.store.events.isEmpty)
		#expect(!FileManager.default.fileExists(atPath: journal.path))
	}

	@Test("Replacing import rolls back after a partial event batch")
	func partialEventImportRollsBack() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let original = ANMedicationConcept(clinicalName: "Original example", quantity: 12.5)
		let oldEvent = ANEventConcept(eventType: .doseTaken, medication: original, date: Date(), note: "Retained note")
		try await fixture.store.addMedication(original)
		try await fixture.store.addEvent(oldEvent, shouldRecordForReview: false)
		let incoming = ANMedicationConcept(clinicalName: "Incoming example")
		let events = (0..<3).map { _ in ANEventConcept(eventType: .doseTaken, medication: incoming, date: Date()) }
		let data = try encode(medications: [incoming], events: events)
		fixture.fault.phase = .afterEvent(0)
		await #expect(throws: (any Error).self) { try await fixture.store.importDataFromJSON(data) }
		let recovered = try await fixture.store.prepareForAccess()
		#expect(recovered.medications == [original])
		#expect(recovered.events.map(\.id) == [oldEvent.id])
		#expect(recovered.events.first?.note == oldEvent.note)
	}

	@Test("Widget reads prior data but cannot recover another process's settings")
	func widgetCannotRestoreApplicationDefaults() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let original = ANMedicationConcept(clinicalName: "Current example", quantity: 12.5)
		try await fixture.store.addMedication(original)
		fixture.defaults.removeObject(forKey: UserDefaultsKeys.hideSupportBanners)
		let oldShared = Data("retained profile fixture".utf8)
		fixture.sharedDefaults.set(oldShared, forKey: UserDefaultsKeys.medicationSafetyProfiles)
		let incoming = ANMedicationConcept(clinicalName: "Incoming example")
		var settings = AppSettings()
		settings.hideSupportBanners = true
		settings.medicationSafetyProfiles = [:]
		fixture.fault.cancelAt = .beforeCommit
		let data = try encode(medications: [incoming], events: [], settings: settings)
		await #expect(throws: (any Error).self) { try await fixture.store.importDataFromJSON(data, applySettings: true) }
		#expect(fixture.defaults.bool(forKey: UserDefaultsKeys.hideSupportBanners))
		let widget = makeCoordinator(fixture, preferences: [:])
		await #expect(throws: PersistenceTransactionError.self) { _ = try await widget.read() }
		await #expect(throws: PersistenceTransactionError.self) { try await widget.perform { $0.medications = [] } }
		#expect(fixture.defaults.bool(forKey: UserDefaultsKeys.hideSupportBanners), "Widget cannot write the main app's preference domain")
		try await fixture.store.prepareForAccess()
		#expect(fixture.defaults.object(forKey: UserDefaultsKeys.hideSupportBanners) == nil)
		#expect(fixture.sharedDefaults.data(forKey: UserDefaultsKeys.medicationSafetyProfiles) == oldShared)
		#expect(fixture.store.medications == [original])
	}

	@Test("Concurrent saves calculate stock from committed data", arguments: [false, true])
	func concurrentSavesDoNotLoseStockUpdates(independentInstances: Bool) async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Concurrent example", quantity: 10.5, prescribedUnit: .tablet)
		try await fixture.store.addMedication(medication)
		let second = independentInstances ? DataStore(storageDirectory: fixture.directory, defaults: fixture.defaults, defaultsDomainName: fixture.suite) : fixture.store
		let firstEvent = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		let secondEvent = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		async let first: Void = fixture.store.recordDose(firstEvent)
		async let next: Void = second.recordDose(secondEvent)
		_ = try await (first, next)
		let snapshot = try await fixture.store.prepareForAccess()
		#expect(snapshot.medications.first?.quantity == 9.5)
		#expect(Set(snapshot.events.map(\.id)) == Set([firstEvent.id, secondEvent.id]))
	}

	@Test("Dose edits and repeated Undo adjust only compatible stock units")
	func editsAndUndoPreserveStockUnits() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Unit example", quantity: 10.5, prescribedUnit: .tablet)
		try await fixture.store.addMedication(medication)
		var event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		try await fixture.store.recordDose(event)
		event.dose = ANDoseConcept(amount: 1, unit: .tablet)
		try await fixture.store.updateEvent(event)
		#expect(fixture.store.medications.first?.quantity == 9.5)
		event.dose = ANDoseConcept(amount: 20, unit: .milligram)
		try await fixture.store.updateEvent(event)
		#expect(fixture.store.medications.first?.quantity == 10.5, "No inferred tablet/milligram conversion")
		try await fixture.store.deleteEvents(ids: [event.id])
		try await fixture.store.deleteEvents(ids: [event.id])
		#expect(fixture.store.medications.first?.quantity == 10.5)
		#expect(fixture.store.events.isEmpty)
	}

	@Test("Failure before journal creation leaves both databases untouched")
	func failedJournalWriteDoesNotMutateData() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Journal example", quantity: 10.5, prescribedUnit: .tablet)
		try await fixture.store.addMedication(medication)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		fixture.fault.phase = .beforeJournal
		await #expect(throws: (any Error).self) { try await fixture.store.recordDose(event) }
		#expect(try await fixture.store.prepareForAccess().medications == [medication])
		#expect(fixture.store.events.isEmpty)
	}

	@Test("Corrupt recovery metadata is retained and blocks new writes")
	func corruptJournalFailsClosed() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Retained example", quantity: 10.5)
		try await fixture.store.addMedication(medication)
		let path = fixture.directory.appendingPathComponent(MedicationPersistenceTransactions.journalName)
		let corrupt = Data("invalid recovery fixture".utf8)
		try corrupt.write(to: path)
		await #expect(throws: PersistenceTransactionError.self) { try await fixture.store.prepareForAccess() }
		await #expect(throws: PersistenceTransactionError.self) { try await fixture.store.addMedication(ANMedicationConcept(clinicalName: "Must not appear")) }
		#expect(try Data(contentsOf: path) == corrupt)
		#expect(fixture.store.medications == [medication])
	}

	@Test("Decodable but inconsistent recovery metadata cannot delete valid records")
	func inconsistentJournalFailsClosed() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let medication = ANMedicationConcept(clinicalName: "Retained example", quantity: 10.5, prescribedUnit: .tablet)
		try await fixture.store.addMedication(medication)
		fixture.fault.cancelAt = .afterMedications
		let event = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		await #expect(throws: (any Error).self) { try await fixture.store.recordDose(event) }
		let path = fixture.directory.appendingPathComponent(MedicationPersistenceTransactions.journalName)
		var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
		json["medications"] = []
		let inconsistent = try JSONSerialization.data(withJSONObject: json)
		try inconsistent.write(to: path)
		await #expect(throws: PersistenceTransactionError.self) { _ = try await fixture.store.prepareForAccess() }
		#expect((try? Data(contentsOf: path)) == inconsistent)
		let storage = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: fixture.directory), databaseFilename: "medications"))
		let persisted = try await Store<ANMedicationConcept>(storage: storage, cacheIdentifier: \.id.uuidString)
		#expect(persisted.items.map(\.id) == [medication.id])
		#expect(persisted.items.first?.quantity == 10)
	}

	@Test("Import rollback leaves unrelated preference edits intact")
	func rollbackOnlyRestoresImportedPreferenceKeys() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		try await fixture.store.addMedication(ANMedicationConcept(clinicalName: "Current example"))
		fixture.defaults.set(false, forKey: UserDefaultsKeys.hapticsEnabled)
		var settings = AppSettings()
		settings.selectedFontFamily = "OpenDyslexic"
		let defaults = fixture.defaults
		fixture.fault.onPhase = { phase in
			if phase == .afterMedications { defaults.set(true, forKey: UserDefaultsKeys.hapticsEnabled) }
		}
		fixture.fault.phase = .afterMedications
		let data = try encode(medications: [ANMedicationConcept(clinicalName: "Imported example")], events: [], settings: settings)
		await #expect(throws: (any Error).self) { try await fixture.store.importDataFromJSON(data, applySettings: true) }
		#expect(fixture.defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled))
	}

	@Test("Saving unrelated edits cannot overwrite stock consumed while the editor was open")
	func editingDoesNotResetConcurrentDoseStock() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let baseline = ANMedicationConcept(clinicalName: "Editing example", quantity: 10.5, prescribedUnit: .tablet)
		try await fixture.store.addMedication(baseline)
		var edited = baseline
		edited.nickname = "Edited nickname"
		let event = ANEventConcept(eventType: .doseTaken, medication: baseline, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		try await fixture.store.recordDose(event)
		try await fixture.store.updateMedication(edited, original: baseline)
		#expect(fixture.store.medications.first?.quantity == 10)
		#expect(fixture.store.medications.first?.nickname == "Edited nickname")
		#expect(fixture.store.events.map(\.id) == [event.id])
	}

	@Test("A second task cannot acquire transaction ownership across an await", arguments: [false, true])
	func ownershipSurvivesSuspension(independentInstances: Bool) async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		try await fixture.store.addMedication(ANMedicationConcept(clinicalName: "Lock example", quantity: 10.5))
		let gate = LockGate()
		let observe: (PersistenceTransactionPhase) throws -> Void = { phase in
			if phase == .beforeLock { gate.noteAttempt() }
			if phase == .afterLock { gate.noteAcquired() }
		}
		let first = MedicationPersistenceTransactions(directory: fixture.directory, medicationsStore: fixture.store.medicationsStore, eventsStore: fixture.store.eventsStore, fault: observe)
		let second = independentInstances ? MedicationPersistenceTransactions(directory: fixture.directory, medicationsStore: fixture.store.medicationsStore, eventsStore: fixture.store.eventsStore, fault: observe) : first
		let owner = Task { try await first.withRecoveredStorage { await gate.hold() } }
		await gate.waitUntilHeld()
		let contender = Task { try await second.perform { $0.medications[0].quantity = 9.5 } }
		await gate.waitUntilContended()
		#expect(!gate.acquiredBeforeRelease)
		gate.release()
		try await owner.value
		try await contender.value
		#expect(try await first.read().medications.first?.quantity == 9.5)
	}

	@MainActor
	final class LockGate {
		var attempts = 0
		var acquiredBeforeRelease = false
		private var held = false
		private var released = false
		private var heldWaiter: CheckedContinuation<Void, Never>?
		private var contentionWaiter: CheckedContinuation<Void, Never>?
		private var releaseWaiter: CheckedContinuation<Void, Never>?
		func noteAttempt() {
			attempts += 1
			if attempts == 2 { contentionWaiter?.resume(); contentionWaiter = nil }
		}
		func noteAcquired() { if attempts == 2 && !released { acquiredBeforeRelease = true } }
		func hold() async {
			held = true
			heldWaiter?.resume(); heldWaiter = nil
			await withCheckedContinuation { releaseWaiter = $0 }
		}
		func waitUntilHeld() async { if !held { await withCheckedContinuation { heldWaiter = $0 } } }
		func waitUntilContended() async { if attempts < 2 { await withCheckedContinuation { contentionWaiter = $0 } } }
		func release() { released = true; releaseWaiter?.resume(); releaseWaiter = nil }
	}

	@Test("Rollback restores absence rather than persisting a registered default")
	func registeredDefaultsRemainUnpersisted() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		try await fixture.store.addMedication(ANMedicationConcept(clinicalName: "Current example"))
		let registeredDefaults = fixture.defaults.volatileDomain(forName: UserDefaults.registrationDomain)
		defer { fixture.defaults.setVolatileDomain(registeredDefaults, forName: UserDefaults.registrationDomain) }
		fixture.defaults.register(defaults: [UserDefaultsKeys.hapticsEnabled: false])
		#expect(fixture.defaults.persistentDomain(forName: fixture.suite)?[UserDefaultsKeys.hapticsEnabled] == nil)
		var settings = AppSettings()
		settings.hapticsEnabled = true
		let data = try encode(medications: [ANMedicationConcept(clinicalName: "Imported example")], events: [], settings: settings)
		fixture.fault.phase = .beforeCommit
		await #expect(throws: (any Error).self) { try await fixture.store.importDataFromJSON(data, applySettings: true) }
		#expect(fixture.defaults.persistentDomain(forName: fixture.suite)?[UserDefaultsKeys.hapticsEnabled] == nil)
		#expect(fixture.defaults.bool(forKey: UserDefaultsKeys.hapticsEnabled) == false)
	}

	@Test("Legacy-format records survive an upgrade and interrupted saves on the device filesystem")
	func legacyUpgradeAndRecoveryOnDeviceStorage() async throws {
		let fixture = try AtomicFixture()
		defer { fixture.cleanup() }
		let legacyDocuments = fixture.directory.appendingPathComponent("LegacyDocuments")
		let legacyMedicationDirectory = legacyDocuments.appendingPathComponent("medications.sqlite")
		let legacyEventDirectory = legacyDocuments.appendingPathComponent("events.sqlite")
		let medication = ANMedicationConcept(clinicalName: "Upgrade example", quantity: 10.5, prescribedUnit: .tablet)
		let originalEvent = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date(timeIntervalSince1970: 1_700_000_000), note: "Retained upgrade note")
		try await seedLegacy([medication], directory: legacyMedicationDirectory)
		try await seedLegacy([originalEvent], directory: legacyEventDirectory)
		let migration = DataMigrationManager(documentsURL: legacyDocuments, applicationSupportURL: nil, appGroupURL: fixture.directory, defaults: fixture.defaults)
		try await migration.migrateIfNeeded()
		try await migration.migrateIfNeeded()
		let upgraded = try await fixture.store.prepareForAccess()
		#expect(upgraded.medications == [medication])
		#expect(upgraded.events.map(\.id) == [originalEvent.id])
		#expect(upgraded.events.first?.note == originalEvent.note)
		#expect(upgraded.medications.first?.nextDoseNotificationEnabled == nil)
		let newEvent = ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: Date())
		fixture.fault.cancelAt = .afterMedications
		await #expect(throws: (any Error).self) { try await fixture.store.recordDose(newEvent) }
		let restarted = DataStore(storageDirectory: fixture.directory, defaults: fixture.defaults, sharedDefaults: fixture.sharedDefaults, defaultsDomainName: fixture.suite, sharedDefaultsDomainName: fixture.suite + ".shared")
		let recovered = try await restarted.prepareForAccess()
		#expect(recovered.medications == [medication])
		#expect(recovered.events.map(\.id) == [originalEvent.id])
		try await restarted.recordDose(newEvent)
		try await restarted.recordDose(newEvent)
		#expect(restarted.medications.first?.quantity == 10)
		#expect(restarted.events.count == 2)
	}

	private func seedLegacy<T: Codable & Identifiable & Sendable>(_ records: [T], directory: URL) async throws where T.ID == UUID {
		let engine = try #require(SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: "data"))
		let store = try await Store<T>(storage: engine, cacheIdentifier: \.id.uuidString)
		try await store.insert(records)
	}

	private func makeCoordinator(_ fixture: AtomicFixture, preferences: [String: PersistencePreferenceDomain]) -> MedicationPersistenceTransactions {
		MedicationPersistenceTransactions(directory: fixture.directory, medicationsStore: fixture.store.medicationsStore, eventsStore: fixture.store.eventsStore, preferences: preferences)
	}

	private func encode(medications: [ANMedicationConcept], events: [ANEventConcept], settings: AppSettings? = nil) throws -> Data {
		let export = DataExport(medications: medications, events: events, exportDate: Date(), appVersion: "1.1.2", dataVersion: "1.0", settings: settings)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		return try encoder.encode(export)
	}

	@MainActor
	final class Fault {
		var phase: PersistenceTransactionPhase?
		var phases: Set<PersistenceTransactionPhase> = []
		var cancelAt: PersistenceTransactionPhase?
		var onPhase: ((PersistenceTransactionPhase) -> Void)?
		func check(_ candidate: PersistenceTransactionPhase) throws {
			onPhase?(candidate)
			if cancelAt == candidate { cancelAt = nil; throw CancellationError() }
			if phase == candidate || phases.remove(candidate) != nil {
				phase = nil
				throw CocoaError(.fileWriteOutOfSpace)
			}
		}
	}

	@MainActor
	struct AtomicFixture {
		let directory: URL
		let defaults: UserDefaults
		let sharedDefaults: UserDefaults
		let suite: String
		let store: DataStore
		let fault: Fault

		init() throws {
			let id = UUID().uuidString
			#if targetEnvironment(simulator)
			directory = FileManager.default.temporaryDirectory.appendingPathComponent(id)
			#else
			// Hardware tests use an owned child of the real App Group, never the primary databases.
			let group = try #require(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: StorageConstants.appGroupIdentifier))
			directory = group.appendingPathComponent("StabilizationVerification-" + id)
			try #require(!FileManager.default.fileExists(atPath: directory.path))
			#endif
			suite = "AtomicPersistenceTests.\(id)"
			defaults = try #require(UserDefaults(suiteName: suite))
			sharedDefaults = try #require(UserDefaults(suiteName: suite + ".shared"))
			fault = Fault()
			let faults = fault
			store = DataStore(storageDirectory: directory, defaults: defaults, sharedDefaults: sharedDefaults, defaultsDomainName: suite, sharedDefaultsDomainName: suite + ".shared", transactionFault: { try faults.check($0) })
		}

		func cleanup() {
			try? FileManager.default.removeItem(at: directory)
			defaults.removePersistentDomain(forName: suite)
			sharedDefaults.removePersistentDomain(forName: suite + ".shared")
		}
	}
}

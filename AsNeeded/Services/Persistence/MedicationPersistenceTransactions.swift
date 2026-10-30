import ANModelKit
import Boutique
import Darwin
import Foundation

// Deterministic I/O boundaries allow regressions to exercise real SQLite writes.
enum PersistenceTransactionPhase: Hashable {
	case beforeLock
	case afterLock
	case beforeJournal
	case afterMedications
	case afterEvent(Int)
	case beforeCommit
	case beforeRollback
}

struct MedicationPersistenceSnapshot: Codable, Sendable {
	var medications: [ANMedicationConcept]
	var events: [ANEventConcept]

	mutating func recordDose(_ supplied: ANEventConcept) throws {
		guard supplied.eventType == .doseTaken, let dose = supplied.dose,
			dose.amount.isFinite, dose.amount > 0, let medicationID = supplied.medication?.id,
			let index = medications.firstIndex(where: { $0.id == medicationID }) else {
			throw PersistenceTransactionError.invalidDose
		}
		// Retrying the same saved event is a no-op, never another stock deduction.
		if let existing = events.first(where: { $0.id == supplied.id }) {
			guard existing.medication?.id == medicationID, existing.dose == dose, existing.eventType == .doseTaken else { throw PersistenceTransactionError.invalidDose }
			return
		}
		var event = supplied
		event.medication = medications[index]
		if let quantity = medications[index].quantity {
			medications[index].quantity = quantity - stockAmount(dose, medication: medications[index])
		}
		events.append(event)
	}

	mutating func deleteEvents(ids: Set<UUID>) {
		for event in events where ids.contains(event.id) {
			if event.eventType == .doseTaken, let dose = event.dose,
				let index = medications.firstIndex(where: { $0.id == event.medication?.id }),
				let quantity = medications[index].quantity {
				medications[index].quantity = quantity + stockAmount(dose, medication: medications[index])
			}
		}
		events.removeAll { ids.contains($0.id) }
	}

	mutating func updateEvent(_ updated: ANEventConcept) throws {
		guard let index = events.firstIndex(where: { $0.id == updated.id }) else { throw PersistenceTransactionError.recordUnavailable }
		let original = events[index]
		guard updated.medication?.id == original.medication?.id else { throw PersistenceTransactionError.invalidDose }
		if let dose = updated.dose, (!dose.amount.isFinite || dose.amount <= 0) { throw PersistenceTransactionError.invalidDose }
		if let medicationIndex = medications.firstIndex(where: { $0.id == original.medication?.id }),
			let quantity = medications[medicationIndex].quantity {
			let medication = medications[medicationIndex]
			let oldAmount = original.eventType == .doseTaken ? original.dose.map { stockAmount($0, medication: medication) } ?? 0 : 0
			let newAmount = updated.eventType == .doseTaken ? updated.dose.map { stockAmount($0, medication: medication) } ?? 0 : 0
			medications[medicationIndex].quantity = quantity + oldAmount - newAmount
		}
		events[index] = updated
	}

	private func stockAmount(_ dose: ANDoseConcept, medication: ANMedicationConcept) -> Double {
		// The quantity is in the medication's unit; never subtract milligrams from tablets.
		guard dose.amount.isFinite, dose.amount > 0, dose.unit == (medication.prescribedUnit ?? .unit) else { return 0 }
		return dose.amount
	}
}

enum PersistenceTransactionError: LocalizedError {
	case storageUnavailable
	case busy
	case recoveryRequired
	case invalidDose
	case recordUnavailable

	var errorDescription: String? {
		switch self {
		case .storageUnavailable: String(localized: "Medication storage is unavailable. Please try again.")
		case .busy: String(localized: "Another save is finishing. Please try again.")
		case .recoveryRequired: String(localized: "Open AsNeeded to finish recovering the previous save before making more changes.")
		case .invalidDose: String(localized: "Check the medication, dose amount, and unit, then try again.")
		case .recordUnavailable: String(localized: "This record is no longer available. Review your history.")
		}
	}
}

@MainActor
struct PersistencePreferenceDomain {
	let defaults: UserDefaults
	let keys: Set<String>
	let persistentDomainName: String
}

/// Recovery metadata only. Primary database paths and schemas do not change.
@MainActor
final class MedicationPersistenceTransactions {
	static let journalName = "pending-data-transaction.json"
	private let directory: URL
	private let medicationsStore: Store<ANMedicationConcept>
	private let eventsStore: Store<ANEventConcept>
	private let preferences: [String: PersistencePreferenceDomain]
	private let fault: (PersistenceTransactionPhase) throws -> Void
	private let didStabilize: (MedicationPersistenceSnapshot) -> Void
	// Hide partially published Boutique changes from app-owned computed views.
	private(set) var visibleSnapshot: MedicationPersistenceSnapshot?

	init(directory: URL, medicationsStore: Store<ANMedicationConcept>, eventsStore: Store<ANEventConcept>, preferences: [String: PersistencePreferenceDomain] = [:], fault: @escaping (PersistenceTransactionPhase) throws -> Void = { _ in }, didStabilize: @escaping (MedicationPersistenceSnapshot) -> Void = { _ in }) {
		self.directory = directory
		self.medicationsStore = medicationsStore
		self.eventsStore = eventsStore
		self.preferences = preferences
		self.fault = fault
		self.didStabilize = didStabilize
	}

	/// Reads a consistent snapshot while holding the same lock as writers.
	func read() async throws -> MedicationPersistenceSnapshot {
		let lock = try await acquireLock()
		defer { lock.release() }
		if let journal = try loadJournal(), !canRestorePreferences(journal) {
			// Do not combine old records with shared preferences changed by an
			// interrupted import. Only the owning app can recover those domains.
			throw PersistenceTransactionError.recoveryRequired
		}
		try await recoverUnlocked()
		let snapshot = try await loadFresh()
		visibleSnapshot = snapshot
		try await apply(snapshot)
		publishStable(snapshot)
		return snapshot
	}

	@discardableResult
	func perform(preferenceKeys: [String: Set<String>] = [:], change: (inout MedicationPersistenceSnapshot) throws -> Void, applyPreferences: (MedicationPersistenceSnapshot) -> Void = { _ in }) async throws -> Bool {
		let lock = try await acquireLock()
		defer { lock.release() }
		try await recoverUnlocked()
		let before = try await loadFresh()
		visibleSnapshot = before
		// Reconcile caches with external-process writes before calculating a mutation.
		try await apply(before)
		var after = before
		do { try change(&after) } catch { visibleSnapshot = nil; throw error }
		let journal = try makeJournal(before: before, after: after, preferenceKeys: preferenceKeys)
		if journal.medicationIDs.isEmpty && journal.eventIDs.isEmpty && journal.preferences.isEmpty {
			publishStable(before)
			return false
		}
		try fault(.beforeJournal)
		try saveJournal(journal)
		do {
			try await apply(after, injectingFaults: true)
			applyPreferences(after)
			for undo in journal.preferences {
				guard preferences[undo.domain]?.defaults.synchronize() == true else { throw PersistenceTransactionError.storageUnavailable }
			}
			try fault(.beforeCommit)
			try FileManager.default.removeItem(at: journalURL)
			flushDirectoryAfterCommit()
			publishStable(after)
			return true
		} catch is CancellationError {
			// Cancellation can mean background expiration. Leave the durable undo record
			// for the next non-cancelled reader/writer, just as after process termination.
			throw PersistenceTransactionError.recoveryRequired
		} catch {
			let originalError = error
			do {
				try fault(.beforeRollback)
				try await recoverUnlocked()
				visibleSnapshot = nil
			} catch {
				throw PersistenceTransactionError.recoveryRequired
			}
			throw originalError
		}
	}

	// Used for the existing idempotent legacy migration, which retains its sources.
	func withRecoveredStorage(_ operation: () async throws -> Void) async throws {
		let lock = try await acquireLock()
		defer { lock.release() }
		try await recoverUnlocked()
		try await operation()
		let snapshot = try await loadFresh()
		visibleSnapshot = snapshot
		try await apply(snapshot)
		publishStable(snapshot)
	}

	private func publishStable(_ snapshot: MedicationPersistenceSnapshot) {
		visibleSnapshot = nil
		didStabilize(snapshot)
	}

	private struct PreferenceUndo: Codable {
		let domain: String
		let keys: [String]
		let values: Data
	}

	private struct UndoJournal: Codable {
		let version: Int
		let medicationIDs: Set<UUID>
		let eventIDs: Set<UUID>
		let medications: [ANMedicationConcept]
		let events: [ANEventConcept]
		let medicationOrder: [UUID]
		let eventOrder: [UUID]
		let preferences: [PreferenceUndo]
	}

	private var journalURL: URL { directory.appendingPathComponent(Self.journalName) }

	private func makeJournal(before: MedicationPersistenceSnapshot, after: MedicationPersistenceSnapshot, preferenceKeys: [String: Set<String>]) throws -> UndoJournal {
		let medicationIDs = try changedIDs(before.medications, after.medications)
		let eventIDs = try changedIDs(before.events, after.events)
		let preferenceUndo = try preferenceKeys.keys.sorted().map { name -> PreferenceUndo in
			guard let domain = preferences[name], let keys = preferenceKeys[name], keys.isSubset(of: domain.keys) else { throw PersistenceTransactionError.recoveryRequired }
			// Registered fallbacks are not persisted preferences. Preserve absence exactly.
			let persisted = domain.defaults.persistentDomain(forName: domain.persistentDomainName) ?? [:]
			var values: [String: Any] = [:]
			for key in keys { if let value = persisted[key] { values[key] = value } }
			return PreferenceUndo(domain: name, keys: keys.sorted(), values: try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0))
		}
		return UndoJournal(version: 1, medicationIDs: medicationIDs, eventIDs: eventIDs, medications: before.medications.filter { medicationIDs.contains($0.id) }, events: before.events.filter { eventIDs.contains($0.id) }, medicationOrder: before.medications.map(\.id), eventOrder: before.events.map(\.id), preferences: preferenceUndo)
	}

	private func changedIDs<T: Codable & Identifiable>(_ before: [T], _ after: [T]) throws -> Set<UUID> where T.ID == UUID {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .sortedKeys
		var previous: [UUID: Data] = [:]
		for item in before { previous[item.id] = try encoder.encode(item) }
		var ids = Set(previous.keys).subtracting(after.map(\.id))
		for item in after where previous[item.id] != (try encoder.encode(item)) { ids.insert(item.id) }
		return ids
	}

	private func loadJournal() throws -> UndoJournal? {
		guard FileManager.default.fileExists(atPath: journalURL.path) else { return nil }
		do {
			let journal = try JSONDecoder().decode(UndoJournal.self, from: Data(contentsOf: journalURL))
			guard journal.version == 1,
				Set(journal.medications.map(\.id)).isSubset(of: journal.medicationIDs),
				Set(journal.events.map(\.id)).isSubset(of: journal.eventIDs),
				Set(journal.medications.map(\.id)).count == journal.medications.count,
				Set(journal.events.map(\.id)).count == journal.events.count,
				Set(journal.medicationOrder).count == journal.medicationOrder.count,
				Set(journal.eventOrder).count == journal.eventOrder.count,
				Set(journal.medications.map(\.id)) == journal.medicationIDs.intersection(journal.medicationOrder),
				Set(journal.events.map(\.id)) == journal.eventIDs.intersection(journal.eventOrder),
				Set(journal.preferences.map(\.domain)).count == journal.preferences.count else { throw PersistenceTransactionError.recoveryRequired }
			for undo in journal.preferences {
				guard ["application", "shared"].contains(undo.domain), Set(undo.keys).count == undo.keys.count,
					let values = try PropertyListSerialization.propertyList(from: undo.values, format: nil) as? [String: Any],
					Set(values.keys).isSubset(of: Set(undo.keys)) else { throw PersistenceTransactionError.recoveryRequired }
			}
			return journal
		} catch { throw PersistenceTransactionError.recoveryRequired }
	}

	private func saveJournal(_ journal: UndoJournal) throws {
		try JSONEncoder().encode(journal).write(to: journalURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
		let descriptor = open(journalURL.path, O_RDONLY)
		guard descriptor >= 0 else { throw PersistenceTransactionError.storageUnavailable }
		defer { close(descriptor) }
		guard fsync(descriptor) == 0 else { throw PersistenceTransactionError.storageUnavailable }
		let parent = open(directory.path, O_RDONLY)
		guard parent >= 0 else { throw PersistenceTransactionError.storageUnavailable }
		defer { close(parent) }
		guard fsync(parent) == 0 else { throw PersistenceTransactionError.storageUnavailable }
	}

	private func flushDirectoryAfterCommit() {
		let descriptor = open(directory.path, O_RDONLY)
		if descriptor >= 0 { _ = fsync(descriptor); close(descriptor) }
		// Process-interruption recovery is covered. Do not promise device power-loss
		// durability beyond the underlying filesystem and SQLite configuration.
	}

	private func canRestorePreferences(_ journal: UndoJournal) -> Bool {
		journal.preferences.allSatisfy { undo in
			guard let domain = preferences[undo.domain] else { return false }
			return Set(undo.keys).isSubset(of: domain.keys)
		}
	}

	private func recoverUnlocked() async throws {
		guard let journal = try loadJournal() else { return }
		guard canRestorePreferences(journal) else { throw PersistenceTransactionError.recoveryRequired }
		// Validate every preference payload before changing any records.
		let restoredPreferences = try journal.preferences.map { undo -> (PreferenceUndo, [String: Any]) in
			guard let values = try PropertyListSerialization.propertyList(from: undo.values, format: nil) as? [String: Any], Set(values.keys).isSubset(of: Set(undo.keys)) else { throw PersistenceTransactionError.recoveryRequired }
			return (undo, values)
		}
		let before = restore(journal, onto: try await loadFresh())
		visibleSnapshot = before
		try await apply(before)
		for (undo, values) in restoredPreferences {
			guard let domain = preferences[undo.domain] else { throw PersistenceTransactionError.recoveryRequired }
			for key in undo.keys {
				if let value = values[key] { domain.defaults.set(value, forKey: key) }
				else { domain.defaults.removeObject(forKey: key) }
			}
			guard domain.defaults.synchronize() else { throw PersistenceTransactionError.storageUnavailable }
		}
		try FileManager.default.removeItem(at: journalURL)
		flushDirectoryAfterCommit()
		publishStable(before)
	}

	private func restore(_ journal: UndoJournal, onto current: MedicationPersistenceSnapshot) -> MedicationPersistenceSnapshot {
		var medications = current.medications.filter { !journal.medicationIDs.contains($0.id) } + journal.medications
		var events = current.events.filter { !journal.eventIDs.contains($0.id) } + journal.events
		let medicationOrder = Dictionary(uniqueKeysWithValues: journal.medicationOrder.enumerated().map { ($0.element, $0.offset) })
		let eventOrder = Dictionary(uniqueKeysWithValues: journal.eventOrder.enumerated().map { ($0.element, $0.offset) })
		medications.sort { (medicationOrder[$0.id] ?? Int.max) < (medicationOrder[$1.id] ?? Int.max) }
		events.sort { (eventOrder[$0.id] ?? Int.max) < (eventOrder[$1.id] ?? Int.max) }
		return MedicationPersistenceSnapshot(medications: medications, events: events)
	}

	private func loadFresh() async throws -> MedicationPersistenceSnapshot {
		guard let medicationStorage = SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: "medications"),
			let eventStorage = SQLiteStorageEngine(directory: FileManager.Directory(url: directory), databaseFilename: "events") else { throw PersistenceTransactionError.storageUnavailable }
		let medications = try await Store<ANMedicationConcept>(storage: medicationStorage, cacheIdentifier: \.id.uuidString)
		let events = try await Store<ANEventConcept>(storage: eventStorage, cacheIdentifier: \.id.uuidString)
		return MedicationPersistenceSnapshot(medications: medications.items, events: events.items)
	}

	private func apply(_ snapshot: MedicationPersistenceSnapshot, injectingFaults: Bool = false) async throws {
		try await medicationsStore.itemsHaveLoaded()
		try await eventsStore.itemsHaveLoaded()
		let disk = try await loadFresh()
		let medicationIDs = Set(snapshot.medications.map(\.id))
		let knownMedications = Dictionary((medicationsStore.items + disk.medications).map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
		for item in knownMedications.values where !medicationIDs.contains(item.id) { try await medicationsStore.remove(item) }
		let changedMedications = try changedIDs(medicationsStore.items, snapshot.medications).union(changedIDs(disk.medications, snapshot.medications))
		for item in snapshot.medications where changedMedications.contains(item.id) { try await medicationsStore.insert(item) }
		if injectingFaults { try fault(.afterMedications) }
		let eventIDs = Set(snapshot.events.map(\.id))
		let knownEvents = Dictionary((eventsStore.items + disk.events).map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
		for item in knownEvents.values where !eventIDs.contains(item.id) { try await eventsStore.remove(item) }
		let changedEvents = try changedIDs(eventsStore.items, snapshot.events).union(changedIDs(disk.events, snapshot.events))
		for (index, item) in snapshot.events.enumerated() where changedEvents.contains(item.id) {
			try await eventsStore.insert(item)
			if injectingFaults { try fault(.afterEvent(index)) }
		}
	}

	private final class Lock {
		let descriptor: Int32
		init(_ descriptor: Int32) { self.descriptor = descriptor }
		func release() { _ = flock(descriptor, LOCK_UN); close(descriptor) }
	}

	private func acquireLock() async throws -> Lock {
		try fault(.beforeLock)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		// Each invocation opens its own descriptor, including reentrant tasks in
		// the same process. Never reuse one descriptor across asynchronous operations.
		let descriptor = open(directory.appendingPathComponent(".persistence.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
		guard descriptor >= 0 else { throw PersistenceTransactionError.storageUnavailable }
		for _ in 0..<500 {
			if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
				do { try fault(.afterLock); return Lock(descriptor) }
				catch { _ = flock(descriptor, LOCK_UN); close(descriptor); throw error }
			}
			guard errno == EWOULDBLOCK || errno == EAGAIN else { close(descriptor); throw PersistenceTransactionError.storageUnavailable }
			do { try await Task.sleep(for: .milliseconds(10)) } catch { close(descriptor); throw error }
		}
		close(descriptor)
		throw PersistenceTransactionError.busy
	}
}

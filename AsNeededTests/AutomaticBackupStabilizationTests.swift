@testable import AsNeeded
import Combine
import Foundation
import Testing

@Suite("Automatic backup stabilization", .tags(.unit, .backup))
@MainActor
struct AutomaticBackupStabilizationTests {
	@Test("Dismissing privacy setup restores the enable action")
	func dismissPrivacySetup() {
		let model = AutomaticBackupViewModel()
		model.enableAutomaticBackup()
		#expect(model.isBusy)
		model.showingPrivacyOnboarding = false
		model.privacyOnboardingDismissed()
		#expect(!model.isBusy)
		#expect(!model.showingLocationPicker)
	}

	@Test("Location selection waits until the privacy sheet has dismissed")
	func privacyToLocationHandoff() {
		let model = AutomaticBackupViewModel()
		model.enableAutomaticBackup()
		model.proceedWithLocationSelection()
		#expect(!model.showingPrivacyOnboarding)
		#expect(!model.showingLocationPicker)
		#expect(model.isBusy)
		model.privacyOnboardingDismissed()
		#expect(model.showingLocationPicker)
		#expect(model.isBusy)
	}

	@Test("Cancelling the location picker restores the enable action without a completion callback")
	func dismissLocationPicker() {
		let model = AutomaticBackupViewModel()
		model.enableAutomaticBackup()
		model.proceedWithLocationSelection()
		model.privacyOnboardingDismissed()
		model.showingLocationPicker = false
		model.locationPickerDismissed()
		#expect(!model.isBusy)
	}

	@Test("Picker dismissal keeps a claimed folder busy until saving finishes")
	func claimedFolderStaysBusy() {
		let model = AutomaticBackupViewModel()
		model.enableAutomaticBackup()
		model.beginSavingLocation()
		model.locationPickerDismissed()
		#expect(!model.isSettingUp)
		#expect(model.isSavingLocation)
		#expect(model.isBusy)
	}

	@Test("A manual backup stays visible and rejects overlapping manual and debounced runs")
	func manualRunRejectsOverlap() async throws {
		let fixture = try BackupFixture()
		defer { fixture.removeDefaults() }
		let gate = BackupGate()
		var runs = 0
		let manager = AutomaticBackupManager(defaults: fixture.defaults, debounceSleep: {}, backupOperation: {
			runs += 1
			await gate.wait()
			return .success
		})
		let model = AutomaticBackupViewModel(manager: manager)
		var changes = 0
		let subscription = model.objectWillChange.sink { changes += 1 }
		defer { subscription.cancel() }

		let first = Task { await manager.performManualBackup() }
		await gate.waitUntilEntered()
		#expect(model.isBackupInProgress)
		#expect(changes > 0)
		let changesWhileRunning = changes
		_ = await manager.performManualBackup()
		let debounced = try #require(manager.triggerBackup())
		await debounced.value
		#expect(runs == 1)
		#expect(model.isBackupInProgress)

		gate.open()
		#expect(await first.value == .success)
		#expect(runs == 2)
		#expect(!model.isBackupInProgress)
		#expect(changes > changesWhileRunning)
	}

	@Test("A debounced backup rejects manual overlap and allows the next completed run")
	func debouncedRunRejectsOverlap() async throws {
		let fixture = try BackupFixture()
		defer { fixture.removeDefaults() }
		let gate = BackupGate()
		var runs = 0
		let manager = AutomaticBackupManager(defaults: fixture.defaults, debounceSleep: {}, backupOperation: {
			runs += 1
			await gate.wait()
			return .success
		})
		let debounced = try #require(manager.triggerBackup())
		await gate.waitUntilEntered()
		#expect(manager.isBackupInProgress)
		_ = await manager.performManualBackup()
		#expect(runs == 1)
		#expect(manager.isBackupInProgress)
		gate.open()
		await debounced.value
		#expect(!manager.isBackupInProgress)
		#expect(await manager.performManualBackup() == .success)
		#expect(runs == 2)
	}
	@Test("Changes during a suspended provider write coalesce into one fresh backup")
	func changesDuringProviderWriteRunAgain() async throws {
		let fixture = try BackupFixture()
		defer { fixture.removeDefaults() }
		let providerGate = BackupGate()
		var currentRevision = 0
		var exportedRevisions: [Int] = []
		let manager = AutomaticBackupManager(defaults: fixture.defaults, debounceSleep: {}, backupOperation: {
			exportedRevisions.append(currentRevision)
			await providerGate.wait()
			return .success
		})
		let first = try #require(manager.triggerBackup())
		await providerGate.waitUntilEntered()
		currentRevision = 1
		let second = try #require(manager.triggerBackup())
		await second.value
		currentRevision = 2
		let third = try #require(manager.triggerBackup())
		await third.value
		#expect(exportedRevisions == [0])
		#expect(manager.isBackupInProgress)
		#expect(!first.isCancelled)
		providerGate.open()
		await first.value
		#expect(exportedRevisions == [0, 2])
		#expect(!manager.isBackupInProgress)
	}

	@Test("A folder cannot replace the active backup location or claim a previous success")
	func locationChangeDuringBackupIsRejected() async throws {
		let fixture = try BackupFixture()
		defer { fixture.removeDefaults() }
		let providerGate = BackupGate()
		let originalBookmark = Data("original-location".utf8)
		var preparations = 0
		let manager = AutomaticBackupManager(defaults: fixture.defaults, backupOperation: {
			await providerGate.wait()
			return .success
		})
		manager.saveBackupLocation(bookmark: originalBookmark)
		manager.lastBackupStatus = .success
		let model = AutomaticBackupViewModel(manager: manager, prepareBookmark: { _ in
			preparations += 1
			return Data("replacement-location".utf8)
		})
		let first = Task { await manager.performManualBackup() }
		await providerGate.waitUntilEntered()
		model.changeBackupLocation()
		#expect(!model.showingLocationPicker)
		await model.saveBackupLocation(url: URL(fileURLWithPath: "/synthetic-backup-location"))
		#expect(preparations == 0)
		#expect(!model.showingSuccess)
		#expect(model.showingAlert)
		#expect(!model.isSavingLocation)
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) == originalBookmark)
		providerGate.open()
		_ = await first.value
	}

	@Test("Folder preparation revalidates a backup that starts while the provider is suspended")
	func locationChangeRevalidatesAfterPreparation() async throws {
		let fixture = try BackupFixture()
		defer { fixture.removeDefaults() }
		let preparationGate = BackupGate()
		let providerGate = BackupGate()
		let originalBookmark = Data("original-location".utf8)
		let manager = AutomaticBackupManager(defaults: fixture.defaults, backupOperation: {
			await providerGate.wait()
			return .success
		})
		manager.saveBackupLocation(bookmark: originalBookmark)
		manager.lastBackupStatus = .success
		let model = AutomaticBackupViewModel(manager: manager, prepareBookmark: { _ in
			await preparationGate.wait()
			return Data("replacement-location".utf8)
		})
		let saving = Task { await model.saveBackupLocation(url: URL(fileURLWithPath: "/synthetic-backup-location")) }
		await preparationGate.waitUntilEntered()
		let first = Task { await manager.performManualBackup() }
		await providerGate.waitUntilEntered()
		preparationGate.open()
		await saving.value
		#expect(!model.showingSuccess)
		#expect(model.showingAlert)
		#expect(fixture.defaults.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark) == originalBookmark)
		providerGate.open()
		_ = await first.value
	}

	@Test("Disabling during a provider operation discards its obsolete success")
	func disabledBackupDoesNotPublishSuccess() async throws {
		let fixture = try BackupFixture()
		defer { fixture.removeDefaults() }
		let providerGate = BackupGate()
		var runs = 0
		let manager = AutomaticBackupManager(defaults: fixture.defaults, debounceSleep: {}, backupOperation: {
			runs += 1
			await providerGate.wait()
			return .success
		})
		let first = Task { await manager.performManualBackup() }
		await providerGate.waitUntilEntered()
		let pending = try #require(manager.triggerBackup())
		await pending.value
		manager.disable()
		providerGate.open()
		_ = await first.value
		#expect(runs == 1)
		#expect(manager.lastBackupStatus == .none)
		#expect(manager.lastBackupDate == nil)
		#expect(!manager.isBackupInProgress)
		#expect(fixture.defaults.object(forKey: UserDefaultsKeys.automaticBackupLastBackupDate) == nil)
	}
	@Test("Validation retry writes the same captured privacy-filtered payload")
	func validationRetryPreservesPayload() throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let url = directory.appendingPathComponent("backup.json")
		let payload = Data(#"{"medications":[{"name":"Medication 1"}],"events":[{"note":""}]}"#.utf8)
		var attempts: [Data] = []

		try AutomaticBackupManager.writeAndValidateBackup(payload, to: url) { candidate in
			if let written = try? Data(contentsOf: candidate) {
				attempts.append(written)
			}
			return attempts.count == 2
		}

		#expect(attempts == [payload, payload])
		#expect(try Data(contentsOf: url) == payload)
	}

	@Test("Two failed validations remove invalid output and report validation failure")
	func repeatedValidationFailureRemovesOutput() throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let url = directory.appendingPathComponent("backup.json")
		let payload = Data("synthetic redacted payload".utf8)
		var attempts: [Data] = []

		do {
			try AutomaticBackupManager.writeAndValidateBackup(payload, to: url) { candidate in
				if let written = try? Data(contentsOf: candidate) {
					attempts.append(written)
				}
				return false
			}
			Issue.record("Expected invalid backup validation to fail")
		} catch BackupError.validationFailed {
			// Expected failure after the one permitted retry.
		}

		#expect(attempts == [payload, payload])
		#expect(!FileManager.default.fileExists(atPath: url.path))
	}
}

// MARK: - Deterministic Helpers
@MainActor
private struct BackupFixture {
	let suiteName: String
	let defaults: UserDefaults

	init() throws {
		suiteName = "AutomaticBackupStabilizationTests.\(UUID().uuidString)"
		defaults = try #require(UserDefaults(suiteName: suiteName))
		defaults.set(true, forKey: UserDefaultsKeys.automaticBackupEnabled)
	}

	func removeDefaults() {
		defaults.removePersistentDomain(forName: suiteName)
	}
}

@MainActor
private final class BackupGate {
	private var isOpen = false
	private var hasEntered = false
	private var waiter: CheckedContinuation<Void, Never>?
	private var entryWaiter: CheckedContinuation<Void, Never>?

	func wait() async {
		hasEntered = true
		entryWaiter?.resume()
		entryWaiter = nil
		guard !isOpen else { return }
		await withCheckedContinuation { waiter = $0 }
	}

	func waitUntilEntered() async {
		guard !hasEntered else { return }
		await withCheckedContinuation { entryWaiter = $0 }
	}

	func open() {
		isOpen = true
		waiter?.resume()
		waiter = nil
	}
}

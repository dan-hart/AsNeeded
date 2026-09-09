# Per-Medication Notification Urgency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a durable per-medication control that schedules normal or Time Sensitive reminders while safely migrating existing reminders to urgent delivery.

**Architecture:** A focused UserDefaults-backed store owns explicit urgency preferences and a one-time migration marker. `NotificationManager` remains the serialized coordinator for request scheduling, startup reconciliation, and transactional urgency changes; `MedicationReminderRequest` remains the pure request/identity helper. `MedicationDetailView` exposes the preference and iOS Time Sensitive availability without adding notification state to ANModelKit.

**Tech Stack:** Swift 6, SwiftUI, UserNotifications, UserDefaults, Boutique-backed app persistence, Swift Testing, Xcode/iOS Simulator.

---

## File Structure

**Create**

- `AsNeeded/Services/MedicationNotificationUrgencyStore.swift` — read, write, verify, migrate, filter, and remove per-medication urgency preferences.
- `AsNeededTests/MedicationNotificationUrgencyStoreTests.swift` — isolated UserDefaults coverage for explicit values, corruption safety, filtering, deletion, and migration marker behavior.

**Modify**

- `AsNeeded/Constants/UserDefaultsKeys.swift` — register the preference payload and device-local migration marker in reset/export classifications.
- `AsNeeded/Services/MedicationReminderRequest.swift` — make interruption level explicit and reconcile toward a per-medication desired level.
- `AsNeeded/Services/NotificationManager.swift` — readiness-gated startup, migration, serialized scheduling, urgency updates with rollback, and Time Sensitive system status.
- `AsNeeded/AsNeededApp.swift` — start reconciliation from the app root only after storage migration completes.
- `AsNeeded/Models/AppSettings.swift` — export/import valid urgency preferences without exporting the migration marker.
- `AsNeeded/Services/Persistence/DataStore.swift` — inject the urgency store, clean deleted medication preferences, and include the payload in import rollback/reset behavior.
- `AsNeeded/Medication/MedicationDetailView.swift` — show and update the medication-specific toggle and system-status explanation.
- `AsNeededTests/MedicationReminderRequestTests.swift` — active/Time Sensitive request and reconciliation coverage.
- `AsNeededTests/NotificationManagerTests.swift` — startup, migration, scheduling, rollback, serialization, and system-setting mapping coverage.
- `AsNeededTests/SettingsExportImportTests.swift` — valid-ID filtering and migration-marker exclusion.
- `AsNeededTests/DataStoreTests.swift` — deletion cleanup and UserDefaults registry classification.
- `AsNeededTests/DataStoreClearTests.swift` — ordinary reset removes preferences while preserving the migration marker.

Xcode uses file-system-synchronized groups, so the new Swift files do not require manual `project.pbxproj` entries.

## Common Verification Command

Use direct, unpiped `xcodebuild` so wrapper output cannot hide the real exit status:

```bash
xcodebuild test \
	-project AsNeeded.xcodeproj \
	-scheme AsNeeded \
	-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
	-parallel-testing-enabled NO \
	-only-testing:AsNeededTests/SUITE_NAME
```

Replace `SUITE_NAME` with the suite named in each task.

### Task 1: Add the urgency preference store and key classifications

**Files:**

- Create: `AsNeeded/Services/MedicationNotificationUrgencyStore.swift`
- Create: `AsNeededTests/MedicationNotificationUrgencyStoreTests.swift`
- Modify: `AsNeeded/Constants/UserDefaultsKeys.swift:59-63,177-380`
- Modify: `AsNeededTests/DataStoreTests.swift:302-355`

- [ ] **Step 1: Write the failing store tests**

Create a serialized suite using a unique UserDefaults domain:

```swift
@MainActor
@Suite("Medication Notification Urgency Store Tests", .serialized, .tags(.service, .notifications, .unit))
struct MedicationNotificationUrgencyStoreTests {
	private func makeStore() -> (MedicationNotificationUrgencyStore, UserDefaults, String) {
		let suite = "MedicationNotificationUrgencyStoreTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite) ?? .standard
		defaults.removePersistentDomain(forName: suite)
		return (MedicationNotificationUrgencyStore(defaults: defaults), defaults, suite)
	}

	@Test("Missing preference resolves to normal without becoming explicit")
	func missingPreferenceResolvesToNormal() {
		let (store, defaults, suite) = makeStore()
		defer { defaults.removePersistentDomain(forName: suite) }
		let medicationID = UUID()

		#expect(store.preference(for: medicationID) == nil)
		#expect(!store.isUrgent(for: medicationID))
	}

	@Test("Explicit false remains distinct from missing")
	func explicitFalseRemainsDistinct() {
		let (store, defaults, suite) = makeStore()
		defer { defaults.removePersistentDomain(forName: suite) }
		let medicationID = UUID()

		#expect(store.save(false, for: medicationID))
		#expect(store.preference(for: medicationID) == false)
	}

	@Test("Filtering removes unknown medication IDs")
	func filteringRemovesUnknownIDs() {
		let valid = UUID()
		let unknown = UUID()
		let filtered = MedicationNotificationUrgencyStore.filteredPreferences(
			[valid.uuidString: true, unknown.uuidString: false, "invalid": true],
			validMedicationIDs: [valid.uuidString]
		)

		#expect(filtered == [valid.uuidString: true])
	}
}
```

Also cover:

- `true` and `false` persistence across a recreated store.
- Isolation between two medication IDs.
- Removal preserves other IDs.
- Complete replacement preserves explicit `false`.
- Invalid stored Data makes writes fail instead of overwriting the payload.
- The migration marker is absent initially, can be verified after marking, and is independent of the preference payload.

- [ ] **Step 2: Add failing key-registry expectations**

Extend `DataStoreTests.userDefaultsKeysComprehensive`:

```swift
#expect(allKeys.contains(UserDefaultsKeys.medicationNotificationUrgency))
#expect(allKeys.contains(UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted))
#expect(UserDefaultsKeys.keysToRemove.contains(UserDefaultsKeys.medicationNotificationUrgency))
#expect(UserDefaultsKeys.keysToSkip.contains(UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted))
#expect(UserDefaultsKeys.safeToExportKeys.contains(UserDefaultsKeys.medicationNotificationUrgency))
#expect(UserDefaultsKeys.keysToNeverExport.contains(UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted))
```

- [ ] **Step 3: Run the suites and verify RED**

Run:

```bash
xcodebuild test \
	-project AsNeeded.xcodeproj \
	-scheme AsNeeded \
	-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
	-parallel-testing-enabled NO \
	-only-testing:AsNeededTests/MedicationNotificationUrgencyStoreTests \
	-only-testing:AsNeededTests/DataStoreTests
```

Expected: compilation fails because the store and keys do not exist.

- [ ] **Step 4: Implement the minimal verified store**

Use JSON `Data` so explicit Boolean values round-trip without property-list bridging ambiguity:

```swift
import Foundation

@MainActor
final class MedicationNotificationUrgencyStore {
	static let shared = MedicationNotificationUrgencyStore()

	private let defaults: UserDefaults
	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func preference(for medicationID: UUID) -> Bool? {
		decodedPreferences()?[medicationID.uuidString]
	}

	func isUrgent(for medicationID: UUID) -> Bool {
		preference(for: medicationID) ?? false
	}

	@discardableResult
	func save(_ isUrgent: Bool, for medicationID: UUID) -> Bool {
		guard var values = decodedPreferences() else { return false }
		values[medicationID.uuidString] = isUrgent
		return persist(values)
	}

	@discardableResult
	func removePreference(for medicationID: UUID) -> Bool {
		guard var values = decodedPreferences() else { return false }
		values.removeValue(forKey: medicationID.uuidString)
		return persist(values)
	}

	func allPreferences() -> [String: Bool]? {
		decodedPreferences()
	}

	@discardableResult
	func replaceAll(with values: [String: Bool]) -> Bool {
		guard decodedPreferences() != nil else { return false }
		return persist(values)
	}

	var migrationCompleted: Bool {
		defaults.bool(forKey: UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted)
	}

	@discardableResult
	func markMigrationCompleted() -> Bool {
		defaults.set(true, forKey: UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted)
		return defaults.bool(forKey: UserDefaultsKeys.medicationNotificationUrgencyMigrationCompleted)
	}
}
```

Implement private decode/persist helpers so:

- Missing payload decodes as an empty dictionary.
- Present but invalid Data returns failure.
- Empty dictionaries remove the payload key and verify it is absent.
- Non-empty dictionaries are encoded, written, decoded, and compared before returning success.
- `filteredPreferences(_:validMedicationIDs:)` retains only valid UUID-string keys in the supplied ID set.

Add:

```swift
static let medicationNotificationUrgency = "medicationNotificationUrgency"
static let medicationNotificationUrgencyMigrationCompleted = "migration.medicationNotificationUrgencyCompleted"
```

Classify the preference key in `allKeys`, `keysToRemove`, and `safeToExportKeys`. Classify the marker in `allKeys`, `keysToSkip`, and `keysToNeverExport`.

- [ ] **Step 5: Run the suites and verify GREEN**

Run the Step 3 command.

Expected: both selected suites pass.

- [ ] **Step 6: Commit**

```bash
git add AsNeeded/Services/MedicationNotificationUrgencyStore.swift \
	AsNeeded/Constants/UserDefaultsKeys.swift \
	AsNeededTests/MedicationNotificationUrgencyStoreTests.swift \
	AsNeededTests/DataStoreTests.swift
git commit -m "Add medication notification urgency preferences"
```

### Task 2: Make request interruption level explicit

**Files:**

- Modify: `AsNeeded/Services/MedicationReminderRequest.swift:39-130,201-207`
- Modify: `AsNeededTests/MedicationReminderRequestTests.swift:15-289`

- [ ] **Step 1: Replace the global-urgency assertion with explicit-level tests**

```swift
@Test("Urgent request is time sensitive")
func urgentRequestIsTimeSensitive() {
	let request = makeRequest(isUrgent: true)
	#expect(request.content.interruptionLevel == .timeSensitive)
}

@Test("Normal request is active")
func normalRequestIsActive() {
	let request = makeRequest(isUrgent: false)
	#expect(request.content.interruptionLevel == .active)
}

@Test("Urgency does not change request identity or trigger")
func urgencyDoesNotChangeIdentityOrTrigger() {
	let medication = makeMedication()
	let urgent = makeRequest(for: medication, isUrgent: true)
	let normal = makeRequest(for: medication, isUrgent: false)

	#expect(urgent.identifier == normal.identifier)
	#expect((urgent.trigger as? UNCalendarNotificationTrigger)?.dateComponents ==
		(normal.trigger as? UNCalendarNotificationTrigger)?.dateComponents)
}
```

Update request helpers to accept `isUrgent`. Add reconciliation tests that pass `[medication.id: false]` and expect `.active`, plus `[medication.id: true]` and expect `.timeSensitive`. Add a test proving requests for medication IDs absent from the desired-level map are ignored.

- [ ] **Step 2: Run the request suite and verify RED**

Run:

```bash
xcodebuild test \
	-project AsNeeded.xcodeproj \
	-scheme AsNeeded \
	-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
	-parallel-testing-enabled NO \
	-only-testing:AsNeededTests/MedicationReminderRequestTests
```

Expected: compilation fails because `make` and `reconciliationPlans` do not accept urgency inputs.

- [ ] **Step 3: Implement explicit request and reconciliation levels**

Change request construction to require `isUrgent`:

```swift
content.interruptionLevel = isUrgent ? .timeSensitive : .active
```

Change reconciliation to:

```swift
static func reconciliationPlans(
	in requests: [UNNotificationRequest],
	urgencyByMedicationID: [UUID: Bool]
) -> [ReconciliationPlan]
```

For each identity:

- Skip it when its medication ID is absent from the map.
- Canonicalize toward `.timeSensitive` for `true` and `.active` for `false`.
- Compare the source against the desired level rather than hard-coding `.timeSensitive`.
- Preserve trigger normalization, stable identifiers, content, and add-before-remove behavior.

Add a pure helper used later by the manager:

```swift
static func updatingUrgency(
	of request: UNNotificationRequest,
	isUrgent: Bool
) -> UNNotificationRequest? {
	guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
		return nil
	}
	content.interruptionLevel = isUrgent ? .timeSensitive : .active
	return UNNotificationRequest(
		identifier: request.identifier,
		content: content,
		trigger: request.trigger
	)
}
```

- [ ] **Step 4: Run the request suite and verify GREEN**

Run the Step 2 command.

Expected: the full request suite passes with active and Time Sensitive coverage.

- [ ] **Step 5: Commit**

```bash
git add AsNeeded/Services/MedicationReminderRequest.swift \
	AsNeededTests/MedicationReminderRequestTests.swift
git commit -m "Support normal and urgent reminder requests"
```

### Task 3: Add readiness-gated startup migration and normal-by-default scheduling

**Files:**

- Modify: `AsNeeded/Services/NotificationManager.swift:38-215`
- Modify: `AsNeeded/AsNeededApp.swift:24-33,44-62`
- Modify: `AsNeededTests/NotificationManagerTests.swift:125-442,769-901`

- [ ] **Step 1: Write failing scheduling and migration tests**

Use isolated `MedicationNotificationUrgencyStore` instances and the existing fake notification client. Cover:

```swift
@Test("First schedule persists normal and creates an active request")
func firstSchedulePersistsNormal() async throws

@Test("Stored urgent preference creates a time sensitive request")
func storedUrgentPreferenceSchedulesTimeSensitive() async throws

@Test("Startup waits for inventory readiness")
func startupWaitsForInventoryReadiness() async

@Test("Provider failure leaves migration incomplete and does not reconcile")
func providerFailureLeavesMigrationIncomplete() async

@Test("Authoritative empty inventory completes migration without touching requests")
func emptyInventoryCompletesMigration() async

@Test("Existing current-medication reminder migrates to urgent once")
func existingReminderMigratesToUrgentOnce() async

@Test("Explicit false survives startup reconciliation")
func explicitFalseSurvivesStartup() async

@Test("Stale medication reminder is excluded from migration and reconciliation")
func staleReminderIsIgnored() async

@Test("Concurrent startup calls share one in-flight pass")
func concurrentStartupCallsAreIdempotent() async
```

Use `TestAsyncGate` for the readiness test. Extend the fake store or store initializer only where failure injection is necessary; do not use global defaults.

- [ ] **Step 2: Run the manager suite and verify RED**

Run:

```bash
xcodebuild test \
	-project AsNeeded.xcodeproj \
	-scheme AsNeeded \
	-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
	-parallel-testing-enabled NO \
	-only-testing:AsNeededTests/NotificationManagerTests
```

Expected: compilation fails because the manager has no urgency-store dependency or readiness-gated startup API.

- [ ] **Step 3: Inject the store and remove init-time reconciliation**

Change the shared manager to construct without `startsAutomatically`. Inject:

```swift
private let urgencyStore: MedicationNotificationUrgencyStore
private var startupTask: Task<Bool, Never>?
private var startupCompleted = false
```

The initializer accepts the store with `.shared` as the live default and no longer accepts `startsAutomatically` or `scheduleStartup`.

- [ ] **Step 4: Implement idempotent startup**

Add:

```swift
func start(
	currentMedicationIDs: @escaping @MainActor () async throws -> Set<UUID>
) async
```

Behavior:

- Return immediately after a successful completed startup.
- Await the existing in-flight task when another caller starts concurrently.
- Run authorization/category setup once per successful startup attempt.
- Await the inventory provider before reading pending medication reminders.
- On provider failure, log and clear the in-flight task without setting `startupCompleted` or the migration marker.
- On success, call the serialized migration/reconciliation operation.

Inside migration/reconciliation:

1. Fetch pending requests.
2. Load the store dictionary; abort safely if it is corrupt.
3. If the marker is absent, set `true` only for current medication IDs that have pending medication reminders and no explicit value.
4. Persist the dictionary, then mark migration complete.
5. If dictionary persistence fails, use urgent for those legacy IDs during this pass but leave the marker unset.
6. Build an urgency map containing every current medication ID, resolving missing values to `false`.
7. Apply `MedicationReminderRequest.reconciliationPlans`.

- [ ] **Step 5: Wire startup from the persistence-ready app root**

Remove the forced reconciliation from `AsNeededApp.init()`. In the `migrationCoordinator.isComplete` app-root branch, add:

```swift
.task {
	await NotificationManager.shared.start {
		Set(DataStore.shared.medications.map(\.id))
	}
}
```

This wiring must land in the same commit as the manager startup change so no intermediate commit disables authorization refresh, category setup, migration, or reconciliation.

- [ ] **Step 6: Make first scheduling establish explicit normal**

Within the mutation queue:

- Read the optional preference.
- If absent, save `false` and throw a typed manager error if verification fails.
- Construct the request with the resolved value.
- Add the canonical request before removing matching legacy identifiers.

This prevents a newly scheduled normal reminder from being mistaken for a legacy reminder.

- [ ] **Step 7: Run the manager and request suites**

Run:

```bash
xcodebuild test \
	-project AsNeeded.xcodeproj \
	-scheme AsNeeded \
	-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
	-parallel-testing-enabled NO \
	-only-testing:AsNeededTests/NotificationManagerTests \
	-only-testing:AsNeededTests/MedicationReminderRequestTests
```

Expected: all selected tests pass.

- [ ] **Step 8: Commit**

```bash
git add AsNeeded/Services/NotificationManager.swift \
	AsNeeded/AsNeededApp.swift \
	AsNeededTests/NotificationManagerTests.swift
git commit -m "Migrate medication urgency after storage is ready"
```

### Task 4: Add transactional urgency changes and Time Sensitive system status

**Files:**

- Modify: `AsNeeded/Services/NotificationManager.swift:51-169,201-215`
- Modify: `AsNeededTests/NotificationManagerTests.swift`

- [ ] **Step 1: Write failing urgency-update tests**

Add deterministic tests for:

- All pending requests for the selected medication change level.
- Other medications remain untouched.
- A medication with no pending reminders still persists its preference.
- Preference persistence happens only after replacements succeed.
- An add failure re-adds originals and retains the old preference.
- A persistence failure re-adds originals.
- Rollback failure is logged/contained and the old stored preference remains authoritative.
- A queued urgency change cannot race with scheduling or cancellation.

Extend `FakeMedicationNotificationClient` to support failure by add-call index rather than only a single global error:

```swift
var addErrorsByCall: [Int: any Error] = [:]
private var addCallCount = 0
```

- [ ] **Step 2: Write failing Time Sensitive mapping tests**

```swift
@Test(arguments: [
	(UNNotificationSetting.enabled, NotificationManager.TimeSensitiveStatus.enabled),
	(.disabled, .disabled),
	(.notSupported, .notSupported),
])
func mapsTimeSensitiveStatus(
	setting: UNNotificationSetting,
	expected: NotificationManager.TimeSensitiveStatus
) {
	#expect(NotificationManager.timeSensitiveStatus(for: setting) == expected)
}
```

- [ ] **Step 3: Run the manager suite and verify RED**

Run the Task 3 Step 2 command.

Expected: missing update API/status enum failures.

- [ ] **Step 4: Implement the transactional update**

Add:

```swift
func setUrgent(_ isUrgent: Bool, for medicationID: UUID) async throws
func isUrgent(for medicationID: UUID) -> Bool
```

`setUrgent` runs inside `enqueueReminderMutation`:

1. Snapshot matching pending requests.
2. Build replacements with `MedicationReminderRequest.updatingUrgency`.
3. Add replacements sequentially.
4. Save and verify the preference after every add succeeds.
5. On any error, re-add the original requests that may have changed.
6. Throw the original typed error so the UI can revert.

Use category/userInfo medication matching, not substring-only identifiers, for this new flow.

- [ ] **Step 5: Publish system status**

Add:

```swift
enum TimeSensitiveStatus: Equatable {
	case enabled
	case disabled
	case notSupported
	case unknown
}

@Published private(set) var timeSensitiveStatus: TimeSensitiveStatus = .unknown
```

Update `checkAuthorizationStatus()` from the same `UNNotificationSettings` snapshot and provide a pure static mapper for tests. Do not claim enabled when the setting is unknown.

- [ ] **Step 6: Run the manager suite and verify GREEN**

Run the Task 3 Step 2 command.

Expected: the full manager suite passes, including rollback and serialization tests.

- [ ] **Step 7: Commit**

```bash
git add AsNeeded/Services/NotificationManager.swift \
	AsNeededTests/NotificationManagerTests.swift
git commit -m "Update medication urgency transactionally"
```

### Task 5: Integrate deletion, reset, and settings portability

**Files:**

- Modify: `AsNeeded/Models/AppSettings.swift:6-12,14-423`
- Modify: `AsNeeded/Services/Persistence/DataStore.swift:26-48,131-230,356-370,517-579,609-668`
- Modify: `AsNeededTests/SettingsExportImportTests.swift`
- Modify: `AsNeededTests/DataStoreTests.swift:80-170`
- Modify: `AsNeededTests/DataStoreClearTests.swift:18-99`

- [ ] **Step 1: Write failing deletion and reset tests**

Add a DataStore test with isolated defaults/store:

```swift
@Test("Deleting medication removes only its urgency preference")
func deletingMedicationRemovesOnlyItsUrgencyPreference() async throws
```

Add reset coverage:

```swift
@Test("resetAppSettings clears urgency preferences and preserves migration marker")
func resetClearsUrgencyButPreservesMigrationMarker() throws
```

- [ ] **Step 2: Write failing export/import tests**

Cover:

- Export includes explicit `true` and `false` preferences.
- Exported JSON does not contain the migration-marker key.
- Import retains valid medication IDs and drops unknown/malformed IDs.
- A verified persistence failure throws `AppSettingsError.notificationUrgencyPersistenceFailed`.
- DataStore import rollback restores the raw preference payload after a later import failure.

- [ ] **Step 3: Run focused data suites and verify RED**

Run:

```bash
xcodebuild test \
	-project AsNeeded.xcodeproj \
	-scheme AsNeeded \
	-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
	-parallel-testing-enabled NO \
	-only-testing:AsNeededTests/SettingsExportImportTests \
	-only-testing:AsNeededTests/DataStoreTests \
	-only-testing:AsNeededTests/DataStoreClearTests
```

Expected: compilation/test failures for missing AppSettings and DataStore integration.

- [ ] **Step 4: Extend AppSettings**

Add:

```swift
var medicationNotificationUrgency: [String: Bool]?
```

Include it in `CodingKeys`, manual decode/encode, `settingsCategories`, and `appliedDefaultsKeys`. Populate exports specifically in `@MainActor init(from defaults: UserDefaults)` by reading `MedicationNotificationUrgencyStore(defaults: defaults).allPreferences()`.

Keep Codable's `init(from decoder:)` and `encode(to:)` nonisolated. Explicitly isolate the synchronous settings APIs that access the `@MainActor` store:

```swift
@MainActor
init(from defaults: UserDefaults = .standard)

@MainActor
func apply(
	to defaults: UserDefaults = .standard,
	validateMedicationIDs: () -> Set<String>,
	profileStore: MedicationRefillProfileStore? = nil,
	urgencyStore: MedicationNotificationUrgencyStore? = nil
) throws
```

Mark any extracted urgency-persistence helper `@MainActor` as well. During apply:

- Filter through `MedicationNotificationUrgencyStore.filteredPreferences`.
- Persist with an injected urgency store.
- Throw `notificationUrgencyPersistenceFailed` when verification fails.
- Never read or write the migration marker.

- [ ] **Step 5: Inject lifecycle cleanup into DataStore**

Add an urgency-store dependency alongside `MedicationRefillProfileStore` in live and test initializers. Then:

- Remove the deleted medication's preference after medication persistence succeeds.
- Log cleanup failure without restoring the deleted medication.
- Pass the store to `AppSettings.apply`.
- Rely on `AppSettings.appliedDefaultsKeys` to include the raw urgency payload in the existing import snapshot/rollback.
- Let `keysToRemove` clear preferences during reset while `keysToSkip` preserves the marker.

- [ ] **Step 6: Run data suites and verify GREEN**

Run the Step 3 command.

Expected: all selected data/settings suites pass.

- [ ] **Step 7: Commit**

```bash
git add AsNeeded/Models/AppSettings.swift \
	AsNeeded/Services/Persistence/DataStore.swift \
	AsNeededTests/SettingsExportImportTests.swift \
	AsNeededTests/DataStoreTests.swift \
	AsNeededTests/DataStoreClearTests.swift
git commit -m "Persist notification urgency through app data flows"
```

### Task 6: Add the medication-detail urgency toggle

**Files:**

- Modify: `AsNeeded/Medication/MedicationDetailView.swift:9-188,576-659`

- [ ] **Step 1: Add view state and loading**

Add medication-detail state:

```swift
@Environment(\.scenePhase) private var scenePhase
@State private var urgentNotificationsEnabled = false
@State private var isUpdatingNotificationUrgency = false
@State private var notificationUrgencyError: String?
```

Load urgency alongside reminder count:

```swift
urgentNotificationsEnabled = notificationManager.isUrgent(for: medication.id)
```

Treat `.authorized`, `.provisional`, and `.ephemeral` as usable authorization states. Keep `.notDetermined` on the existing permission-request path.

- [ ] **Step 2: Add the toggle and status copy**

Place the toggle at the top of the authorized reminders controls:

```swift
Toggle(isOn: Binding(
	get: { urgentNotificationsEnabled },
	set: { requestedValue in
		Task {
			await updateNotificationUrgency(to: requestedValue)
		}
	}
)) {
	VStack(alignment: .leading, spacing: 4) {
		Text("Urgent Notifications")
			.font(.customFont(fontFamily, style: .body, weight: .medium))
		Text("Can notify you through Focus and Scheduled Summary.")
			.font(.customFont(fontFamily, style: .caption))
			.foregroundStyle(.secondary)
	}
}
.tint(.accent)
.disabled(isUpdatingNotificationUrgency)
```

When urgent is on:

- `.disabled`: show “Time Sensitive alerts are disabled in iOS Settings.” and `Open Settings`.
- `.notSupported`: show “Urgent delivery is unavailable for this build or device.”
- `.unknown`: do not claim system support; show a neutral “Urgent delivery status is unavailable.” message.
- `.enabled`: show no warning.

Use existing card typography, `.accent`, and `UIApplication.openSettingsURLString`.

- [ ] **Step 3: Refresh system settings on foreground activation**

Add a scene-phase refresh so returning from the provided `Open Settings` action updates the warning immediately:

```swift
.onChange(of: scenePhase) { _, phase in
	guard phase == .active else { return }
	Task {
		await notificationManager.checkAuthorizationStatus()
	}
}
```

`checkAuthorizationStatus()` must refresh both authorization and `timeSensitiveStatus` from the same system snapshot.

- [ ] **Step 4: Implement update/error behavior**

```swift
private func updateNotificationUrgency(to requestedValue: Bool) async {
	let previousValue = urgentNotificationsEnabled
	urgentNotificationsEnabled = requestedValue
	isUpdatingNotificationUrgency = true
	defer { isUpdatingNotificationUrgency = false }

	do {
		try await notificationManager.setUrgent(requestedValue, for: medication.id)
	} catch {
		urgentNotificationsEnabled = previousValue
		notificationUrgencyError = "Urgent notification settings could not be updated. Please try again."
	}
}
```

Present a SwiftUI alert from the optional error and ensure repeated taps are disabled while the update is pending.

- [ ] **Step 5: Run focused regression suites**

Run:

```bash
xcodebuild test \
	-project AsNeeded.xcodeproj \
	-scheme AsNeeded \
	-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
	-parallel-testing-enabled NO \
	-only-testing:AsNeededTests/MedicationNotificationUrgencyStoreTests \
	-only-testing:AsNeededTests/MedicationReminderRequestTests \
	-only-testing:AsNeededTests/NotificationManagerTests \
	-only-testing:AsNeededTests/SettingsExportImportTests \
	-only-testing:AsNeededTests/DataStoreTests \
	-only-testing:AsNeededTests/DataStoreClearTests
```

Expected: all selected tests pass.

- [ ] **Step 6: Run a direct Debug build**

Run:

```bash
xcodebuild build \
	-project AsNeeded.xcodeproj \
	-scheme AsNeeded \
	-configuration Debug \
	-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
	CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add AsNeeded/Medication/MedicationDetailView.swift
git commit -m "Add per-medication urgent notification control"
```

### Task 7: Final verification and PR #4 handoff

**Files:**

- Verify all changed production/test files.
- Update the existing PR #4 description; do not create another PR.

- [ ] **Step 1: Check repository hygiene**

Run:

```bash
git diff --check
git status --short
git log --oneline origin/task/remove-medication-guardrails..HEAD
```

Expected: no whitespace errors, no unrelated files, and only the approved design/plan/implementation commits.

- [ ] **Step 2: Re-run the direct focused tests**

Run the Task 6 Step 5 command without piping.

Expected: all selected suites pass. Record exact test counts from `xcodebuild`.

- [ ] **Step 3: Re-run the direct Debug build**

Run the Task 6 Step 6 command.

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify entitlement boundaries**

Run:

```bash
plutil -p AsNeeded/AsNeeded.entitlements
```

Expected source evidence:

```text
"com.apple.developer.usernotifications.time-sensitive" => true
```

If a signed Release archive is available, inspect the built application entitlements separately. Do not claim signed capability from the source plist. Do not claim Focus behavior without a physical-device urgent-vs-normal delivery test.

- [ ] **Step 5: Review the exact diff**

Run:

```bash
git diff --stat origin/task/remove-medication-guardrails...HEAD
git diff origin/task/remove-medication-guardrails...HEAD -- \
	AsNeeded AsNeededTests
```

Confirm:

- ANModelKit and `Package.resolved` are unchanged.
- Normal reminders use `.active`.
- Existing current-medication reminders migrate once to urgent.
- Explicit `false` cannot be re-migrated.
- Startup cannot complete migration before inventory readiness.
- Other medications and delivered-notification acknowledgement remain unaffected.

- [ ] **Step 6: Push the existing branch**

```bash
git push origin task/remove-medication-guardrails
```

- [ ] **Step 7: Update and re-read PR #4**

Use `gh pr edit 4 --body-file <prepared-temp-file>` to add:

- Per-medication urgency behavior and defaults.
- One-time/readiness-gated migration.
- Focused test counts and Debug build result.
- Source-entitlement, signed-Release, and physical-device validation as separate states.

Then run:

```bash
gh pr view 4 --json number,url,headRefOid,mergeable,reviewDecision,statusCheckRollup,body
```

Confirm the PR head matches local `HEAD`, the body describes the final implementation accurately, and no new PR was created.

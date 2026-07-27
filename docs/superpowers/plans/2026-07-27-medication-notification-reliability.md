# Medication Notification Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make medication reminders Time Sensitive, eliminate logically duplicate pending schedules including legacy timestamp-identified requests, and clear delivered reminders for a medication after its row-level quick log succeeds.

**Architecture:** Add a small pure request factory/identity helper around UserNotifications so notification content, normalized triggers, identifiers, duplicate detection, and medication matching are deterministic and unit-testable. Put pending/delivered system calls behind an injectable `MedicationNotificationClient` for manager-level ordering tests, and inject quick-log persistence plus acknowledgement closures into `MedicationListViewModel` so both success and failure behavior are deterministic.

**Tech Stack:** Swift 6, UserNotifications, Swift Testing, SwiftUI, Xcode 26, repository build/test scripts.

---

## File Map

- Create `AsNeeded/Services/MedicationReminderRequest.swift`: construct reminder requests and derive logical identities used for deterministic identifiers, legacy reconciliation, and delivered-notification matching.
- Create `AsNeededTests/MedicationReminderRequestTests.swift`: fast pure regression tests for interruption level, identity, deduplication, and medication matching.
- Modify `AsNeeded/Services/NotificationManager.swift`: add the injectable `MedicationNotificationClient`, use the request helper, reconcile pending duplicates, remove legacy matches only after replacement scheduling succeeds, and acknowledge delivered reminders.
- Modify `AsNeededTests/NotificationManagerTests.swift`: prove add-before-remove ordering, failure preservation, startup reconciliation, and delivered-only acknowledgement with a fake notification client.
- Modify `AsNeeded/Medication/ViewModels/MedicationListViewModel.swift`: inject quick-log persistence and delivered-reminder acknowledgement, invoking acknowledgement only after persistence succeeds.
- Modify `AsNeededTests/MedicationListViewModelUnitTests.swift`: record acknowledgement and inject deterministic persistence failure.
- Modify `AsNeeded/AsNeeded.entitlements`: enable the Time Sensitive Notifications capability for the app target.

### Task 0: Commit The Reviewed Plan

**Files:**
- Create: `docs/superpowers/plans/2026-07-27-medication-notification-reliability.md`

- [ ] **Step 1: Commit the reviewed implementation plan**

```bash
git add docs/superpowers/plans/2026-07-27-medication-notification-reliability.md
git commit -m "Plan notification reliability implementation"
```

### Task 1: Build Deterministic Medication Reminder Requests

**Files:**
- Create: `AsNeeded/Services/MedicationReminderRequest.swift`
- Create: `AsNeededTests/MedicationReminderRequestTests.swift`

- [ ] **Step 1: Write failing Time Sensitive and identity tests**

Create `MedicationReminderRequestTests` with shared helpers that build an `ANMedicationConcept` and `UNNotificationRequest` values. Start with these behaviors:

```swift
import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@Suite("Medication Reminder Request Tests", .tags(.service, .notifications, .unit))
struct MedicationReminderRequestTests {
	private let medication = ANMedicationConcept(clinicalName: "Aspirin")
	private let otherMedication = ANMedicationConcept(clinicalName: "Ibuprofen")

	private func makeRecurringRequest(
		medication requestedMedication: ANMedicationConcept? = nil,
		hour: Int,
		minute: Int
	) -> UNNotificationRequest {
		makeRecurringRequest(
			medication: requestedMedication,
			components: DateComponents(hour: hour, minute: minute)
		)
	}

	private func makeRecurringRequest(
		medication requestedMedication: ANMedicationConcept? = nil,
		components: DateComponents
	) -> UNNotificationRequest {
		MedicationReminderRequest.make(
			medication: requestedMedication ?? medication,
			date: Date(timeIntervalSince1970: 1_800_000_000),
			isRecurring: true,
			repeatInterval: components,
			showMedicationNames: false
		)
	}

	private func makeOneTimeRequest(date: Date) -> UNNotificationRequest {
		MedicationReminderRequest.make(
			medication: medication,
			date: date,
			isRecurring: false,
			repeatInterval: nil,
			showMedicationNames: false
		)
	}

	@Test("Reminder content is time sensitive")
	func reminderContentIsTimeSensitive() {
		let request = MedicationReminderRequest.make(
			medication: medication,
			date: Date(timeIntervalSince1970: 1_800_000_000),
			isRecurring: false,
			repeatInterval: nil,
			showMedicationNames: false
		)

		#expect(request.content.interruptionLevel == .timeSensitive)
	}

	@Test("Equivalent daily reminders have the same identifier")
	func equivalentDailyRemindersHaveStableIdentifier() {
		let components = DateComponents(hour: 9, minute: 30)
		let first = MedicationReminderRequest.make(
			medication: medication,
			date: Date(timeIntervalSince1970: 1_800_000_000),
			isRecurring: true,
			repeatInterval: components,
			showMedicationNames: false
		)
		let second = MedicationReminderRequest.make(
			medication: medication,
			date: Date(timeIntervalSince1970: 1_900_000_000),
			isRecurring: true,
			repeatInterval: components,
			showMedicationNames: false
		)

		#expect(first.identifier == second.identifier)
	}

	@Test("One-time identity ignores seconds within the same logical minute")
	func oneTimeIdentityIgnoresSecondsWithinMinute() {
		let minuteStart = Date(timeIntervalSince1970: 1_800_000_000)
		let first = makeOneTimeRequest(date: minuteStart)
		let sameMinute = makeOneTimeRequest(
			date: minuteStart.addingTimeInterval(59)
		)

		#expect(first.identifier == sameMinute.identifier)
	}

	@Test("One-time identity distinguishes different logical minutes")
	func oneTimeIdentityDistinguishesMinutes() {
		let minuteStart = Date(timeIntervalSince1970: 1_800_000_000)
		let first = makeOneTimeRequest(date: minuteStart)
		let nextMinute = makeOneTimeRequest(
			date: minuteStart.addingTimeInterval(60)
		)

		#expect(first.identifier != nextMinute.identifier)
	}

	@Test("Different recurring times have different identifiers")
	func differentRecurringTimesHaveDifferentIdentifiers() {
		let first = makeRecurringRequest(hour: 9, minute: 30)
		let second = makeRecurringRequest(hour: 10, minute: 30)

		#expect(first.identifier != second.identifier)
	}

	@Test("Recurring identity ignores unrelated source date fields")
	func recurringIdentityIgnoresUnrelatedSourceDateFields() {
		var firstComponents = DateComponents()
		firstComponents.year = 2026
		firstComponents.month = 7
		firstComponents.day = 27
		firstComponents.weekday = 2
		firstComponents.hour = 9
		firstComponents.minute = 30
		var secondComponents = firstComponents
		secondComponents.year = 2027
		secondComponents.month = 8
		secondComponents.day = 28

		let first = makeRecurringRequest(components: firstComponents)
		let second = makeRecurringRequest(components: secondComponents)

		#expect(first.identifier == second.identifier)
		let firstTrigger = first.trigger as? UNCalendarNotificationTrigger
		let secondTrigger = second.trigger as? UNCalendarNotificationTrigger
		#expect(firstTrigger?.dateComponents == secondTrigger?.dateComponents)
		#expect(firstTrigger?.dateComponents.year == nil)
		#expect(firstTrigger?.dateComponents.month == nil)
		#expect(firstTrigger?.dateComponents.day == nil)
	}

	@Test("Different weekly weekdays have different identifiers")
	func differentWeeklyWeekdaysHaveDifferentIdentifiers() {
		var firstComponents = DateComponents(hour: 9, minute: 30)
		firstComponents.weekday = 2
		var secondComponents = DateComponents(hour: 9, minute: 30)
		secondComponents.weekday = 3
		let first = makeRecurringRequest(components: firstComponents)
		let second = makeRecurringRequest(components: secondComponents)

		#expect(first.identifier != second.identifier)
	}
}
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```bash
./scripts/test-parallel.sh MedicationReminderRequestTests
```

Expected: build failure because `MedicationReminderRequest` does not exist.

- [ ] **Step 3: Implement the minimal request factory and logical identity**

Create a focused helper with these APIs:

```swift
import ANModelKit
import Foundation
import UserNotifications

struct MedicationReminderRequest {
	static let categoryIdentifier = "MEDICATION_REMINDER"
	static let medicationIDKey = "medicationId"

	struct Identity: Hashable {
		let medicationID: UUID
		let repeats: Bool
		let year: Int?
		let month: Int?
		let day: Int?
		let weekday: Int?
		let hour: Int?
		let minute: Int?

		var identifier: String {
			let values = [year, month, day, weekday, hour, minute]
				.map { $0.map(String.init) ?? "nil" }
				.joined(separator: "-")
			return "medication-reminder-\(medicationID.uuidString)-\(repeats ? "recurring" : "once")-\(values)"
		}
	}

	static func make(
		medication: ANMedicationConcept,
		date: Date,
		isRecurring: Bool,
		repeatInterval: DateComponents?,
		showMedicationNames: Bool,
		calendar: Calendar = .current
	) -> UNNotificationRequest {
		let repeats = isRecurring && repeatInterval != nil
		let components: DateComponents
		if repeats, let repeatInterval {
			var normalizedComponents = DateComponents()
			normalizedComponents.weekday = repeatInterval.weekday
			normalizedComponents.hour = repeatInterval.hour
			normalizedComponents.minute = repeatInterval.minute
			components = normalizedComponents
		} else {
			components = calendar.dateComponents(
				[.year, .month, .day, .hour, .minute],
				from: date
			)
		}
		let identity = Identity(
			medicationID: medication.id,
			repeats: repeats,
			components: components
		)
		let content = UNMutableNotificationContent()
		content.title = showMedicationNames ? medication.displayName : "Medication Reminder"
		content.body = showMedicationNames
			? "It's time to take \(medication.displayName)"
			: "It's time to take your medication"
		content.sound = .default
		content.interruptionLevel = .timeSensitive
		content.categoryIdentifier = categoryIdentifier
		content.userInfo = [medicationIDKey: medication.id.uuidString]
		let trigger = UNCalendarNotificationTrigger(
			dateMatching: components,
			repeats: repeats
		)
		return UNNotificationRequest(
			identifier: identity.identifier,
			content: content,
			trigger: trigger
		)
	}
}

private extension MedicationReminderRequest.Identity {
	init(medicationID: UUID, repeats: Bool, components: DateComponents) {
		self.init(
			medicationID: medicationID,
			repeats: repeats,
			year: repeats ? nil : components.year,
			month: repeats ? nil : components.month,
			day: repeats ? nil : components.day,
			weekday: repeats ? components.weekday : nil,
			hour: components.hour,
			minute: components.minute
		)
	}
}
```

- [ ] **Step 4: Run the focused suite and verify GREEN**

Run:

```bash
./scripts/test-parallel.sh MedicationReminderRequestTests
```

Expected: all initial request-construction tests pass.

- [ ] **Step 5: Write failing legacy duplicate and delivered-matching tests**

Add tests that construct canonical and timestamp-identified requests with the same content/trigger:

```swift
@Test("Duplicate reconciliation prefers the deterministic identifier")
func duplicateReconciliationPrefersDeterministicIdentifier() {
	let canonical = makeRecurringRequest(hour: 9, minute: 30)
	let legacy = UNNotificationRequest(
		identifier: "\(medication.id.uuidString)-1800000000.0",
		content: canonical.content,
		trigger: canonical.trigger
	)

	#expect(
		MedicationReminderRequest.duplicateIdentifiers(in: [legacy, canonical])
			== [legacy.identifier]
	)
}

@Test("Delivered matching selects only the requested medication")
func deliveredMatchingSelectsOnlyRequestedMedication() {
	let matching = makeRecurringRequest(hour: 9, minute: 30)
	let other = makeRecurringRequest(
		medication: otherMedication,
		hour: 9,
		minute: 30
	)

	#expect(
		MedicationReminderRequest.deliveredIdentifiers(
			for: medication.id,
			in: [matching, other]
		) == [matching.identifier]
	)
}
```

Also cover:

- a single pending request produces no duplicate identifiers
- multiple legacy duplicates retain exactly one deterministic choice
- a non-medication category is ignored
- `legacyIdentifiers(matching:in:)` excludes the incoming deterministic request itself

- [ ] **Step 6: Run the focused suite and verify RED**

Run:

```bash
./scripts/test-parallel.sh MedicationReminderRequestTests
```

Expected: compile failures for the missing duplicate and delivered-matching APIs.

- [ ] **Step 7: Implement identity extraction and filtering**

Add:

```swift
static func identity(for request: UNNotificationRequest) -> Identity? {
	guard request.content.categoryIdentifier == categoryIdentifier,
		  let medicationIDString = request.content.userInfo[medicationIDKey] as? String,
		  let medicationID = UUID(uuidString: medicationIDString),
		  let trigger = request.trigger as? UNCalendarNotificationTrigger
	else {
		return nil
	}

	return Identity(
		medicationID: medicationID,
		repeats: trigger.repeats,
		components: trigger.dateComponents
	)
}

static func legacyIdentifiers(
	matching request: UNNotificationRequest,
	in pendingRequests: [UNNotificationRequest]
) -> [String] {
	guard let targetIdentity = identity(for: request) else {
		return []
	}

	return pendingRequests.compactMap { pendingRequest in
		guard pendingRequest.identifier != request.identifier,
			  identity(for: pendingRequest) == targetIdentity
		else {
			return nil
		}
		return pendingRequest.identifier
	}.sorted()
}

static func duplicateIdentifiers(in requests: [UNNotificationRequest]) -> [String] {
	var grouped: [Identity: [UNNotificationRequest]] = [:]
	for request in requests {
		guard let identity = identity(for: request) else { continue }
		grouped[identity, default: []].append(request)
	}

	return grouped.flatMap { identity, groupedRequests in
		guard groupedRequests.count > 1 else { return [] }
		let retainedIdentifier = groupedRequests
			.first(where: { $0.identifier == identity.identifier })?
			.identifier
			?? groupedRequests.map(\.identifier).min()
		return groupedRequests
			.map(\.identifier)
			.filter { $0 != retainedIdentifier }
	}.sorted()
}

static func deliveredIdentifiers(
	for medicationID: UUID,
	in requests: [UNNotificationRequest]
) -> [String] {
	requests.compactMap { request in
		guard request.content.categoryIdentifier == categoryIdentifier,
			  request.content.userInfo[medicationIDKey] as? String == medicationID.uuidString
		else {
			return nil
		}
		return request.identifier
	}.sorted()
}
```

- [ ] **Step 8: Run the focused suite and verify GREEN**

Run:

```bash
./scripts/test-parallel.sh MedicationReminderRequestTests
```

Expected: all request construction, deduplication, and matching tests pass.

- [ ] **Step 9: Commit the pure notification behavior**

```bash
git add AsNeeded/Services/MedicationReminderRequest.swift AsNeededTests/MedicationReminderRequestTests.swift
git commit -m "Add deterministic medication reminders"
```

### Task 2: Coordinate Scheduling, Reconciliation, And Delivered Acknowledgement

**Files:**
- Modify: `AsNeeded/Services/NotificationManager.swift:32-172`
- Modify: `AsNeeded/AsNeeded.entitlements:5-15`
- Modify: `AsNeededTests/NotificationManagerTests.swift:15-25,121-220`
- Test: `AsNeededTests/MedicationReminderRequestTests.swift`

- [ ] **Step 1: Add a fake notification client and failing manager tests**

Add a test client to `NotificationManagerTests` that stores pending/delivered requests, records operations in order, and optionally throws from `add`:

```swift
@MainActor
private final class TestNotificationClient {
	enum TestError: Error {
		case addFailed
	}

	var pendingRequests: [UNNotificationRequest] = []
	var deliveredRequests: [UNNotificationRequest] = []
	var addedRequests: [UNNotificationRequest] = []
	var removedPendingIdentifiers: [[String]] = []
	var removedDeliveredIdentifiers: [[String]] = []
	var operations: [String] = []
	var addError: TestError?

	func makeClient() -> MedicationNotificationClient {
		MedicationNotificationClient(
			pendingRequests: {
				self.operations.append("pending")
				return self.pendingRequests
			},
			deliveredRequests: {
				self.operations.append("delivered")
				return self.deliveredRequests
			},
			add: { request in
				self.operations.append("add")
				self.addedRequests.append(request)
				if let addError = self.addError {
					throw addError
				}
			},
			removePending: { identifiers in
				self.operations.append("removePending")
				self.removedPendingIdentifiers.append(identifiers)
			},
			removeDelivered: { identifiers in
				self.operations.append("removeDelivered")
				self.removedDeliveredIdentifiers.append(identifiers)
			}
		)
	}
}

@MainActor
private final class TestStartupScheduler {
	private(set) var actions: [@MainActor () async -> Void] = []

	func schedule(_ action: @escaping @MainActor () async -> Void) {
		actions.append(action)
	}
}
```

Inside `NotificationManagerTests`, add concrete medication and request fixtures. `canonicalDailyRequest` uses the deterministic factory, `legacyDailyRequest` has the old timestamp identifier but identical content/trigger, `distinctWeeklyRequest` has a different logical identity, and `otherMedicationRequest` belongs to another medication:

```swift
private let medication = ANMedicationConcept(clinicalName: "Aspirin")
private let otherMedication = ANMedicationConcept(clinicalName: "Ibuprofen")
private let sourceDate = Date(timeIntervalSince1970: 1_800_000_000)

private func makeRecurringRequest(
	medication requestedMedication: ANMedicationConcept,
	weekday: Int? = nil,
	hour: Int,
	minute: Int
) -> UNNotificationRequest {
	var components = DateComponents(hour: hour, minute: minute)
	components.weekday = weekday
	return MedicationReminderRequest.make(
		medication: requestedMedication,
		date: sourceDate,
		isRecurring: true,
		repeatInterval: components,
		showMedicationNames: false
	)
}

private var canonicalDailyRequest: UNNotificationRequest {
	makeRecurringRequest(
		medication: medication,
		hour: 9,
		minute: 30
	)
}

private var legacyDailyRequest: UNNotificationRequest {
	let canonicalRequest = canonicalDailyRequest
	return UNNotificationRequest(
		identifier: "\(medication.id.uuidString)-\(sourceDate.timeIntervalSince1970)",
		content: canonicalRequest.content,
		trigger: canonicalRequest.trigger
	)
}

private var distinctWeeklyRequest: UNNotificationRequest {
	makeRecurringRequest(
		medication: medication,
		weekday: 2,
		hour: 9,
		minute: 30
	)
}

private var otherMedicationRequest: UNNotificationRequest {
	makeRecurringRequest(
		medication: otherMedication,
		hour: 9,
		minute: 30
	)
}
```

Write these tests against the injectable manager initializer:

```swift
@Test("Replacement is added before legacy reminders are removed")
func replacementIsAddedBeforeLegacyRemoval() async throws {
	let client = TestNotificationClient()
	client.pendingRequests = [legacyDailyRequest]
	let manager = NotificationManager(notificationClient: client.makeClient())

	try await manager.scheduleReminder(
		for: medication,
		date: sourceDate,
		isRecurring: true,
		repeatInterval: DateComponents(hour: 9, minute: 30)
	)

	#expect(client.operations == ["pending", "add", "removePending"])
	#expect(client.removedPendingIdentifiers == [[legacyDailyRequest.identifier]])
}

@Test("Failed replacement preserves legacy reminders")
func failedReplacementPreservesLegacyReminders() async {
	let client = TestNotificationClient()
	client.pendingRequests = [legacyDailyRequest]
	client.addError = .addFailed
	let manager = NotificationManager(notificationClient: client.makeClient())

	await #expect(throws: TestNotificationClient.TestError.addFailed) {
		try await manager.scheduleReminder(
			for: medication,
			date: sourceDate,
			isRecurring: true,
			repeatInterval: DateComponents(hour: 9, minute: 30)
		)
	}

	#expect(client.operations == ["pending", "add"])
	#expect(client.removedPendingIdentifiers.isEmpty)
}

@Test("Direct reconciliation removes only duplicate pending reminders")
func directReconciliationRemovesOnlyDuplicates() async {
	let client = TestNotificationClient()
	client.pendingRequests = [legacyDailyRequest, canonicalDailyRequest, distinctWeeklyRequest]
	let manager = NotificationManager(notificationClient: client.makeClient())

	await manager.reconcilePendingReminders()

	#expect(client.removedPendingIdentifiers == [[legacyDailyRequest.identifier]])
}

@Test("Startup initialization reconciles legacy duplicates")
func startupInitializationReconcilesLegacyDuplicates() async throws {
	let client = TestNotificationClient()
	let startupScheduler = TestStartupScheduler()
	client.pendingRequests = [legacyDailyRequest, canonicalDailyRequest]
	let manager = NotificationManager(
		notificationClient: client.makeClient(),
		startsAutomatically: true,
		performsSystemSetup: false,
		scheduleStartup: startupScheduler.schedule
	)

	#expect(startupScheduler.actions.count == 1)
	let startupAction = try #require(startupScheduler.actions.first)
	await startupAction()

	#expect(client.removedPendingIdentifiers == [[legacyDailyRequest.identifier]])
	withExtendedLifetime(manager) {}
}

@Test("Acknowledgement removes delivered reminders without changing pending recurrence")
func acknowledgementPreservesPendingRecurrence() async {
	let client = TestNotificationClient()
	client.pendingRequests = [canonicalDailyRequest]
	client.deliveredRequests = [canonicalDailyRequest, otherMedicationRequest]
	let manager = NotificationManager(notificationClient: client.makeClient())

	await manager.acknowledgeDeliveredReminders(for: medication.id)

	#expect(client.removedDeliveredIdentifiers == [[canonicalDailyRequest.identifier]])
	#expect(client.removedPendingIdentifiers.isEmpty)
	#expect(client.pendingRequests == [canonicalDailyRequest])
}
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```bash
./scripts/test-parallel.sh NotificationManagerTests
```

Expected: compile failure because `MedicationNotificationClient`, the startup-controlled injectable initializer, reconciliation, and delivered acknowledgement do not exist.

- [ ] **Step 3: Add the system-call client seam**

Add this internal client type in `NotificationManager.swift`:

```swift
@MainActor
struct MedicationNotificationClient {
	let pendingRequests: @MainActor () async -> [UNNotificationRequest]
	let deliveredRequests: @MainActor () async -> [UNNotificationRequest]
	let add: @MainActor (UNNotificationRequest) async throws -> Void
	let removePending: @MainActor ([String]) -> Void
	let removeDelivered: @MainActor ([String]) -> Void

	static func live(
		notificationCenter: UNUserNotificationCenter
	) -> MedicationNotificationClient {
		MedicationNotificationClient(
			pendingRequests: {
				await notificationCenter.pendingNotificationRequests()
			},
			deliveredRequests: {
				await notificationCenter.deliveredNotifications().map(\.request)
			},
			add: { request in
				try await notificationCenter.add(request)
			},
			removePending: { identifiers in
				notificationCenter.removePendingNotificationRequests(
					withIdentifiers: identifiers
				)
			},
			removeDelivered: { identifiers in
				notificationCenter.removeDeliveredNotifications(
					withIdentifiers: identifiers
				)
			}
		)
	}
}
```

Keep `MedicationNotificationClient` responsible for notification operations. Store `notificationCenter` and `notificationClient` in `NotificationManager`, and route both production and tests through one internal initializer. `startsAutomatically` and `performsSystemSetup` must both default to `false` so ordinary unit-test construction cannot touch the real notification center. Inject a startup scheduler matching the existing toast-scheduler pattern; its production default launches `Task { await action() }`. When automatic startup is enabled, pass one shared async startup action to the scheduler. That action conditionally performs real authorization/category setup and then always performs pending-reminder reconciliation:

```swift
static let shared: NotificationManager = {
	let notificationCenter = UNUserNotificationCenter.current()
	return NotificationManager(
		notificationCenter: notificationCenter,
		notificationClient: .live(notificationCenter: notificationCenter),
		startsAutomatically: true,
		performsSystemSetup: true
	)
}()

init(
	notificationCenter: UNUserNotificationCenter = .current(),
	notificationClient: MedicationNotificationClient,
	startsAutomatically: Bool = false,
	performsSystemSetup: Bool = false,
	scheduleStartup: @escaping (
		@escaping @MainActor () async -> Void
	) -> Void = { action in
		Task {
			await action()
		}
	}
) {
	self.notificationCenter = notificationCenter
	self.notificationClient = notificationClient
	showMedicationNames = UserDefaults.standard.object(
		forKey: UserDefaultsKeys.showMedicationNamesInNotifications
	) as? Bool ?? false

	if startsAutomatically {
		scheduleStartup {
			if performsSystemSetup {
				await checkAuthorizationStatus()
				await setupNotificationCategories()
			}
			await reconcilePendingReminders()
		}
	}
}
```

Do not add a separate production-only startup task. The scheduler-based test in Step 1 must exercise this exact initializer path with `startsAutomatically: true` and `performsSystemSetup: false`, assert exactly one startup action was captured, explicitly await that action, and then prove the legacy request was removed. Do not use continuations, polling, or timing sleeps.

- [ ] **Step 4: Replace ad hoc request construction in `NotificationManager`**

Replace `scheduleReminder` request construction with:

```swift
let request = MedicationReminderRequest.make(
	medication: medication,
	date: date,
	isRecurring: isRecurring,
	repeatInterval: repeatInterval,
	showMedicationNames: showMedicationNames
)
let pendingRequests = await notificationClient.pendingRequests()
let legacyIdentifiers = MedicationReminderRequest.legacyIdentifiers(
	matching: request,
	in: pendingRequests
)

try await notificationClient.add(request)

if !legacyIdentifiers.isEmpty {
	notificationClient.removePending(legacyIdentifiers)
}
```

Add focused system-call methods:

```swift
func reconcilePendingReminders() async {
	let pendingRequests = await notificationClient.pendingRequests()
	let duplicateIdentifiers = MedicationReminderRequest
		.duplicateIdentifiers(in: pendingRequests)
	guard !duplicateIdentifiers.isEmpty else { return }
	notificationClient.removePending(duplicateIdentifiers)
	logger.info("Removed \(duplicateIdentifiers.count) duplicate reminders")
}

func acknowledgeDeliveredReminders(for medicationID: UUID) async {
	let requests = await notificationClient.deliveredRequests()
	let identifiers = MedicationReminderRequest.deliveredIdentifiers(
		for: medicationID,
		in: requests
	)
	guard !identifiers.isEmpty else { return }
	notificationClient.removeDelivered(identifiers)
	logger.info("Acknowledged \(identifiers.count) delivered reminders")
}
```

Use `MedicationReminderRequest.categoryIdentifier` when registering the existing notification category.

- [ ] **Step 5: Enable the app capability**

Add to `AsNeeded/AsNeeded.entitlements`:

```xml
<key>com.apple.developer.usernotifications.time-sensitive</key>
<true/>
```

Do not request the deprecated `UNAuthorizationOptions.timeSensitive` authorization option.

- [ ] **Step 6: Run focused tests and entitlement validation**

Run:

```bash
./scripts/test-parallel.sh MedicationReminderRequestTests
./scripts/test-parallel.sh NotificationManagerTests
plutil -extract 'com\.apple\.developer\.usernotifications\.time-sensitive' raw AsNeeded/AsNeeded.entitlements
```

Expected: both focused suites pass; manager tests prove add-before-remove ordering and pending preservation; `plutil` prints `true`.

- [ ] **Step 7: Commit notification coordination**

```bash
git add AsNeeded/Services/NotificationManager.swift AsNeeded/AsNeeded.entitlements AsNeededTests/NotificationManagerTests.swift
git commit -m "Reconcile medication reminder notifications"
```

### Task 3: Acknowledge Delivered Reminders After Quick Log

**Files:**
- Modify: `AsNeeded/Medication/ViewModels/MedicationListViewModel.swift:12-95,237-291`
- Modify: `AsNeededTests/MedicationListViewModelUnitTests.swift:10-36,245-263`

- [ ] **Step 1: Add acknowledgement and persistence test doubles**

In `MedicationListViewModelUnitTests`, add:

```swift
@MainActor
private final class TestReminderAcknowledgement {
	private(set) var medicationIDs: [UUID] = []

	func acknowledge(_ medicationID: UUID) async {
		medicationIDs.append(medicationID)
	}
}
```

Create it in suite initialization and inject `acknowledge` into the view model. Use injected `QuickLogPersistence` closures for all unsuccessful persistence combinations without touching SQLite.

- [ ] **Step 2: Write the failing quick-log acknowledgement test**

Extend `quickLogCorrectlyLogsDose`:

```swift
#expect(reminderAcknowledgement.medicationIDs == [medication.id])
```

Add an assertion before quick logging that the recorder is empty, proving acknowledgement follows persistence rather than view-model construction.

Parameterize the failure test across `(false, false)`, `(true, false)`, and `(false, true)` so neither a total failure nor either partial persistence result acknowledges delivered reminders:

```swift
@Test(
	"Unsuccessful quick log does not acknowledge delivered reminders",
	arguments: [
		(updateSuccess: false, eventSuccess: false),
		(updateSuccess: true, eventSuccess: false),
		(updateSuccess: false, eventSuccess: true),
	]
)
func unsuccessfulQuickLogDoesNotAcknowledgeReminders(
	updateSuccess: Bool,
	eventSuccess: Bool
) async {
	let reminderAcknowledgement = TestReminderAcknowledgement()
	let failingViewModel = MedicationListViewModel(
		dataStore: dataStore,
		scheduleQuickLogToastDismissal: toastScheduler.schedule,
		quickLogPersistence: { _, _ in
			(updateSuccess, eventSuccess)
		},
		acknowledgeDeliveredReminders: reminderAcknowledgement.acknowledge
	)

	#expect(
		await failingViewModel.quickLog(
			medication: createTestMedication(name: "Failed")
		) == false
	)
	#expect(reminderAcknowledgement.medicationIDs.isEmpty)
}
```

- [ ] **Step 3: Run the view-model suite and verify RED**

Run:

```bash
./scripts/test-parallel.sh MedicationListViewModelUnitTests
```

Expected: compile failure because the view-model initializer has no acknowledgement parameter.

- [ ] **Step 4: Inject persistence and acknowledgement dependencies**

Add stored closure types:

```swift
typealias QuickLogPersistence = @MainActor (
	ANMedicationConcept,
	ANEventConcept
) async -> (updateSuccess: Bool, eventSuccess: Bool)

private let quickLogPersistence: QuickLogPersistence
private let acknowledgeDeliveredReminders: @MainActor (UUID) async -> Void
```

Extend the initializer:

```swift
init(
	dataStore: DataStore = .shared,
	scheduleQuickLogToastDismissal: @escaping (@escaping @MainActor @Sendable () -> Void) -> Void = { action in
		Task { @MainActor in
			try? await Task.sleep(nanoseconds: 3_000_000_000)
			action()
		}
	},
	quickLogPersistence: QuickLogPersistence? = nil,
	acknowledgeDeliveredReminders: @escaping @MainActor (UUID) async -> Void = { medicationID in
		await NotificationManager.shared
			.acknowledgeDeliveredReminders(for: medicationID)
	}
) {
	self.dataStore = dataStore
	self.scheduleQuickLogToastDismissal = scheduleQuickLogToastDismissal
	self.quickLogPersistence = quickLogPersistence ?? { updatedMedication, event in
		async let updateSuccess: Bool = {
			do {
				try await dataStore.updateMedication(updatedMedication)
				return true
			} catch {
				return false
			}
		}()
		async let eventSuccess: Bool = {
			do {
				try await dataStore.addEvent(
					event,
					shouldRecordForReview: false
				)
				return true
			} catch {
				return false
			}
		}()
		return await (updateSuccess, eventSuccess)
	}
	self.acknowledgeDeliveredReminders = acknowledgeDeliveredReminders
	// Existing initialization continues unchanged.
}
```

Replace the two `async let` calls in `quickLog` with:

```swift
let (updateSuccess, eventSuccess) = await quickLogPersistence(
	updatedMed,
	event
)
```

Inside the existing `if updateSuccess, eventSuccess` branch, invoke:

```swift
await acknowledgeDeliveredReminders(medication.id)
```

Do not invoke acknowledgement in the failure branch or in generic add/update methods.

- [ ] **Step 5: Run focused view-model and notification tests**

Run:

```bash
./scripts/test-parallel.sh MedicationListViewModelUnitTests
./scripts/test-parallel.sh MedicationReminderRequestTests
./scripts/test-parallel.sh NotificationManagerTests
```

Expected: all three focused suites pass.

- [ ] **Step 6: Commit quick-log integration**

```bash
git add AsNeeded/Medication/ViewModels/MedicationListViewModel.swift AsNeededTests/MedicationListViewModelUnitTests.swift
git commit -m "Acknowledge reminders after quick log"
```

### Task 4: Verify The PR Branch

**Files:**
- Verify all files changed since the exact pre-fix PR head `f8eb8b127b86bf9c3c11f04406ae2fa4260db2a6`

- [ ] **Step 1: Check formatting, whitespace, and scope**

Run:

```bash
git diff --check f8eb8b127b86bf9c3c11f04406ae2fa4260db2a6...HEAD
git status --short
git diff --stat f8eb8b127b86bf9c3c11f04406ae2fa4260db2a6...HEAD
```

Expected: no whitespace errors; only the approved spec/plan, notification helper/manager, entitlement, view model, and focused tests are changed.

- [ ] **Step 2: Run the repository test script**

Run:

```bash
./scripts/test-parallel.sh
```

Compare against the pinned pre-fix PR-head signature from `f8eb8b127b86bf9c3c11f04406ae2fa4260db2a6`:

- 444 passed, 360 failed, 4 skipped
- 356 failures are Boutique/SQLite test-host crashes
- the remaining settings assertions pass when run in isolation

The new focused tests increase the passing count, so compare failure identities as well as totals. Any failure outside that documented signature, any increase in those failure categories, or any focused-suite failure is a regression. Report a reproduced baseline limitation separately; do not call the broad suite clean.

- [ ] **Step 3: Run the optimized development build**

Run:

```bash
./scripts/dev-build.sh
```

Expected: Debug app/widget/watch build succeeds for the iPhone 17 simulator.

- [ ] **Step 4: Validate the source entitlement plist**

Run:

```bash
plutil -lint AsNeeded/AsNeeded.entitlements
plutil -extract 'com\.apple\.developer\.usernotifications\.time-sensitive' raw AsNeeded/AsNeeded.entitlements
```

Expected: the entitlement plist is valid and the extracted value is `true`. This source-plist check is necessary but does not prove the entitlement survived signing.

- [ ] **Step 5: Build Release and verify the signed app's embedded entitlement**

Run the repository's production build, derive the exact Release app path from Xcode build settings, verify its signature and embedded provisioning profile, then extract the signed entitlements with `codesign` and assert the Time Sensitive value with `plutil`:

```bash
./scripts/prod-build.sh
RELEASE_SETTINGS="$(mktemp /tmp/asneeded-release-settings.XXXXXX)"
SIGNED_ENTITLEMENTS="$(mktemp /tmp/asneeded-signed-entitlements.XXXXXX)"
PROFILE_PLIST="$(mktemp /tmp/asneeded-profile.XXXXXX)"
xcodebuild -project AsNeeded.xcodeproj -scheme AsNeeded -configuration Release -sdk iphoneos -showBuildSettings -json > "$RELEASE_SETTINGS"
RELEASE_APP="$(plutil -extract '0.buildSettings.CODESIGNING_FOLDER_PATH' raw -o - "$RELEASE_SETTINGS")"
test -d "$RELEASE_APP"
codesign --verify --deep --strict --verbose=2 "$RELEASE_APP"
test -f "$RELEASE_APP/embedded.mobileprovision"
codesign -d --entitlements "$SIGNED_ENTITLEMENTS" --xml "$RELEASE_APP"
plutil -lint "$SIGNED_ENTITLEMENTS"
test "$(plutil -extract 'com\.apple\.developer\.usernotifications\.time-sensitive' raw "$SIGNED_ENTITLEMENTS")" = "true"
security cms -D -i "$RELEASE_APP/embedded.mobileprovision" > "$PROFILE_PLIST"
plutil -lint "$PROFILE_PLIST"
test "$(plutil -extract 'Entitlements.com\.apple\.developer\.usernotifications\.time-sensitive' raw "$PROFILE_PLIST")" = "true"
```

Expected: `./scripts/prod-build.sh` succeeds; `RELEASE_APP` resolves to a signed Release `AsNeeded.app`; its embedded profile exists; and both the signed entitlement and provisioning-profile entitlement are `true`. If the Release app cannot be signed, the profile is absent, or either signed value is unavailable/false, stop and report a distribution-signing blocker. Do not claim production Time Sensitive capability verification from the source plist alone.

- [ ] **Step 6: Perform the remaining Focus delivery check on named physical hardware**

Run:

```bash
xcrun devicectl list devices
```

If a named physical iPhone is available, record its exact device name and iOS version, install/launch the signed Release app, enable a Focus that would ordinarily suppress As Needed, allow Time Sensitive Notifications for As Needed, schedule a near-term medication reminder, lock the device, and verify the notification is delivered as Time Sensitive. Also verify a successful row quick log clears the delivered reminder while leaving its next recurring request scheduled.

If no named physical iPhone is available, report this as explicit remaining validation: “Focus/Time Sensitive delivery not yet verified on physical hardware.” Simulator delivery or a successful simulator build does not prove Focus bypass behavior.

- [ ] **Step 7: Verify final diff and worktree state**

Run:

```bash
git diff --check f8eb8b127b86bf9c3c11f04406ae2fa4260db2a6...HEAD
git status --short --branch
```

Expected: diff check is clean; worktree is clean and ahead of the remote PR branch.

- [ ] **Step 8: Push the verified branch to PR #4**

```bash
git push origin task/remove-medication-guardrails
```

- [ ] **Step 9: Re-read the live PR head and checks**

Run:

```bash
gh pr view 4 --json headRefOid,mergeable,statusCheckRollup,url
```

Expected: `headRefOid` matches local `HEAD`; report mergeability and CI independently from local verification.

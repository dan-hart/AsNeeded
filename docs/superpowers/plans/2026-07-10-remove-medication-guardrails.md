# Remove Medication Guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all dose-safety guardrails and eligibility claims while preserving a safely migrated per-medication low-stock threshold and the app's unrelated refill, logging, history, privacy, and accessibility behavior.

**Architecture:** Replace the mixed safety/refill profile and guidance service with a refill-only profile store and projection service. Migrate only `lowStockThreshold` from the legacy UserDefaults payload, archive the verified raw payload, and prevent replay. Then simplify app and extension surfaces so refill state and last-dose history remain while logging is always available.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, UserDefaults/App Group storage, ActivityKit, WidgetKit, WatchConnectivity, App Intents, Boutique, Xcode 26.6

---

## File Structure

**Create or rename:**

- `AsNeeded/Models/MedicationRefillProfile.swift` — refill-only stored model.
- `AsNeeded/Services/MedicationRefillProfileStore.swift` — active profile persistence and legacy migration.
- `AsNeeded/Services/MedicationRefillProjectionService.swift` — refill calculations only.
- `AsNeededTests/MedicationRefillProfileStoreTests.swift` — storage and migration behavior.
- `AsNeededTests/MedicationRefillProjectionServiceTests.swift` — refill calculation behavior.

**Delete:**

- `AsNeeded/Models/MedicationSafetyProfile.swift`
- `AsNeeded/Services/MedicationSafetyProfileStore.swift`
- `AsNeeded/Services/MedicationDoseGuidanceService.swift`
- `AsNeeded/Services/Intents/GetNextDoseIntent.swift`
- `AsNeededTests/MedicationSafetyProfileStoreTests.swift`
- `AsNeededTests/MedicationDoseGuidanceServiceTests.swift`

The Xcode project uses file-system-synchronized groups, so these file additions, renames, and deletions do not require manual `project.pbxproj` edits.

### Task 1: Build the refill-only profile and safe migration

**Files:**

- Create: `AsNeeded/Models/MedicationRefillProfile.swift`
- Create: `AsNeeded/Services/MedicationRefillProfileStore.swift`
- Create: `AsNeededTests/MedicationRefillProfileStoreTests.swift`
- Modify: `AsNeeded/Constants/UserDefaultsKeys.swift`

- [ ] **Step 1: Write failing profile and migration tests**

Cover these public behaviors with Swift Testing:

```swift
@Test("Store saves only custom low-stock thresholds")
func savesCustomThreshold() {
	let store = makeStore()
	let medicationID = UUID()
	store.save(MedicationRefillProfile(lowStockThreshold: 7), for: medicationID)
	#expect(store.profile(for: medicationID).lowStockThreshold == 7)
}

@Test("Legacy profiles migrate low-stock thresholds once")
func migratesLegacyProfilesOnce() throws {
	let fixture = try legacyPayload([medicationID.uuidString: 6])
	defaults.set(fixture, forKey: UserDefaultsKeys.legacyMedicationProfiles)
	let store = makeStore()
	#expect(store.profile(for: medicationID).lowStockThreshold == 6)
	#expect(defaults.data(forKey: UserDefaultsKeys.archivedMedicationProfiles) == fixture)
	#expect(defaults.data(forKey: UserDefaultsKeys.legacyMedicationProfiles) == nil)
	#expect(defaults.bool(forKey: UserDefaultsKeys.medicationProfilesMigrationCompleted))
	store.save(.empty, for: medicationID)
	#expect(makeStore().profile(for: medicationID) == .empty)
}
```

Also test new-only data, both keys with new data winning, legacy data without a threshold, invalid legacy data remaining untouched, standard defaults winning over App Group data, verified mirroring, filtering invalid medication IDs, repeated store creation, active-payload verification failure, and archive-write/verification failure. Inject internal profile encoding and legacy archiving closures into the store initializer so those two failure paths are deterministic without relying on a real `UserDefaults` I/O failure.

- [ ] **Step 2: Run the store suite and verify RED**

Run:

```bash
./scripts/test-parallel.sh MedicationRefillProfileStoreTests
```

Expected: compilation fails because `MedicationRefillProfile` and `MedicationRefillProfileStore` do not exist.

- [ ] **Step 3: Implement the refill model and keys**

Use this public model:

```swift
struct MedicationRefillProfile: Codable, Equatable, Sendable {
	static let empty = MedicationRefillProfile()
	var lowStockThreshold: Double?

	var isEmpty: Bool { lowStockThreshold == nil }
}
```

Add typed keys for the active refill payload, legacy payload, archived raw payload, and migration-completed marker. Keep the literal legacy key equal to `"medicationSafetyProfiles"` only for migration. Add active and marker keys to `allKeys`/reset handling; exclude the archive from normal export allowlists.

- [ ] **Step 4: Implement migration and persistence**

`MedicationRefillProfileStore` must:

- Prefer valid standard-defaults active data and mirror it to shared defaults.
- Fall back to valid shared active data only when standard data is absent.
- Decode the legacy dictionary through a private `LegacyMedicationProfile` containing only `lowStockThreshold`; Codable ignores removed fields.
- Persist and decode-verify migrated active profiles before archiving legacy bytes.
- Copy and byte-verify the archive before removing the active legacy key.
- Set the migration marker only after archival succeeds.
- Keep invalid or unverifiable legacy data untouched.
- Leave the active legacy key and migration marker unchanged when active-payload verification or archive verification fails.
- Never migrate again after the marker is set, including after the final custom threshold is removed.
- Provide `profile(for:)`, `save(_:for:)`, `allProfiles()`, `replaceAll(with:)`, and `filteredProfiles(from:validMedicationIDs:)`.
- Keep the old safety profile/store files temporarily so downstream targets continue compiling until Task 8 completes their migration.

- [ ] **Step 5: Run the store suite and verify GREEN**

Run `./scripts/test-parallel.sh MedicationRefillProfileStoreTests` and inspect the latest `.xcresult` summary. Expected: the focused suite passes with zero failed tests.

- [ ] **Step 6: Commit the storage boundary**

```bash
git add AsNeeded/Models/MedicationRefillProfile.swift AsNeeded/Services/MedicationRefillProfileStore.swift AsNeeded/Constants/UserDefaultsKeys.swift AsNeededTests/MedicationRefillProfileStoreTests.swift
git commit -m "Replace guardrails with refill profiles"
```

### Task 2: Extract refill calculations from dose guidance

**Files:**

- Create: `AsNeeded/Services/MedicationRefillProjectionService.swift`
- Create: `AsNeededTests/MedicationRefillProjectionServiceTests.swift`
- Modify: `AsNeeded/Services/Intents/CheckRefillStatusIntent.swift`
- Modify: `AsNeededTests/CheckRefillStatusIntentTests.swift`

- [ ] **Step 1: Write failing refill projection tests**

Retain tests for average daily usage, estimated days remaining, next-refill dates, custom/default low-stock thresholds, and urgent/refill-soon status. Add a test proving the refill-soon window is the fixed five-day constant.

```swift
let projection = MedicationRefillProjectionService().projection(
	for: medication,
	at: now,
	events: events,
	profile: MedicationRefillProfile(lowStockThreshold: 5)
)
#expect(projection.lowStock)
#expect(projection.refillSoon)
```

- [ ] **Step 2: Run the projection suite and verify RED**

Run `./scripts/test-parallel.sh MedicationRefillProjectionServiceTests`. Expected: missing service compilation failure.

- [ ] **Step 3: Implement the refill-only service**

Move `RefillProjection`, event filtering, unit-aware average usage, run-out projection, and status copy from the old service. Expose `projection(for:at:events:profile:)`. Use `defaultLowStockThreshold = 10` and `refillLeadDays = 5` as internal constants. Do not copy `Severity`, `Assessment`, dose eligibility, daily totals for proposed doses, or duplicate detection.

- [ ] **Step 4: Update the refill App Intent**

Inject/use `MedicationRefillProfileStore` and `MedicationRefillProjectionService` in `CheckRefillStatusIntent`. Update its tests to construct `MedicationRefillProjectionService.RefillProjection`.

- [ ] **Step 5: Run both focused suites while retaining the compatibility service**

Run:

```bash
./scripts/test-parallel.sh MedicationRefillProjectionServiceTests
./scripts/test-parallel.sh CheckRefillStatusIntentTests
```

Expected: both pass with zero failures in their `.xcresult` summaries.

Keep `MedicationDoseGuidanceService.swift` and its tests until Task 8 has migrated the final widget/watch consumer. This preserves whole-target compilation at every checkpoint.

- [ ] **Step 6: Commit the service split**

```bash
git add AsNeeded/Services AsNeededTests
git commit -m "Extract refill projection service"
```

### Task 3: Reduce medication editing to low-stock configuration

**Files:**

- Modify: `AsNeeded/Medication/ViewModels/MedicationEditViewModel.swift`
- Modify: `AsNeeded/Medication/MedicationEditView.swift`
- Modify: `AsNeededTests/MedicationEditViewModelTests.swift`

- [ ] **Step 1: Replace guardrail view-model tests with refill-only tests**

Assert that an existing custom threshold loads, blank/invalid/zero values normalize to nil, positive values save, and the resulting profile contains no other configurable state.

- [ ] **Step 2: Run `./scripts/test-parallel.sh MedicationEditViewModelTests` and verify RED**

Expected: failures reference the not-yet-renamed store/build methods.

- [ ] **Step 3: Simplify `MedicationEditViewModel`**

Remove minimum interval, caution, daily limit, duplicate window, and refill lead-time published properties. Rename dependencies and methods to `refillProfileStore`, `buildRefillProfile()`, and `saveRefillProfile(for:)`. Keep `lowStockThresholdText` and existing positive-number normalization.

- [ ] **Step 4: Simplify the SwiftUI form**

Remove the “Safety Guardrails” section and its focus cases. Add a compact “Refill Alert” section containing only “Low Stock Threshold,” with copy that explains the default of 10 when blank. Remove the guardrail navigation subtitle.

- [ ] **Step 5: Run the focused suite and development build**

Run:

```bash
./scripts/test-parallel.sh MedicationEditViewModelTests
./scripts/dev-build.sh
```

Expected: focused tests pass and the app builds.

- [ ] **Step 6: Commit the editor removal**

```bash
git add AsNeeded/Medication AsNeededTests/MedicationEditViewModelTests.swift
git commit -m "Remove guardrail medication settings"
```

### Task 4: Simplify app status and logging feedback

**Files:**

- Modify: `AsNeeded/Services/MedicationStatusSummaryService.swift`
- Modify: `AsNeeded/Services/QuickLogFeedbackService.swift`
- Modify: `AsNeeded/Medication/ViewModels/MedicationListViewModel.swift`
- Modify: `AsNeeded/Medication/LogDoseView.swift`
- Modify: `AsNeeded/Medication/MedicationDetailView.swift`
- Modify: `AsNeeded/Views/Components/MedicationRowComponent.swift`
- Modify: `AsNeeded/Views/Components/QuickLogToastView.swift`
- Modify: `AsNeededTests/MedicationStatusSummaryServiceTests.swift`
- Modify: `AsNeededTests/QuickLogFeedbackServiceTests.swift`
- Modify: `AsNeededTests/MedicationListViewModelUnitTests.swift`

- [ ] **Step 1: Write failing status and feedback tests**

Define `MedicationStatusSummaryService.Summary` around `headline`, `timingText`, `refillText`, `isLowStock`, `refillSoon`, and `accessibilityLabel`. Assert that no returned string contains `guardrail`, `guidance`, `next window`, or a daily limit. Assert quick-log feedback is always success and retains the logged event ID for undo.

- [ ] **Step 2: Run the three focused suites and verify RED**

Run the status, quick-log feedback, and medication-list view-model suites separately.

- [ ] **Step 3: Implement refill/last-dose status only**

Make `MedicationStatusSummaryService` depend on `MedicationRefillProjectionService`. Preserve last-dose formatting and refill text. Derive visual emphasis only from `isLowStock` and `refillSoon`; remove dose-severity, badge, next-window, daily-total, and guardrail accessibility fields.

- [ ] **Step 4: Simplify quick-log feedback**

Reduce `Tone` to success or remove the enum if the view no longer needs it. Build feedback from medication, dose, and logged event only:

```swift
Feedback(
	title: "Dose logged",
	message: "Logged ...",
	detail: medication.displayName,
	undoEventID: loggedEvent.id
)
```

Remove assessment creation from `MedicationListViewModel`. Preserve toast dismissal and undo behavior.

- [ ] **Step 5: Remove guidance UI from dose logging and summaries**

Delete the guidance section, accessibility warning, severity colors, and assessment dependencies from `LogDoseView`. Update row/detail summary layouts to show last-dose and refill information without eligibility badges. Update `QuickLogToastView` to use the accent success treatment while retaining dismissal and undo.

- [ ] **Step 6: Run focused tests and build**

Run each modified suite, then `./scripts/dev-build.sh`. Expected: zero focused failures and a successful app build.

- [ ] **Step 7: Commit app behavior removal**

```bash
git add AsNeeded/Medication AsNeeded/Services/MedicationStatusSummaryService.swift AsNeeded/Services/QuickLogFeedbackService.swift AsNeeded/Views/Components AsNeededTests
git commit -m "Remove guardrail status and warnings"
```

### Task 5: Preserve refill insights in trends and clinician reports

**Files:**

- Modify: `AsNeeded/Medication/ViewModels/MedicationTrendsViewModel.swift`
- Modify: `AsNeeded/Views/Screens/Medication/MedicationTrendsView.swift`
- Modify: `AsNeeded/Services/ClinicianReportExporter.swift`
- Modify: `AsNeeded/Views/ViewModels/DataManagementViewModel.swift`
- Modify: `AsNeededTests/MedicationTrendsViewModelTests.swift`
- Modify: `AsNeededTests/ClinicianReportExporterTests.swift`

- [ ] **Step 1: Update tests to the refill-only API**

Remove the next-eligible-dose test. Assert trends still expose refill projection with a custom threshold and clinician reports include refill status using `[String: MedicationRefillProfile]`.

- [ ] **Step 2: Run both suites and verify RED**

Run the trends and clinician exporter suites separately. Expected: old type/signature failures.

- [ ] **Step 3: Update trends**

Inject `MedicationRefillProfileStore` and `MedicationRefillProjectionService`; expose `refillProfile` and `refillProjection`; remove `nextEligibleDoseDate` and the “Next window” UI.

- [ ] **Step 4: Update clinician export**

Rename `safetyProfiles` to `refillProfiles` and use the refill projection service. Pass profiles from `MedicationRefillProfileStore.shared` in `DataManagementViewModel`.

- [ ] **Step 5: Run focused tests and commit**

Run both suites and `git diff --check`, then commit as `Preserve refill insights after guardrails`.

### Task 6: Migrate settings export, import, reset, and clear-all behavior

**Files:**

- Modify: `AsNeeded/Models/AppSettings.swift`
- Modify: `AsNeeded/Constants/UserDefaultsKeys.swift`
- Modify: `AsNeeded/Services/Persistence/DataStore.swift`
- Modify: `AsNeededTests/SettingsExportImportTests.swift`
- Modify: `AsNeededTests/DataStoreClearTests.swift`
- Modify: `AsNeededTests/DataStoreTests.swift`
- Modify: `docs/DATA_STORAGE_GUIDELINES.md`

- [ ] **Step 1: Write failing settings lifecycle tests**

Test active refill profile export/import with invalid medication IDs filtered, decoding legacy exported `medicationSafetyProfiles` into refill profiles, clear-all removal from standard/shared defaults, reset behavior, and key-list completeness. Assert archive recovery data is not exported.

- [ ] **Step 2: Run the focused settings suites and verify RED**

Run `SettingsExportImportTests`, `DataStoreClearTests`, and the UserDefaults-key test from `DataStoreTests` separately.

- [ ] **Step 3: Implement backward-compatible `AppSettings` decoding**

Rename the active property to `medicationRefillProfiles`. Use custom Codable decoding so current exports read `medicationRefillProfiles` first and legacy exports can decode the old `medicationSafetyProfiles` object through the minimal legacy low-stock shape. Encode only the new property. Rename the settings category from “Clinical Guidance” to “Refill Preferences.”

- [ ] **Step 4: Update reset and clear-all key handling**

Ensure active refill, legacy active, archive, and migration marker keys are handled deliberately: normal settings reset removes the active refill preference; clear-all removes active and migration state from standard/shared defaults; archived migration recovery bytes remain excluded from normal settings export.

- [ ] **Step 5: Document the UserDefaults migration**

Add the refill profile key, legacy archive, authority rules, non-replay marker, and verification cases to `docs/DATA_STORAGE_GUIDELINES.md` without changing database storage claims.

- [ ] **Step 6: Run focused suites and commit**

Expected: all settings lifecycle suites pass. Commit as `Migrate refill profile settings safely`.

### Task 7: Remove eligibility from Live Activities and App Intents

**Files:**

- Modify: `AsNeeded/Services/MedicationLiveActivityManager.swift`
- Modify: `AsNeededWidget/MedicationLiveActivityAttributes.swift`
- Modify: `AsNeededWidget/MedicationLiveActivityBridge.swift`
- Modify: `AsNeededWidget/MedicationLiveActivityWidget.swift`
- Modify: `AsNeeded/Services/Intents/LogMedicationIntent.swift`
- Delete: `AsNeeded/Services/Intents/GetNextDoseIntent.swift`
- Modify: `AsNeededTests/MedicationLiveActivityStateBuilderTests.swift`

- [ ] **Step 1: Replace eligibility state-builder tests**

Assert the builder prioritizes low-stock, then refill-soon, then alphabetical medications; emits refill status/detail; and has no `nextDoseDate` or `canTakeNow` fields.

- [ ] **Step 2: Run the state-builder suite and verify RED**

Expected: compile failures against the old snapshot shape.

- [ ] **Step 3: Simplify the Live Activity state**

Remove `nextDoseDate` and `canTakeNow` from snapshot, content, ActivityKit state, bridge, and widget rendering. Use a fixed 30-minute stale date. Render low-stock/refill status and keep the deep link into the medication.

- [ ] **Step 4: Remove the unsupported intent**

Delete `GetNextDoseIntent.swift` and remove `GetNextDoseIntent()` from the `AppShortcutsProvider` registration in `LogMedicationIntent.swift`. Confirm no remaining shortcut registration or tests reference it. Retain `CheckRefillStatusIntent`.

- [ ] **Step 5: Run focused tests and build**

Run `MedicationLiveActivityStateBuilderTests` and `./scripts/dev-build.sh`. Expected: tests and all app extension compilation pass.

- [ ] **Step 6: Commit**

Commit as `Remove dose eligibility from live surfaces`.

### Task 8: Remove eligibility from widgets and watchOS

**Files:**

- Modify: `AsNeededWidget/WidgetDataProvider.swift`
- Modify: `AsNeededWidget/LogDoseWidgetIntent.swift`
- Modify: `AsNeededWidget/MedicationSmallWidget.swift`
- Modify: `AsNeededWidget/MedicationMediumWidget.swift`
- Modify: `AsNeededWidget/MedicationLargeWidget.swift`
- Modify: `AsNeededWidget/MedicationLockScreenWidget.swift`
- Modify: `AsNeeded/Services/WatchConnectivity/WCReceiver.swift`
- Modify: `WristAsNeeded Watch App/WatchMedication.swift`
- Modify: `WristAsNeeded Watch App/MedicationListView.swift`
- Modify: `WristAsNeeded Watch App/MedicationDetailView.swift`
- Modify: `WristAsNeeded Watch App/DoseLoggerView.swift`
- Delete: `AsNeeded/Models/MedicationSafetyProfile.swift`
- Delete: `AsNeeded/Services/MedicationSafetyProfileStore.swift`
- Delete: `AsNeeded/Services/MedicationDoseGuidanceService.swift`
- Delete: `AsNeededTests/MedicationSafetyProfileStoreTests.swift`
- Delete: `AsNeededTests/MedicationDoseGuidanceServiceTests.swift`

- [ ] **Step 1: Refactor widget data to refill-only state**

Decode `medicationRefillProfiles` from shared defaults, with a read-only legacy fallback for upgrades before the main app launches. Replace `WidgetMedicationSafetyProfile`/guidance with refill-only equivalents. Remove next-dose time, time-until-dose, and can-take APIs. Choose featured medications by low-stock/refill urgency then name.

- [ ] **Step 2: Make widget logging always available**

Remove the `canTakeNow` guard from `LogDoseWidgetIntent`. Remove eligibility fields and conditional clock/ready UI from small, medium, large, and lock-screen timeline entries. Keep refill indicators and logging deep links/buttons.

- [ ] **Step 3: Simplify watch payload and model**

Send only refill state, medication identity, quantity, and prescribed dose fields. Remove `canTakeNow` and `nextDoseDate` from `WCReceiver` and `WatchMedication`.

- [ ] **Step 4: Make watch logging always available**

Remove disabled states, clock icons, countdown copy, and `canTake(at:)` checks from watch list, detail, and logger views. Preserve low-stock/refill banners and successful quantity/log updates.

- [ ] **Step 5: Delete the now-unused compatibility types**

After app, intent, Live Activity, widget, and watch callers all compile against refill-only APIs, delete the old safety profile, safety store, dose-guidance service, and their obsolete tests. Confirm `rg` finds no consumers before deletion.

- [ ] **Step 6: Build all targets and inspect active references**

Run:

```bash
./scripts/dev-build.sh
rg -n "canTakeNow|nextDoseDate|nextEligible|guardrail|saved guidance" AsNeeded AsNeededWidget "WristAsNeeded Watch App"
```

Expected: build succeeds; remaining matches are limited to explicit legacy migration identifiers or unrelated generic language, with no active eligibility UI/logic.

- [ ] **Step 7: Commit**

Commit as `Remove guardrails from widget and watch`.

### Task 9: Update product copy and perform final verification

**Files:**

- Modify: `README.md`
- Modify: any active source/test file revealed by final guardrail searches

- [ ] **Step 1: Update README product claims**

Replace saved safety-guardrail and next-dose claims with quick logging, low-stock/refill awareness, last-dose history, and usage insights. Do not rewrite historical design/plan documents.

- [ ] **Step 2: Run static removal checks**

Run targeted searches for every removed type, field, and claim across active source, tests, widgets, watch, and README. Expected: no active references to old types or dose guardrail fields; only migration key literals/types explicitly documented by Task 1 may remain.

- [ ] **Step 3: Run all focused affected suites**

Run each affected suite separately through `scripts/test-parallel.sh` and inspect each latest `.xcresult` summary. Expected: zero failed tests.

- [ ] **Step 4: Run repository-wide verification**

Run:

```bash
./scripts/test-parallel.sh
./scripts/dev-build.sh
./scripts/prod-build.sh
git diff origin/develop...HEAD --check
```

Inspect the full test `.xcresult` directly because the unchanged baseline wrapper can exit 0 after a Boutique/SQLite test-host crash. If the baseline crash persists, report passed/failed/skipped counts accurately and require all focused suites plus both builds to pass before publishing.

- [ ] **Step 5: Review the final diff against the spec**

Confirm: only low-stock threshold remains configurable; migrations are non-destructive and non-replaying; logging is never eligibility-gated; refill, last-dose, undo, history, privacy, clinician report, and accessibility behavior remain; no unrelated changes are staged.

- [ ] **Step 6: Commit final copy/cleanup**

```bash
git add README.md AsNeeded AsNeededWidget "WristAsNeeded Watch App" AsNeededTests docs/DATA_STORAGE_GUIDELINES.md
git commit -m "Remove medication guardrails"
```

- [ ] **Step 7: Publish the branch**

Use `github:yeet`: verify status/diff, push `task/remove-medication-guardrails`, and open a draft PR against `develop` with the migration behavior, removed surfaces, preserved refill behavior, focused test results, build results, and any unchanged full-suite host-crash limitation documented accurately.

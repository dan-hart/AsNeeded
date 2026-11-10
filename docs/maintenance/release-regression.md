# AsNeeded 1.3 regression baseline

Use the `1.2.0` tag at `4b2c3b6488568a350330e6eceb4e322817bd98c4` (build 324) as the source reference for behavior to preserve. The [business rules](../../BUSINESS_RULES.md) describe current behavior and link to implementation and tests. Resolve surprises through the [human Drift review policy](../drift.md#required-human-review).

## Behavior that must survive

| Surface | Regression evidence | Release rehearsal |
| --- | --- | --- |
| Log Dose, quick log, Undo, and stock | [Atomic persistence](../../AsNeededTests/AtomicPersistenceTests.swift), [Undo races](../../AsNeededTests/QuickLogUndoRaceTests.swift), [selection](../../AsNeededTests/FloatingDoseTargetTests.swift) | Log against two different medications, then Undo one. Check the event and its stock correction. |
| Saved limits and historical logging | [Guidance boundaries](../../AsNeededTests/MedicationDoseGuidanceServiceTests.swift), [backdated dose checks](../../AsNeededTests/BackdatedDoseLoggingTests.swift) | Check one medication without limits and one with limits. Backdate a dose and confirm its recorded date. |
| History and Trends | [History filters](../../AsNeededTests/HistoryDateFilterTests.swift), [Trends ranges](../../AsNeededTests/TrendsDateRangeTests.swift) | Verify History includes today when in range, Trends uses complete days, and navigation carries the intended scope. |
| Scheduled and next-dose reminders | [Scheduled reminders](../../AsNeededTests/ScheduledReminderReliabilityTests.swift), [notification recording](../../AsNeededTests/NotificationDoseLoggerTests.swift), [availability plans](../../AsNeededTests/MedicationAvailabilityNotificationPlannerTests.swift) | On an authorized test device, verify delivery, private names, action outcomes, and removal of obsolete requests. |
| Widgets, Shortcuts, and Watch | [Widget routing](../../AsNeededTests/WidgetScopedNavigationTests.swift), [Shortcut logging](../../AsNeededTests/LogMedicationIntentTests.swift), [Watch messages](../../AsNeededTests/WatchMessageValidationTests.swift) | Check widget links open review, Shortcuts target the selected medication, and Watch distinguishes queued from saved. |
| Backup, restore, and upgrade | [Import rollback](../../AsNeededTests/DataImportIntegrityTests.swift), [upgrade fixtures](../../AsNeededTests/Fixtures/Upgrades/README.md), and the rehearsal below | Confirm identifiers, stock, fractional doses, notes, refill dates, and settings after an in-place upgrade and two launches. |
| Accessibility, localization, and optional purchases | [Contrast](../../AsNeededTests/ColorContrastTests.swift), [bundled resources](../../AsNeededTests/LocalizationResourceTests.swift), [configuration fallback](../../AsNeededTests/RevenueCatConfigurationTests.swift) | Check large text, VoiceOver, and RTL on a device. Confirm tracking works when purchase configuration is unavailable. |

The initial 1.2-to-1.3 rehearsal exposed a saved-order mismatch between native preference arrays written by backups and the JSON string written by the medication list. The compatibility fix uses the existing key and accepts both representations. [The order regression](../../AsNeededTests/MedicationOrderCompatibilityTests.swift) exercises both encodings.

The known product differences already in the 1.3 beta are year and custom ranges in History and Trends, and normal confirmation for explicit past doses. Recent backdated entries still count at the recorded time when they fall within the applicable window. These differences have explicit tests. Any other observed difference needs a bug fix or a maintainer decision.

## Simulator upgrade rehearsal

From the repo root, with an iPhone 17 compatible iOS simulator runtime installed:

```bash
xcrun simctl list runtimes iOS
./scripts/upgrade-rehearsal/run.sh HEAD com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

The script exports the pinned tag and the requested candidate commit into disposable source trees. It creates a new simulator and copies the test harness into each test target. The 1.2 app imports the existing synthetic fixture through the real production store and exports a baseline. The 1.3 app replaces it on the same simulator, reads that store after each launch, and restores the original backup into a separate test store. The harness compares medication and event records, including IDs, fractional quantities, dates, notes and refill information, plus selected settings and the persisted notification urgency preference. It requires a matching simulator name and an empty 1.2 store before seeding.

Keep the source and result bundles from the printed temporary directory with the release evidence. Report the two source revisions, Xcode and runtime versions, and all three results. The harness leaves the dedicated simulator shut down for inspection. Remove that dedicated simulator when its evidence is no longer needed.

For a physical rehearsal, use a dedicated iPhone with an empty AsNeeded store and an authorized path to the verified 1.2 build. Seed and export synthetic records, install the candidate without uninstalling, and compare exports after two separate launches. Check scheduled reminder delivery and Watch separately. A simulator run and an export fixture do not establish actual iPhone or Watch behavior. Keep device identifiers and private records out of Git.

### Settings import lockout

On November 10, 2026, a settings-inclusive import on build 329 left a pending undo journal that failed to replay at launch. Both SQLite databases passed their health checks. The device trace reached database rollback and stopped before the journal was removed. The device also logged that iOS rejected an all-users lookup for the app-group preferences. That log identifies a scope error, but does not identify which preference call originally failed during the import.

Local build 330 allowed recovery to finish by skipping preference synchronization when the journal's saved values already matched. The user then imported records with **Keep Settings**. The app confirmed the import, and History displayed the recovered records after another cold launch. This verified recovery on that device. The settings-inclusive path still needed its own fix.

Before promoting a build with changes to import, export, or journal replay, rehearse an in-place upgrade on a physical iPhone with synthetic data. Include a safety profile so the import touches both the app and shared preferences. Verify an unchanged settings import, an import with changed settings, and an import with **Keep Settings**. Export after two cold launches and compare record IDs and settings with the expected result. Exercise the interrupted-import fixture before promotion. Verify that a failed preference write leaves the previous records recoverable and that a prior journal with already-restored preferences can finish replay. For an affected install, preserve the app container and journal through the upgrade. Confirm History before choosing whether to import a backup, since the normal import replaces current records.

## Transaction interruption rehearsal

```bash
./scripts/interruption-rehearsal/run.sh HEAD com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

The harness uses a new simulator and separate synthetic stores for dose, Undo and replacement import. It stops the hosted test process at an existing persistence checkpoint, then relaunches twice to check records, stock, preferences and journal cleanup. Keep the printed result directory private. The interruption phases are expected to exit unsuccessfully after writing their checkpoint markers. The two reopen phases must pass.

## Locked-device check

Use a dedicated iPhone with synthetic records and, for Watch transport, a paired test Watch. Export a baseline. Reboot the phone, leave it locked before first unlock, and try an already scheduled reminder action and an existing Watch dose action when available. Record whether iOS delivers or defers each action. Unlock and export again. A deferred or rejected action leaves the baseline intact. A committed action appears once with its stock change, including after a second launch. Record OS and build, delivery, save acknowledgement and comparison separately. An injected storage failure or simulator lock does not establish first-unlock behavior on hardware.

## Long history performance

Run the [long-history workload](../../AsNeededTests/LongHistoryWorkloadTests.swift) with `TEST_RAW_OUTPUT=1 TEST_PARALLEL_ENABLED=NO ./scripts/test-parallel.sh LongHistoryWorkloadTests`. It imports 5,844 synthetic doses over 1,461 days, with active and archived medications and notes, then measures store open, History filtering, Trends totals, and JSON export. The test asserts the results and records cold and warm computation times. Use the same Xcode, configuration, and runtime or device for comparisons. For an older iPhone, select the authorized phone as the Xcode test destination and run only `LongHistoryWorkloadTests` from the Test navigator, or supply its explicit `TEST_DESTINATION='platform=iOS,id=…'` to the same command. The workload creates a separate store.

Capture three runs on the reference simulator and three on an older supported physical iPhone before setting a release baseline. Use the median for each operation. Investigate a repeatable median increase above 25% and 20 ms for the same workload. This is a review threshold, since simulator timing varies with host load. Measure cold app launch separately from store open. In Instruments, use the App Launch template with the same build configuration and seeded test device. Terminate the app before each recording, record launch through the first usable medication screen, and keep three traces outside Git.

The November 8, 2026 simulator reference used Xcode 27.2 (27B52), iPhone 17 / iOS 26.5, and the 1.3 maintenance candidate. Median of three Debug runs:

| Operation | Median |
| --- | ---: |
| Open and recover the store | 351.4 ms |
| First History grouping | 14.1 ms |
| Repeated History grouping | 0.006 ms |
| First two-year Trends calculation | 38.4 ms |
| Repeated Trends calculation | 0.301 ms |
| Export to JSON | 355.1 ms |

These are simulator samples of domain operations. The initial App Launch trace on the synthetic upgrade simulator produced no usable lifecycle timing. A cold-launch baseline and physical-device timings are pending.

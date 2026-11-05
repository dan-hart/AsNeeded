# Features and business rules

This is the current behavior map for 1.3.0 development, not a list of future ideas. Follow prescription/care instructions: the app records information and evaluates saved settings; it does not establish that a dose is medically safe. Changes to these rules require an explicit product decision and regression coverage.

Drift anchors this document to a selected implementation/test set. A fresh anchor means the referenced content has not changed since review; it does not prove the prose is true. The tests below provide behavioral evidence.

## Dose recording, stock, and Undo

<a id="dose-001"></a>

**DOSE-001 — Valid recording.** Record the explicitly selected medication and its finite positive quantity/unit.

<a id="dose-002"></a>

**DOSE-002 — Atomic commit.** Dose and stock effects must commit together or remain recoverable.

<a id="dose-003"></a>

**DOSE-003 — Exact Undo.** Undo and confirmation ownership belong to the exact committed event.

Record the selected medication, finite positive amount, unit, and effective dose timestamp. A committed dose and its stock change form one recoverable transaction. Canceling or failing a save must not leave half a record. Undo targets the exact committed event and restores its stock contribution; an old operation or toast timer must not replace or clear a newer confirmation.

Implementation: [DataStore](AsNeeded/Services/Persistence/DataStore.swift), [transactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift), [confirmation owner](AsNeeded/Features/Medication/ViewModels/MedicationListViewModel.swift). Tests: [atomic persistence](AsNeededTests/AtomicPersistenceTests.swift), [Undo races](AsNeededTests/QuickLogUndoRaceTests.swift), [confirmations](AsNeededTests/DoseConfirmationTests.swift).

## Now and backdated entries

<a id="dose-004"></a>

**DOSE-004 — Effective time.** Now uses submission time; explicit past entries retain their selected timestamp and ordinary confirmation.

Now resolves to submission time even if the form has been open for a while. Explicit past selections retain their selected timestamp and show ordinary Dose logged feedback with Undo rather than replaying historical limit warnings. Recent backdated doses still contribute to a current interval/rolling window when their actual timestamp falls inside it; old expired entries do not restart the current window.

Implementation: [Log Dose](AsNeeded/Features/Medication/LogDoseView.swift), [feedback](AsNeeded/Services/QuickLogFeedbackService.swift). Tests: [backdating](AsNeededTests/BackdatedDoseLoggingTests.swift), [confirmations](AsNeededTests/DoseConfirmationTests.swift).

## Optional saved guidance

<a id="guidance-001"></a>

**GUIDANCE-001 — Optional recorded guidance.** Missing settings are distinct from eligibility; quantity windows use recorded dose times and the medication unit.

Minimum interval and maximum total quantity over a rolling 24 hours are optional. Quantity limits use the medication's unit, not a count of log events. Evaluate saved settings against recorded dose times and compatible finite quantities; do not treat absent configuration/history or invalid data as medical clearance. A recent dose is counted at its recorded date, not its insertion date. Safety feedback is descriptive and cannot account for unrecorded doses.

Implementation: [guidance](AsNeeded/Services/MedicationDoseGuidanceService.swift). Tests: [guidance boundaries](AsNeededTests/MedicationDoseGuidanceServiceTests.swift), [backdating](AsNeededTests/BackdatedDoseLoggingTests.swift).

## History and Trends dates

<a id="date-001"></a>

**DATE-001 — History versus Trends.** History can include today; Trends ends yesterday.

<a id="date-002"></a>

**DATE-002 — Calendar ranges.** Year/custom ranges follow local calendar boundaries and preserve selection on cancellation and navigation.

History defaults to All Time; period filters include today. Trends uses complete local calendar days ending yesterday. Both support calendar-year and custom ranges, and custom cancellation preserves the current selection. Calendar years are not assumed to equal 365 days. Trends-to-History navigation preserves the selected medication and exact date range; jumping outside a History filter can clear that date filter without clearing the medication.

Implementation: [range model](AsNeeded/Features/Medication/ViewModels/TrendsDateRange.swift), [History filter](AsNeeded/Features/Medication/ViewModels/HistoryDateFilter.swift). Tests: [range boundaries](AsNeededTests/TrendsDateRangeTests.swift), [History filters and handoff](AsNeededTests/HistoryDateFilterTests.swift).

## Reminders and notification actions

<a id="reminder-001"></a>

**REMINDER-001 — Reconciliation.** Deleted medications must not regain scheduled requests, and successful logging acknowledges delivered reminders.

<a id="notification-001"></a>

**NOTIFICATION-001 — Explicit action.** Opening a notification does not save; explicit Log is authenticated, policy-checked, idempotent, and reports the actual outcome.

Scheduled reminders and optional next-dose alerts have different purposes. Reconciliation uses current saved medications/settings and must not recreate reminders for deleted medications. Successful logging acknowledges the relevant delivered reminders. Respect the notification-name privacy setting and per-medication urgency choice.

A notification body tap navigates without saving. Explicit authenticated Log can record the prescribed/default dose when the saved-guidance policy permits it, using an idempotent identity. Otherwise it offers review and does not claim a dose was logged. Success/failure feedback must describe the actual result. Skip dismisses that occurrence without changing stock or dose history.

Implementation: [actions](AsNeeded/Services/MedicationNotificationAction.swift), [background logger](AsNeeded/Services/NotificationDoseLogger.swift), [notification manager](AsNeeded/Services/NotificationManager.swift). Tests: [actions](AsNeededTests/MedicationNotificationActionTests.swift), [background policy and recording](AsNeededTests/NotificationDoseLoggerTests.swift), [reconciliation](AsNeededTests/NotificationManagerTests.swift).

## Import, backup, and upgrade preservation

<a id="data-001"></a>

**DATA-001 — Recoverable import.** Import must preserve a complete recoverable snapshot across failures.

<a id="backup-001"></a>

**BACKUP-001 — Cancelable, serialized backup.** Slow folder work stays off the main actor and cancellation must not strand setup or overlap operations.

Prepare and validate imported content before committing; medication/event/settings changes must remain recoverable if a phase fails. Preserve supported older data and retired-setting decoding without reintroducing retired UI. Automatic backups must avoid overlapping work, keep slow folder operations off the main actor, and leave setup recoverable after cancellation.

Implementation: [transactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift), [backup manager](AsNeeded/Services/AutomaticBackupManager.swift). Tests: [import rollback](AsNeededTests/DataImportIntegrityTests.swift), [backup cancellation/concurrency](AsNeededTests/AutomaticBackupStabilizationTests.swift), [retired settings](AsNeededTests/RetiredQuestionSettingsTests.swift). Durable path/migration constraints live in [storage guidelines](docs/DATA_STORAGE_GUIDELINES.md).

## Widgets, Watch, accessibility, and privacy

Widgets route to the intended medication and respect their selected scope. The Watch reports transport and save outcomes accurately. Medication names, amounts, units, and actions must remain usable with Dynamic Type, custom accessible fonts, RTL, and assistive technology. Demo Mode is temporary presentation redaction, not encryption or a persisted privacy preference. Purchases do not unlock tracking features.

References: [widget integration](docs/WIDGETS_INTEGRATION.md), [design/accessibility rules](ai-rules/design-accessibility.md), [privacy policy](PRIVACY.md). Relevant tests: [widget routing](AsNeededTests/WidgetNavigationRouteTests.swift), [widget projections](AsNeededTests/WidgetExperienceProjectionTests.swift), [Demo Mode](AsNeededTests/DemoModeStateTests.swift), and the standalone Watch availability harness documented in [scripts](scripts/README.md).

## Shared contracts and upgrade fixtures

<a id="platform-001"></a>

**PLATFORM-001 — Stable stored and wire identifiers.** App Group, database names, the shared safety-profile preference, and Watch message fields retain their existing values across all compiling targets. [SharedPlatformContracts](AsNeeded/Shared/SharedPlatformContracts.swift) is the common source. Existing routing remains in [WidgetNavigationRoute](AsNeeded/Services/WidgetNavigationRoute.swift). This centralization does not move containers, rename databases, change schema versions, or grant Watch access to phone storage.

<a id="upgrade-001"></a>

**UPGRADE-001 — Frozen supported export shapes.** Versioned [synthetic upgrade fixtures](AsNeededTests/Fixtures/Upgrades/README.md) preserve known supported older shapes. Import/reopen/re-export, repeated-import semantics, and rollback/recovery must retain their records. A fixture's recorded hash is immutable; add a new fixture rather than rewriting history. These are schema-derived synthetic examples, not captures of a released app's private records.

## Rule traceability

IDs are permanent references: do not renumber or reuse them when a rule is retired. Add a new ID for a new behavior, document intentional changes, and keep the implementation/test mapping current. Drift flags changes to selected referenced files; it does not interpret the ID or replace execution of the regression.

| Rule | Implementation | Named regression evidence |
| --- | --- | --- |
| [DOSE-001](#dose-001) | [Recording policy](AsNeeded/Services/WidgetDoseRecordingPolicy.swift) | [WatchMessageValidationTests](AsNeededTests/WatchMessageValidationTests.swift), [DataStoreTests](AsNeededTests/DataStoreTests.swift) |
| [DOSE-002](#dose-002) | [Transactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift) | [AtomicPersistenceTests](AsNeededTests/AtomicPersistenceTests.swift): `failedDoseSaveRestoresBothStores`, `interruptedSaveRecoversAcrossInstances` |
| [DOSE-003](#dose-003) | [Confirmation owner](AsNeeded/Features/Medication/ViewModels/MedicationListViewModel.swift) | [QuickLogUndoRaceTests](AsNeededTests/QuickLogUndoRaceTests.swift): `replacementToastSurvivesUndo`, `repeatUndoDoesNotOverlap` |
| [DOSE-004](#dose-004) | [Log Dose](AsNeeded/Features/Medication/LogDoseView.swift) | [BackdatedDoseLoggingTests](AsNeededTests/BackdatedDoseLoggingTests.swift): `nowRemainsCurrent`, `recentBacklogStillCountsAtActualTime` |
| [GUIDANCE-001](#guidance-001) | [Guidance service](AsNeeded/Services/MedicationDoseGuidanceService.swift) | [Guidance tests](AsNeededTests/MedicationDoseGuidanceServiceTests.swift), [backdated window tests](AsNeededTests/BackdatedDoseLoggingTests.swift) |
| [DATE-001](#date-001) | [Range model](AsNeeded/Features/Medication/ViewModels/TrendsDateRange.swift) | [HistoryDateFilterTests](AsNeededTests/HistoryDateFilterTests.swift): `historyAndTrendsBounds` |
| [DATE-002](#date-002) | [History filter](AsNeeded/Features/Medication/ViewModels/HistoryDateFilter.swift) | [TrendsDateRangeTests](AsNeededTests/TrendsDateRangeTests.swift): `yearPresets`, `customInclusive`; [HistoryDateFilterTests](AsNeededTests/HistoryDateFilterTests.swift): `trendsRangeInHistory` |
| [REMINDER-001](#reminder-001) | [Notification manager](AsNeeded/Services/NotificationManager.swift) | [NotificationManagerTests](AsNeededTests/NotificationManagerTests.swift), [widget reconciliation](AsNeededTests/WidgetNotificationReconciliationTests.swift) |
| [NOTIFICATION-001](#notification-001) | [Notification logger](AsNeeded/Services/NotificationDoseLogger.swift) | [NotificationDoseLoggerTests](AsNeededTests/NotificationDoseLoggerTests.swift): `replay`, `requiresReview`, `failedSave` |
| [DATA-001](#data-001) | [Transactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift) | [DataImportIntegrityTests](AsNeededTests/DataImportIntegrityTests.swift), [UpgradeFixtureTests](AsNeededTests/UpgradeFixtureTests.swift) |
| [BACKUP-001](#backup-001) | [Backup manager](AsNeeded/Services/AutomaticBackupManager.swift) | [AutomaticBackupStabilizationTests](AsNeededTests/AutomaticBackupStabilizationTests.swift) |
| [PLATFORM-001](#platform-001) | [Shared identifiers](AsNeeded/Shared/SharedPlatformContracts.swift) | [SharedPlatformContractTests](AsNeededTests/SharedPlatformContractTests.swift), [WatchMessageValidationTests](AsNeededTests/WatchMessageValidationTests.swift) |
| [UPGRADE-001](#upgrade-001) | [Import API](AsNeeded/Services/Persistence/DataStore.swift) | [UpgradeFixtureTests](AsNeededTests/UpgradeFixtureTests.swift): `importReopenAndReexport`, `repeatedImports`, rollback/recovery cases |

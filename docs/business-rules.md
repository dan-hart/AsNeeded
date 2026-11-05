# Features and business rules

This is the current behavior map for 1.3.0 development, not a list of future ideas. Follow prescription/care instructions: the app records information and evaluates saved settings; it does not establish that a dose is medically safe. Changes to these rules require an explicit product decision and regression coverage.

Drift anchors this document to a selected implementation/test set. A fresh anchor means the referenced content has not changed since review; it does not prove the prose is true. The tests below provide behavioral evidence.

## Dose recording, stock, and Undo

Record the selected medication, finite positive amount, unit, and effective dose timestamp. A committed dose and its stock change form one recoverable transaction. Canceling or failing a save must not leave half a record. Undo targets the exact committed event and restores its stock contribution; an old operation or toast timer must not replace or clear a newer confirmation.

Implementation: [DataStore](../AsNeeded/Services/Persistence/DataStore.swift), [transactions](../AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift), [confirmation owner](../AsNeeded/Medication/ViewModels/MedicationListViewModel.swift). Tests: [atomic persistence](../AsNeededTests/AtomicPersistenceTests.swift), [Undo races](../AsNeededTests/QuickLogUndoRaceTests.swift), [confirmations](../AsNeededTests/DoseConfirmationTests.swift).

## Now and backdated entries

Now resolves to submission time even if the form has been open for a while. Explicit past selections retain their selected timestamp and show ordinary Dose logged feedback with Undo rather than replaying historical limit warnings. Recent backdated doses still contribute to a current interval/rolling window when their actual timestamp falls inside it; old expired entries do not restart the current window.

Implementation: [Log Dose](../AsNeeded/Medication/LogDoseView.swift), [feedback](../AsNeeded/Services/QuickLogFeedbackService.swift). Tests: [backdating](../AsNeededTests/BackdatedDoseLoggingTests.swift), [confirmations](../AsNeededTests/DoseConfirmationTests.swift).

## Optional saved guidance

Minimum interval and maximum total quantity over a rolling 24 hours are optional. Quantity limits use the medication's unit, not a count of log events. Evaluate saved settings against recorded dose times and compatible finite quantities; do not treat absent configuration/history or invalid data as medical clearance. A recent dose is counted at its recorded date, not its insertion date. Safety feedback is descriptive and cannot account for unrecorded doses.

Implementation: [guidance](../AsNeeded/Services/MedicationDoseGuidanceService.swift). Tests: [guidance boundaries](../AsNeededTests/MedicationDoseGuidanceServiceTests.swift), [backdating](../AsNeededTests/BackdatedDoseLoggingTests.swift).

## History and Trends dates

History defaults to All Time; period filters include today. Trends uses complete local calendar days ending yesterday. Both support calendar-year and custom ranges, and custom cancellation preserves the current selection. Calendar years are not assumed to equal 365 days. Trends-to-History navigation preserves the selected medication and exact date range; jumping outside a History filter can clear that date filter without clearing the medication.

Implementation: [range model](../AsNeeded/Medication/ViewModels/TrendsDateRange.swift), [History filter](../AsNeeded/Medication/ViewModels/HistoryDateFilter.swift). Tests: [range boundaries](../AsNeededTests/TrendsDateRangeTests.swift), [History filters and handoff](../AsNeededTests/HistoryDateFilterTests.swift).

## Reminders and notification actions

Scheduled reminders and optional next-dose alerts have different purposes. Reconciliation uses current saved medications/settings and must not recreate reminders for deleted medications. Successful logging acknowledges the relevant delivered reminders. Respect the notification-name privacy setting and per-medication urgency choice.

A notification body tap navigates without saving. Explicit authenticated Log can record the prescribed/default dose when the saved-guidance policy permits it, using an idempotent identity. Otherwise it offers review and does not claim a dose was logged. Success/failure feedback must describe the actual result. Skip dismisses that occurrence without changing stock or dose history.

Implementation: [actions](../AsNeeded/Services/MedicationNotificationAction.swift), [background logger](../AsNeeded/Services/NotificationDoseLogger.swift), [notification manager](../AsNeeded/Services/NotificationManager.swift). Tests: [actions](../AsNeededTests/MedicationNotificationActionTests.swift), [background policy and recording](../AsNeededTests/NotificationDoseLoggerTests.swift), [reconciliation](../AsNeededTests/NotificationManagerTests.swift).

## Import, backup, and upgrade preservation

Prepare and validate imported content before committing; medication/event/settings changes must remain recoverable if a phase fails. Preserve supported older data and retired-setting decoding without reintroducing retired UI. Automatic backups must avoid overlapping work, keep slow folder operations off the main actor, and leave setup recoverable after cancellation.

Implementation: [transactions](../AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift), [backup manager](../AsNeeded/Services/AutomaticBackupManager.swift). Tests: [import rollback](../AsNeededTests/DataImportIntegrityTests.swift), [backup cancellation/concurrency](../AsNeededTests/AutomaticBackupStabilizationTests.swift), [retired settings](../AsNeededTests/RetiredQuestionSettingsTests.swift). Durable path/migration constraints live in [storage guidelines](DATA_STORAGE_GUIDELINES.md).

## Widgets, Watch, accessibility, and privacy

Widgets route to the intended medication and respect their selected scope. The Watch reports transport and save outcomes accurately. Medication names, amounts, units, and actions must remain usable with Dynamic Type, custom accessible fonts, RTL, and assistive technology. Demo Mode is temporary presentation redaction, not encryption or a persisted privacy preference. Purchases do not unlock tracking features.

References: [widget integration](WIDGETS_INTEGRATION.md), [design/accessibility rules](../ai-rules/design-accessibility.md), [privacy policy](../PRIVACY.md). Relevant tests: [widget routing](../AsNeededTests/WidgetNavigationRouteTests.swift), [widget projections](../AsNeededTests/WidgetExperienceProjectionTests.swift), [Demo Mode](../AsNeededTests/DemoModeStateTests.swift), and the standalone Watch availability harness documented in [scripts](../scripts/README.md).

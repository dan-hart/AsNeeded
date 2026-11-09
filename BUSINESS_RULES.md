# Features and business rules

This is the current behavior map for 1.3.0 development, not a list of future ideas. Follow prescription/care instructions: the app records information and evaluates saved settings; it does not establish that a dose is medically safe. Changes to these rules require an explicit human maintainer decision and regression coverage under the [Drift review policy](docs/drift.md#required-human-review).

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

Turning off medication names replaces pending named reminders and next-dose alerts with generic content and removes app-owned named deliveries. Preserve the schedule and urgency when the system accepts the replacement. If a generic replacement is refused, remove the named request.

A notification body tap navigates without saving. Explicit authenticated Log can record the prescribed/default dose when the saved-guidance policy permits it, using an idempotent identity. Otherwise it offers review and does not claim a dose was logged. Success/failure feedback must describe the actual result. Skip dismisses that occurrence without changing stock or dose history.

Implementation: [actions](AsNeeded/Services/MedicationNotificationAction.swift), [background logger](AsNeeded/Services/NotificationDoseLogger.swift), [notification manager](AsNeeded/Services/NotificationManager.swift). Tests: [actions](AsNeededTests/MedicationNotificationActionTests.swift), [background policy and recording](AsNeededTests/NotificationDoseLoggerTests.swift), [reconciliation](AsNeededTests/NotificationManagerTests.swift).

## Import, backup, and upgrade preservation

<a id="data-001"></a>

**DATA-001 — Recoverable import.** Import must preserve a complete recoverable snapshot across failures.

<a id="backup-001"></a>

**BACKUP-001 — Cancelable, serialized backup.** Slow folder work stays off the main actor and cancellation must not strand setup or overlap operations.

Prepare and validate imported content before committing; medication/event/settings changes must remain recoverable if a phase fails. Preserve supported older data and retired-setting decoding without reintroducing retired UI. Automatic backups must avoid overlapping work, keep slow folder operations off the main actor, and leave setup recoverable after cancellation.

Reject conflicting duplicate identities inside one import before changing records or preferences. Temporary storage access failures preserve existing files and permit retry. A failed automatic backup retains the last validated backup and its success timestamp.

Implementation: [transactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift), [backup manager](AsNeeded/Services/AutomaticBackupManager.swift). Tests: [import rollback](AsNeededTests/DataImportIntegrityTests.swift), [backup cancellation/concurrency](AsNeededTests/AutomaticBackupStabilizationTests.swift), [retired settings](AsNeededTests/RetiredQuestionSettingsTests.swift). Durable path/migration constraints live in [storage guidelines](docs/DATA_STORAGE_GUIDELINES.md).

## Widgets and Watch

<a id="widget-001"></a>

**WIDGET-001 — Navigation opens review.** A widget link opens the intended in-app destination and does not save a dose. A Lock Screen dose link opens the selected medication’s form. Invalid or unavailable dose targets cannot fall back to a different medication.

<a id="widget-002"></a>

**WIDGET-002 — Scope and name visibility.** Widget configuration carries the selected medication and name visibility into the projection. An unavailable explicit selection stays unavailable. Usage totals use complete local days and only combine compatible amounts.

<a id="watch-001"></a>

**WATCH-001 — Acknowledged saves.** The Watch distinguishes a queued transfer from a confirmed save. Dose and quantity actions show success only after the phone acknowledges persistence. Dose retries from the same form preserve the event identity and timestamp.

An acknowledged Watch event ID stays consumed after its dose is deleted, including across relaunch. A delayed replay leaves history and stock intact.

## Accessibility, localization, privacy, and optional support

<a id="accessibility-001"></a>

**ACCESSIBILITY-001 — Readable medication controls.** Critical medication names can wrap, custom fonts respect Dynamic Type, and filled medication actions use the configured foreground policy for standard and increased contrast. Keep names, amounts, and actions usable with assistive technology. Layout and VoiceOver behavior need device review in addition to the automated checks below.

<a id="locale-001"></a>

**LOCALE-001 — Localized medication presentation.** The app, widget, and Watch ship resources for supported locales. Use localized quantities, units, and decimal input and preserve readability in right-to-left layouts. The [main strings catalog](AsNeeded/Localizable.xcstrings) exceeds the pinned Drift version’s file size limit. The bundled-resource tests check locale bundles and representative strings.

<a id="privacy-001"></a>

**PRIVACY-001 — Session-only Demo Mode.** Demo Mode obscures medication names in the app’s presentation, starts off on a new launch, and requires confirmation to turn off. It does not modify stored names, encrypt data, or change what other surfaces show.

<a id="support-001"></a>

**SUPPORT-001 — Optional purchases.** Tips and recurring support do not unlock medication tracking. Without purchase configuration, product loading returns no products and purchase or restore attempts explain that support is unavailable. The configuration regression exercises these paths.

<a id="search-001"></a>

**SEARCH-001 — Current medication query owns results.** Publish results and recent search entries for the current query. Clearing, closing, or superseding a query invalidates its outstanding result. Manual medication entry remains available offline.

Related references: [widget integration](docs/WIDGETS_INTEGRATION.md), [design and accessibility guidance](ai-rules/design-accessibility.md), and [privacy policy](PRIVACY.md).

## Shared contracts and upgrade fixtures

<a id="platform-001"></a>

**PLATFORM-001 — Stable stored and wire identifiers.** App Group, database names, the shared safety-profile preference, and Watch message fields retain their existing values across all compiling targets. [SharedPlatformContracts](AsNeeded/Shared/SharedPlatformContracts.swift) is the common source. Existing routing remains in [WidgetNavigationRoute](AsNeeded/Services/WidgetNavigationRoute.swift). This centralization does not move containers, rename databases, change schema versions, or grant Watch access to phone storage.

<a id="upgrade-001"></a>

**UPGRADE-001 — Frozen supported export shapes.** Versioned [synthetic upgrade fixtures](AsNeededTests/Fixtures/Upgrades/README.md) preserve known supported older shapes. Import/reopen/re-export, repeated-import semantics, and rollback/recovery must retain their records. A fixture's recorded hash is immutable; add a new fixture rather than rewriting history. These are schema-derived synthetic examples. The [tagged release rehearsal](docs/maintenance/release-regression.md#simulator-upgrade-rehearsal) checks the persisted store across the actual simulator app replacement.

The [1.2 regression baseline](docs/maintenance/release-regression.md) records workflows to preserve, intentional beta differences, and release checks that require a device.

## Rule traceability

IDs are permanent references. Do not renumber or reuse retired IDs. Add a new ID for a new behavior and document intentional changes. Each file linked in the traceability table has a Drift binding. The CI check verifies that every rule is represented and its references are bound. Drift flags file changes for review and the listed tests exercise behavior.

| Rule | Implementation | Regression evidence |
| --- | --- | --- |
| [DOSE-001](#dose-001) | [LogDoseView](AsNeeded/Features/Medication/LogDoseView.swift), [DoseAmountInput](AsNeeded/Features/Medication/DoseAmountInput.swift), [LogDosePickerModel](AsNeeded/Features/Medication/LogDosePickerModel.swift), [FloatingLogDoseButton](AsNeeded/Views/Components/FloatingLogDoseButton.swift), [WidgetDoseRecordingPolicy](AsNeeded/Services/WidgetDoseRecordingPolicy.swift), [MedicationPersistenceTransactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift), [LogMedicationIntent](AsNeeded/Services/Intents/LogMedicationIntent.swift) | [DoseEntryRegression tests](AsNeededTests/DoseEntryRegressionTests.swift), [FloatingDoseTarget tests](AsNeededTests/FloatingDoseTargetTests.swift), [LogDosePickerModel tests](AsNeededTests/LogDosePickerModelTests.swift), [DataStore tests](AsNeededTests/DataStoreTests.swift), [WatchMessageValidation tests](AsNeededTests/WatchMessageValidationTests.swift), [Dose recording surfaces](AsNeededTests/DoseRecordingSurfaceTests.swift) |
| [DOSE-002](#dose-002) | [DataStore](AsNeeded/Services/Persistence/DataStore.swift), [MedicationPersistenceTransactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift) | [AtomicPersistence tests](AsNeededTests/AtomicPersistenceTests.swift): `failedDoseSaveRestoresBothStores`, `interruptedSaveRecoversAcrossInstances`, [DoseStockStability tests](AsNeededTests/DoseStockStabilityTests.swift), [Interruption rehearsal](scripts/interruption-rehearsal/TransactionInterruptionRehearsal.swift) |
| [DOSE-003](#dose-003) | [MedicationListViewModel](AsNeeded/Features/Medication/ViewModels/MedicationListViewModel.swift), [QuickLogToastView](AsNeeded/Views/Components/QuickLogToastView.swift), [QuickLogFeedbackService](AsNeeded/Services/QuickLogFeedbackService.swift) | [QuickLogUndoRace tests](AsNeededTests/QuickLogUndoRaceTests.swift): `replacementToastSurvivesUndo`, `repeatUndoDoesNotOverlap`, [DoseConfirmation tests](AsNeededTests/DoseConfirmationTests.swift), [QuickLogFeedbackService tests](AsNeededTests/QuickLogFeedbackServiceTests.swift) |
| [DOSE-004](#dose-004) | [LogDoseView](AsNeeded/Features/Medication/LogDoseView.swift), [QuickLogFeedbackService](AsNeeded/Services/QuickLogFeedbackService.swift) | [BackdatedDoseLogging tests](AsNeededTests/BackdatedDoseLoggingTests.swift): `nowRemainsCurrent`, `recentBacklogStillCountsAtActualTime`, [DoseConfirmation tests](AsNeededTests/DoseConfirmationTests.swift) |
| [GUIDANCE-001](#guidance-001) | [MedicationDoseGuidanceService](AsNeeded/Services/MedicationDoseGuidanceService.swift), [MedicationDoseLimitMigration](AsNeeded/Services/MedicationDoseLimitMigration.swift), [GetNextDoseIntent](AsNeeded/Services/Intents/GetNextDoseIntent.swift), [WidgetDoseRecordingPolicy](AsNeeded/Services/WidgetDoseRecordingPolicy.swift) | [MedicationDoseGuidanceService tests](AsNeededTests/MedicationDoseGuidanceServiceTests.swift), [BackdatedDoseLogging tests](AsNeededTests/BackdatedDoseLoggingTests.swift), [MedicationDoseLimitMigration tests](AsNeededTests/MedicationDoseLimitMigrationTests.swift), [GetNextDoseIntent tests](AsNeededTests/GetNextDoseIntentTests.swift), [WidgetDoseRegression tests](AsNeededTests/WidgetDoseRegressionTests.swift), [Calendar surface regressions](AsNeededTests/CalendarSurfaceRegressionTests.swift) |
| [DATE-001](#date-001) | [HistoryDateFilter](AsNeeded/Features/Medication/ViewModels/HistoryDateFilter.swift), [TrendsDateRange](AsNeeded/Features/Medication/ViewModels/TrendsDateRange.swift), [MedicationHistoryViewModel](AsNeeded/Features/Medication/ViewModels/MedicationHistoryViewModel.swift), [MedicationTrendsViewModel](AsNeeded/Features/Medication/ViewModels/MedicationTrendsViewModel.swift) | [HistoryDateFilter tests](AsNeededTests/HistoryDateFilterTests.swift): `historyAndTrendsBounds`, [TrendsDateRange tests](AsNeededTests/TrendsDateRangeTests.swift), [MedicationHistoryViewModel tests](AsNeededTests/MedicationHistoryViewModelTests.swift), [MedicationTrendsViewModel tests](AsNeededTests/MedicationTrendsViewModelTests.swift), [Calendar surface regressions](AsNeededTests/CalendarSurfaceRegressionTests.swift) |
| [DATE-002](#date-002) | [MedicationHistoryView](AsNeeded/Features/Medication/MedicationHistoryView.swift), [MedicationTrendsView](AsNeeded/Features/Medication/MedicationTrendsView.swift), [NavigationManager](AsNeeded/Services/NavigationManager.swift) | [HistoryDateFilter tests](AsNeededTests/HistoryDateFilterTests.swift): `trendsRangeInHistory`, [TrendsDateRange tests](AsNeededTests/TrendsDateRangeTests.swift): `yearPresets`, `customInclusive`, [Calendar surface regressions](AsNeededTests/CalendarSurfaceRegressionTests.swift) |
| [REMINDER-001](#reminder-001) | [NotificationManager](AsNeeded/Services/NotificationManager.swift), [MedicationReminderRequest](AsNeeded/Services/MedicationReminderRequest.swift), [MedicationNotificationUrgencyStore](AsNeeded/Services/MedicationNotificationUrgencyStore.swift), [MedicationAvailabilityNotificationPlanner](AsNeeded/Services/MedicationAvailabilityNotificationPlanner.swift), [WidgetDoseNotificationReconciler](AsNeeded/Services/WidgetDoseNotificationReconciler.swift) | [NotificationManager tests](AsNeededTests/NotificationManagerTests.swift), [ScheduledReminderReliability tests](AsNeededTests/ScheduledReminderReliabilityTests.swift), [MedicationReminderRequest tests](AsNeededTests/MedicationReminderRequestTests.swift), [ReminderPersistenceIntegration tests](AsNeededTests/ReminderPersistenceIntegrationTests.swift), [MedicationAvailabilityNotificationPlanner tests](AsNeededTests/MedicationAvailabilityNotificationPlannerTests.swift), [WidgetNotificationReconciliation tests](AsNeededTests/WidgetNotificationReconciliationTests.swift), [Calendar surface regressions](AsNeededTests/CalendarSurfaceRegressionTests.swift) |
| [NOTIFICATION-001](#notification-001) | [AppDelegate](AsNeeded/Services/AppDelegate.swift), [MedicationNotificationAction](AsNeeded/Services/MedicationNotificationAction.swift), [MedicationNotificationResponseHandler](AsNeeded/Services/MedicationNotificationResponseHandler.swift), [NotificationDoseLogger](AsNeeded/Services/NotificationDoseLogger.swift) | [MedicationNotificationAction tests](AsNeededTests/MedicationNotificationActionTests.swift), [NotificationDoseLogger tests](AsNeededTests/NotificationDoseLoggerTests.swift): `replay`, `requiresReview`, `failedSave`, [Dose recording surfaces](AsNeededTests/DoseRecordingSurfaceTests.swift), [NotificationManager tests](AsNeededTests/NotificationManagerTests.swift) |
| [DATA-001](#data-001) | [DataStore](AsNeeded/Services/Persistence/DataStore.swift), [MedicationPersistenceTransactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift), [AppSettings](AsNeeded/Models/AppSettings.swift), [Medication order preference](AsNeeded/Extensions/AppStorage+Array.swift), [Storage health checker](AsNeeded/Services/Persistence/StorageHealthChecker.swift), [Migration coordinator](AsNeeded/Services/MigrationCoordinator.swift) | [DataImportIntegrity tests](AsNeededTests/DataImportIntegrityTests.swift), [SettingsExportImport tests](AsNeededTests/SettingsExportImportTests.swift), [RetiredQuestionSettings tests](AsNeededTests/RetiredQuestionSettingsTests.swift), [UpgradeFixture tests](AsNeededTests/UpgradeFixtureTests.swift), [Medication order compatibility](AsNeededTests/MedicationOrderCompatibilityTests.swift), [Storage integrity tests](AsNeededTests/DataIntegrityTests.swift), [Interruption rehearsal](scripts/interruption-rehearsal/TransactionInterruptionRehearsal.swift) |
| [BACKUP-001](#backup-001) | [AutomaticBackupManager](AsNeeded/Services/AutomaticBackupManager.swift), [AutomaticBackupViewModel](AsNeeded/Features/Settings/ViewModels/AutomaticBackupViewModel.swift), [AutomaticBackupView](AsNeeded/Features/Settings/AutomaticBackupView.swift) | [AutomaticBackupStabilization tests](AsNeededTests/AutomaticBackupStabilizationTests.swift), [AutomaticBackupManager tests](AsNeededTests/AutomaticBackupManagerTests.swift) |
| [WIDGET-001](#widget-001) | [WidgetNavigationRoute](AsNeeded/Services/WidgetNavigationRoute.swift), [NavigationManager](AsNeeded/Services/NavigationManager.swift), [MedicationView](AsNeeded/Features/Main/MedicationView.swift), [MedicationLockScreenWidget](AsNeededWidget/MedicationLockScreenWidget.swift), [WidgetExperienceViews](AsNeededWidget/WidgetExperienceViews.swift), [LogDoseWidgetIntent](AsNeededWidget/LogDoseWidgetIntent.swift) | [WidgetNavigationRoute tests](AsNeededTests/WidgetNavigationRouteTests.swift), [WidgetScopedNavigation tests](AsNeededTests/WidgetScopedNavigationTests.swift), [LegacyWidgetIntent tests](AsNeededTests/LegacyWidgetIntentTests.swift) |
| [WIDGET-002](#widget-002) | [WidgetExperienceConfiguration](AsNeededWidget/WidgetExperienceConfiguration.swift), [WidgetDataProvider](AsNeededWidget/WidgetDataProvider.swift), [WidgetExperienceViews](AsNeededWidget/WidgetExperienceViews.swift), [MedicationLockScreenWidget](AsNeededWidget/MedicationLockScreenWidget.swift), [WidgetExperienceProjection](AsNeeded/Services/WidgetExperienceProjection.swift) | [WidgetExperienceProjection tests](AsNeededTests/WidgetExperienceProjectionTests.swift), [Calendar surface regressions](AsNeededTests/CalendarSurfaceRegressionTests.swift) |
| [WATCH-001](#watch-001) | [WCSender](<WristAsNeeded Watch App/WCSender.swift>), [DoseLoggerView](<WristAsNeeded Watch App/DoseLoggerView.swift>), [QuantityEditorView](<WristAsNeeded Watch App/QuantityEditorView.swift>), [WCReceiver](AsNeeded/Services/WatchConnectivity/WCReceiver.swift), [Watch receipt key](AsNeeded/Constants/UserDefaultsKeys.swift) | [WatchMessageValidation tests](AsNeededTests/WatchMessageValidationTests.swift), [Dose recording surfaces](AsNeededTests/DoseRecordingSurfaceTests.swift) |
| [ACCESSIBILITY-001](#accessibility-001) | [Font+CustomFonts](AsNeeded/Extensions/Font+CustomFonts.swift), [FontFamily](AsNeeded/Constants/FontFamily.swift), [FontManager](AsNeeded/Services/FontManager.swift), [FontPreferencesView](AsNeeded/Features/Settings/FontPreferencesView.swift), [Color+Contrast](AsNeeded/Extensions/Color+Contrast.swift), [View+NoTruncate](AsNeeded/Extensions/View+NoTruncate.swift), [MedicationRowComponent](AsNeeded/Views/Components/MedicationRowComponent.swift) | [ColorContrast tests](AsNeededTests/ColorContrastTests.swift), [FontFamily tests](AsNeededTests/FontFamilyTests.swift), [FontManager tests](AsNeededTests/FontManagerTests.swift) |
| [LOCALE-001](#locale-001) | [InfoPlist](AsNeeded/InfoPlist.xcstrings), [AppShortcuts](AsNeeded/AppShortcuts.xcstrings), [project](AsNeeded.xcodeproj/project.pbxproj), [DoseAmountInput](AsNeeded/Features/Medication/DoseAmountInput.swift), [ANUnitConcept+Localization](AsNeeded/Extensions/ANUnitConcept+Localization.swift) | [LocalizationResource tests](AsNeededTests/LocalizationResourceTests.swift), [DoseEntryRegression tests](AsNeededTests/DoseEntryRegressionTests.swift), [Fractional quantity round trip](AsNeededTests/LocalizedFractionalQuantityTests.swift) |
| [PRIVACY-001](#privacy-001) | [DemoModeState](AsNeeded/Services/DemoModeState.swift), [DataPrivacyView](AsNeeded/Features/Settings/DataPrivacyView.swift), [MedicationRowComponent](AsNeeded/Views/Components/MedicationRowComponent.swift), [MedicationHistoryView](AsNeeded/Features/Medication/MedicationHistoryView.swift), [MedicationTrendsView](AsNeeded/Features/Medication/MedicationTrendsView.swift), [LogDoseView](AsNeeded/Features/Medication/LogDoseView.swift), [LogDosePickerSheet](AsNeeded/Views/Components/LogDosePickerSheet.swift), [QuickLogToastView](AsNeeded/Views/Components/QuickLogToastView.swift) | [DemoModeState tests](AsNeededTests/DemoModeStateTests.swift) |
| [SUPPORT-001](#support-001) | [RevenueCatManager](AsNeeded/Services/RevenueCatManager.swift), [SupportView](AsNeeded/Features/Support/SupportView.swift), [AboutView](AsNeeded/Features/Settings/AboutView.swift), [AsNeededApp](AsNeeded/AsNeededApp.swift) | [RevenueCatConfiguration tests](AsNeededTests/RevenueCatConfigurationTests.swift) |
| [SEARCH-001](#search-001) | [Medication search service](AsNeeded/Services/MedicationSearchService.swift), [Medication search field](AsNeeded/Views/Components/EnhancedMedicationSearchField.swift) | [Medication search regressions](AsNeededTests/MedicationSearchEnhancedTests.swift) |
| [PLATFORM-001](#platform-001) | [SharedPlatformContracts](AsNeeded/Shared/SharedPlatformContracts.swift), [MedicationPersistenceTransactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift), [WCReceiver](AsNeeded/Services/WatchConnectivity/WCReceiver.swift), [WCSender](<WristAsNeeded Watch App/WCSender.swift>), [project](AsNeeded.xcodeproj/project.pbxproj) | [SharedPlatformContract tests](AsNeededTests/SharedPlatformContractTests.swift), [WatchMessageValidation tests](AsNeededTests/WatchMessageValidationTests.swift) |
| [UPGRADE-001](#upgrade-001) | [DataStore](AsNeeded/Services/Persistence/DataStore.swift), [MedicationPersistenceTransactions](AsNeeded/Services/Persistence/MedicationPersistenceTransactions.swift), [upgrade-export-v1-no-settings](AsNeededTests/Fixtures/Upgrades/upgrade-export-v1-no-settings.json), [upgrade-export-v1-sparse-settings](AsNeededTests/Fixtures/Upgrades/upgrade-export-v1-sparse-settings.json), [upgrade-fixture-manifest](AsNeededTests/Fixtures/Upgrades/upgrade-fixture-manifest.json) | [UpgradeFixture tests](AsNeededTests/UpgradeFixtureTests.swift): `importReopenAndReexport`, `repeatedImports` |

# Calm Clinical UX And On-Device Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship medication guardrails, richer logging, refill intelligence, calm-clinical UX improvements, ambient surface upgrades, and an opt-in on-device Trends question feature.

**Architecture:** Keep storage stable by introducing typed local safety preferences plus a versioned metadata codec for richer event notes. Centralize dose/refill guidance in shared pure logic, then reuse it across iPhone views, widgets, watch, intents, and Live Activities.

**Tech Stack:** SwiftUI, Swift 6, Foundation Models, ActivityKit, WidgetKit, AppIntents, WatchConnectivity, Swift Testing

---

### Task 1: Add The Core Safety And Metadata Models

**Files:**
- Create: `AsNeeded/Models/MedicationSafetyProfile.swift`
- Create: `AsNeeded/Models/DoseReflection.swift`
- Create: `AsNeeded/Services/MedicationSafetyProfileStore.swift`
- Create: `AsNeeded/Services/DoseReflectionCodec.swift`
- Modify: `AsNeeded/Constants/UserDefaultsKeys.swift`
- Modify: `AsNeeded/Models/AppSettings.swift`
- Test: `AsNeededTests/MedicationSafetyProfileStoreTests.swift`
- Test: `AsNeededTests/DoseReflectionCodecTests.swift`
- Test: `AsNeededTests/SettingsExportImportTests.swift`

- [ ] Write failing tests for safety profile persistence and export/import coverage.
- [ ] Write failing tests for encoding, decoding, backward compatibility, malformed payloads, and note-preservation behavior.
- [ ] Implement the minimal models and codec/store code to satisfy those tests.
- [ ] Re-run the focused tests until green.

### Task 2: Add Shared Dose And Refill Guidance

**Files:**
- Create: `AsNeeded/Services/MedicationDoseGuidanceService.swift`
- Test: `AsNeededTests/MedicationDoseGuidanceServiceTests.swift`
- Modify: `AsNeededTests/MedicationTrendsViewModelTests.swift`

- [ ] Write failing tests for next-eligible calculations, duplicate detection, caution windows, daily limit proximity, low-stock state, refill lead state, and run-out projections.
- [ ] Implement the pure guidance service with no UI dependencies.
- [ ] Update existing Trends tests to exercise the new shared calculations where appropriate.
- [ ] Re-run the focused tests until green.

### Task 3: Add Pattern Summaries And On-Device Question Logic

**Files:**
- Create: `AsNeeded/Models/TrendsQuestionAnswer.swift`
- Create: `AsNeeded/Services/MedicationTrendsQuestionService.swift`
- Modify: `AsNeeded/Medication/ViewModels/MedicationTrendsViewModel.swift`
- Test: `AsNeededTests/MedicationTrendsQuestionServiceTests.swift`
- Test: `AsNeededTests/MedicationTrendsViewModelTests.swift`

- [ ] Write failing tests for availability gating, prompt input shaping, example prompts, and new pattern summary outputs.
- [ ] Implement the availability checks and strict prompt construction for on-device questions.
- [ ] Extend the Trends view model with pattern summaries, refill messaging, and answer state helpers.
- [ ] Re-run the focused tests until green.

### Task 4: Redesign Settings, Medication Edit, And Log Dose

**Files:**
- Modify: `AsNeeded/Views/Screens/Settings/AppPreferencesView.swift`
- Modify: `AsNeeded/Medication/ViewModels/MedicationEditViewModel.swift`
- Modify: `AsNeeded/Medication/MedicationEditView.swift`
- Modify: `AsNeeded/Medication/LogDoseView.swift`
- Create: `AsNeeded/Views/Components/ClinicalSurfaceCard.swift`
- Create: `AsNeeded/Views/Components/DoseReflectionSectionComponent.swift`
- Test: `AsNeededTests/MedicationEditViewModelTests.swift`

- [ ] Add failing tests for new medication safety inputs inside the edit view model.
- [ ] Implement the settings opt-in toggle and availability gating for on-device questions.
- [ ] Add the safety/refill configuration UI to medication editing.
- [ ] Add the structured reflection section and guidance summary to dose logging.
- [ ] Re-run focused tests and ensure the new UI compiles cleanly.

### Task 5: Redesign History, Detail, And Trends

**Files:**
- Modify: `AsNeeded/Medication/ViewModels/MedicationHistoryViewModel.swift`
- Modify: `AsNeeded/Views/Screens/Medication/MedicationHistoryView.swift`
- Modify: `AsNeeded/Medication/ViewModels/MedicationDetailViewModel.swift`
- Modify: `AsNeeded/Medication/MedicationDetailView.swift`
- Modify: `AsNeeded/Views/Screens/Medication/MedicationTrendsView.swift`
- Create: `AsNeeded/Views/Components/TrendsQuestionCard.swift`
- Create: `AsNeeded/Views/Components/MedicalCautionFooterView.swift`
- Test: `AsNeededTests/MedicationHistoryViewModelTests.swift`
- Test: `AsNeededTests/MedicationDetailViewModelTests.swift`

- [ ] Write failing tests for preserving structured note metadata during history note edits.
- [ ] Update detail and history logic to surface safety/refill summaries and decoded reflections.
- [ ] Redesign Trends around the new metrics, pattern summary, and integrated question card.
- [ ] Add the persistent caution footer and disclaimer access.
- [ ] Re-run focused tests and ensure the redesigned flows compile cleanly.

### Task 6: Upgrade Widgets, Live Activity, Watch, And Intents

**Files:**
- Modify: `AsNeededWidget/WidgetDataProvider.swift`
- Modify: `AsNeededWidget/MedicationSmallWidget.swift`
- Modify: `AsNeededWidget/MedicationMediumWidget.swift`
- Modify: `AsNeededWidget/MedicationLargeWidget.swift`
- Modify: `AsNeededWidget/MedicationLockScreenWidget.swift`
- Modify: `AsNeededWidget/LogDoseWidgetIntent.swift`
- Create: `AsNeededWidget/MedicationLiveActivity.swift`
- Create: `AsNeeded/Services/MedicationLiveActivityManager.swift`
- Modify: `AsNeeded/AsNeededApp.swift`
- Modify: `AsNeeded/Services/Intents/GetNextDoseIntent.swift`
- Modify: `AsNeeded/Services/Intents/CheckRefillStatusIntent.swift`
- Modify: `AsNeeded/Services/WatchConnectivity/WCReceiver.swift`
- Modify: `WristAsNeeded Watch App/WatchMedication.swift`
- Modify: `WristAsNeeded Watch App/MedicationListView.swift`
- Modify: `WristAsNeeded Watch App/MedicationDetailView.swift`
- Modify: `WristAsNeeded Watch App/DoseLoggerView.swift`
- Test: `AsNeededTests/WidgetDataProviderTests.swift`
- Test: `AsNeededTests/GetNextDoseIntentTests.swift`

- [ ] Add failing tests around the widget/intents guidance behavior.
- [ ] Replace hardcoded four-hour logic with shared dose guidance.
- [ ] Add the Live Activity surface and update hooks after app launch and dose logging.
- [ ] Improve the watch data payload and UI with sync, availability, and refill state.
- [ ] Re-run focused tests and ensure app/widget/watch targets still build.

### Task 7: Improve Data Management, Recovery, And Report Export

**Files:**
- Create: `AsNeeded/Services/ClinicianReportExporter.swift`
- Modify: `AsNeeded/Views/ViewModels/DataManagementViewModel.swift`
- Modify: `AsNeeded/Views/Screens/Settings/DataManagementView.swift`
- Modify: `AsNeeded/Views/ViewModels/AutomaticBackupViewModel.swift`
- Modify: `AsNeeded/Views/Screens/Settings/AutomaticBackupView.swift`
- Test: `AsNeededTests/ClinicianReportExporterTests.swift`
- Test: `AsNeededTests/DataManagementViewModelTests.swift`

- [ ] Write failing tests for clinician summary generation and recovery scan state handling.
- [ ] Implement readable summary export for clinician sharing.
- [ ] Surface recovery scan results and stronger backup status language in data management.
- [ ] Add any small backup UX improvements needed to support the new trust flow.
- [ ] Re-run the focused tests until green.

### Task 8: Final Verification

**Files:**
- Modify as needed based on failures from verification and review.

- [ ] Run `./scripts/dev-build.sh`.
- [ ] Run `./scripts/test-parallel.sh`.
- [ ] Run any focused test commands needed for the new logic if parallel tests are noisy.
- [ ] Run `coderabbit --plain` and address actionable issues if the tool completes.
- [ ] Review diffs for user-facing copy and confirm the Trends question feature never uses the word `AI`.

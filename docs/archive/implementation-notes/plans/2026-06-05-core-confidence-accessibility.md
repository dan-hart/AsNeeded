# Core Confidence And Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Core Confidence pass for AsNeeded: clearer medication status, fast quick-log warning/undo, progressive setup copy/grouping, a Data & Privacy hub, and accessibility improvements on touched screens.

**Architecture:** Add small pure summary helpers for medication status and quick-log feedback, then consume them from existing SwiftUI views and view models. Keep persistence, model schemas, storage paths, and migration behavior unchanged. Use fast Swift tests for helper behavior and only run broader build/test verification after targeted tests are green.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, ANModelKit, existing `MedicationDoseGuidanceService`, `MedicationSafetyProfileStore`, `DataStore`, and repo scripts.

---

## File Structure

- Create `AsNeeded/Services/MedicationStatusSummaryService.swift`: pure status and accessibility summary builder for list/detail/trends.
- Create `AsNeeded/Services/QuickLogFeedbackService.swift`: pure quick-log toast/undo feedback builder.
- Create `AsNeeded/Views/Screens/Settings/DataPrivacyView.swift`: new top-level trust hub that links to existing data and preferences flows.
- Modify `AsNeeded/Medication/ViewModels/MedicationListViewModel.swift`: expose quick-log undo metadata and use summary helpers.
- Modify `AsNeeded/Views/Components/MedicationRowComponent.swift`: display status summary, warning/refill badges, and accessible actions.
- Modify `AsNeeded/Views/Components/QuickLogToastView.swift`: support warning tone, next-window copy, and Undo action.
- Modify `AsNeeded/Medication/LogDoseView.swift`: improve confirmation/accessibility and reduce-motion behavior where touched.
- Modify `AsNeeded/Medication/MedicationEditView.swift`: reorganize labels/headers into essentials, safer, supply, and personalize sections without changing storage.
- Modify `AsNeeded/Medication/MedicationDetailView.swift`: add compact situation summary using shared helper.
- Modify `AsNeeded/Views/Screens/Medication/MedicationTrendsView.swift`: add chart/summary accessibility labels and reuse status copy where appropriate.
- Modify `AsNeeded/Views/Screens/Medication/MedicationHistoryView.swift`: add accessible actions and row labels for note/edit/delete.
- Modify `AsNeeded/Views/Screens/Settings/SettingsView.swift`: add top-level Data & Privacy row.
- Test `AsNeededTests/MedicationStatusSummaryServiceTests.swift`.
- Test `AsNeededTests/QuickLogFeedbackServiceTests.swift`.
- Test `AsNeededTests/DataPrivacyViewModelTests.swift` if the hub uses a helper model.

## Task 1: Status Summary Helper

- [ ] Write failing tests in `AsNeededTests/MedicationStatusSummaryServiceTests.swift` for last-dose text, next-window text, refill text, warning severity text, and accessibility summary.
- [ ] Run the targeted test and confirm it fails because `MedicationStatusSummaryService` does not exist.
- [ ] Create `AsNeeded/Services/MedicationStatusSummaryService.swift` with pure summary types and formatting.
- [ ] Run targeted tests and confirm they pass.

## Task 2: Quick Log Feedback And Undo State

- [ ] Write failing tests in `AsNeededTests/QuickLogFeedbackServiceTests.swift` for clear success copy, warning copy, next-window copy, and undo metadata.
- [ ] Run targeted tests and confirm they fail because `QuickLogFeedbackService` does not exist.
- [ ] Create `AsNeeded/Services/QuickLogFeedbackService.swift`.
- [ ] Modify `MedicationListViewModel` so quick log stores the last logged event and exposes undo.
- [ ] Run targeted quick-log tests and existing medication list view model tests.

## Task 3: Medication List UI And Accessibility

- [ ] Modify `MedicationRowComponent` to show status summary lines and warning/refill badges.
- [ ] Add accessibility label/value/hint/actions for opening details, logging, and changing appearance.
- [ ] Modify `MedicationListView` toast wiring for warning/undo.
- [ ] Run targeted tests from Tasks 1 and 2.

## Task 4: Progressive Add/Edit And Log Flow Accessibility

- [ ] Modify `MedicationEditView` section headers/copy: Essentials, Make This Safer, Track Supply, Personalize.
- [ ] Keep save behavior and safety-profile persistence unchanged.
- [ ] Modify `LogDoseView` labels, hints, warning copy, and reduce-motion/reduce-transparency handling where touched.
- [ ] Run existing edit/log-related tests if available plus helper tests.

## Task 5: Data & Privacy Hub

- [ ] Create `DataPrivacyView` with local-only summary, RxNorm disclosure, backup/export/import/clinician report links, and destructive data action route to `DataManagementView`.
- [ ] Add top-level Settings row for Data & Privacy.
- [ ] Add a small model/helper only if needed for testable section structure.
- [ ] Run targeted tests for any helper plus compile verification.

## Task 6: Detail, Trends, History Accessibility

- [ ] Add situation summary to `MedicationDetailView` using `MedicationStatusSummaryService`.
- [ ] Add accessibility summaries for Trends metric cards, charts, and heatmap.
- [ ] Add accessible actions and improved labels to History rows for edit/delete/note.
- [ ] Keep visual churn limited to touched screens.

## Task 7: Verification, Commit, Push, PR

- [ ] Run targeted fast tests for new helpers.
- [ ] Run the smallest relevant repo verification script.
- [ ] Review `git diff` for scope, no storage path/migration changes, and no `.superpowers/` files.
- [ ] Commit the changes.
- [ ] Push `task/core-confidence-accessibility`.
- [ ] Create a PR to `develop`.

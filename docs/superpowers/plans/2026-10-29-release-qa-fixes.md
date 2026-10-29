# Release QA fixes implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development and test-driven-development for focused implementation and independent review.

**Goal:** Resolve all actionable October 29 QA findings and prepare a coherent 1.2.0 candidate without disturbing concurrent notification work.

**Architecture:** Preserve storage locations, database schemas, transaction ownership, current SwiftUI styling and optional configuration. Fix behavior at its existing owner, add focused service regressions, and verify actual rendered layouts. No broad redesign or public submission.

**Tech Stack:** SwiftUI, Swift Testing, Boutique, UserNotifications, App Intents, Xcode and asc.

## Scope and isolation

At the maintainer’s direction, implementation waits for concurrent work to finish, then uses the original checkout directly. This condition was verified: clean task/v1.2.0 at 867d023 is pushed to origin. Preserve its completed authenticated background notification Log action and confirmation behavior. Do not use additional worktrees. No storage path, schema, migration, reset or primary settings-key change is planned. Export redaction changes only the exported copy; recovery scanning remains read-only. Use synthetic fixtures throughout.

## 1. Re-establish baseline

- [x] Run the full existing plan with TEST_DESTINATION set to the isolated iPhone 17 iOS 26.5 and TEST_WORKERS=1.
- [x] Inspect xcresult counts, keep source checkout changes untouched.

## 2. Dose, export and recovery correctness

Files: MedicationDoseGuidanceService.swift, MedicationEditViewModel.swift, DataStore.swift export section, Models/AppSettings.swift, Persistence/DataRecoveryManager.swift and matching Swift Testing suites.

- [x] Add failing coverage for huge finite quantities, nonfinite/negative quantities, redaction combined with settings/search history, and recovery reports that distinguish current from historical locations.
- [x] Guard derived numeric conversions; reject invalid stock input with actionable validation. Preserve valid fractional and optional quantities.
- [x] Omit search history from the settings copy when medication names are redacted. Never mutate saved preferences during export.
- [x] Compute recovery totals from existing distinct historical sources, excluding the current store, and accurately describe potentially duplicated source records.
- [x] Run focused tests red then green; independently review boundaries and backward compatibility.

## 3. Logging, layout and interaction

Files: MedicationListView.swift, related view-model/picker dispatch owner and tests, VerticalOnlyScrollView.swift, SettingsView.swift or the smallest proven layout boundary, support banner policy/owner and medication form copy.

- [x] Cover row quick log with no prior dose and with a different last-logged target. Keep floating quick log restricted to its intended current target.
- [x] Correct row dispatch with current active-medication validation; no silent failure on valid rows.
- [x] Reproduce and isolate iPad width overflow before choosing a fix. Constrain the real scroll viewport, retain navigation state and native controls.
- [x] Defer support banner appearance until meaningful established usage; keep optional support available in Settings.
- [x] Shorten explanatory form copy without weakening dose/unit/limit instructions.
- [x] Verify row hold, normal tap, movement cancellation, Undo, small/large iPhone, iPad portrait/landscape, dark/large text and keyboard behavior.

## 4. Notification and cold intent reads

Files: MedicationReminderRequest.swift, NotificationManager.swift reconciliation, Intents/ListMedicationsIntent.swift, CheckRefillStatusIntent.swift, GetDailyUsageIntent.swift, MedicationEntity.swift and tests.

- [x] Add failing coverage for names off-to-on and on-to-off-to-on with existing scheduled reminders.
- [x] Rebuild canonical named content from current medication while preserving identity, trigger, urgency and scheduling failure recovery.
- [x] Await prepareForAccess in every cold persisted intent/query read; use the resulting snapshot consistently. Cover cold persisted access with isolated stores.
- [x] Review against concurrent notification changes before integration.

## 5. Release configuration and truthfulness

Files: shipping privacy manifests, PRIVACY.md, in-app privacy descriptions when applicable, README.md, RevenueCatManager.swift, compiler-warning sites, project version settings and canonical store metadata.

- [x] Declare truthful reasons for file timestamp, disk capacity, local and App Group defaults in each executable bundle that uses them; verify Apple guidance and exported manifests.
- [x] Describe local medication storage, optional search requests, support purchases/RevenueCat, feedback/export and user-selected backups accurately. Clarify optional support subscriptions while retaining all free features.
- [x] Use production RevenueCat logging; fix observed compiler warnings; correct README minimum OS to the existing iOS 26 target.
- [x] Resolve latest live/in-flight build number and use the next number across shipping targets. Prepare current 1.2.0 metadata and release notes, inspect readiness without public submission or unnecessary changes to old drafts.

## 6. Integration and release verification

- [x] Run focused regressions, then scripts/test-parallel.sh; inspect actual xcresult counts.
- [x] Run Release build, review logs, inspect coherent app/widget/watch versions and privacy resources.
- [x] Repeat simulator smoke/UI checks with synthetic data, including relaunch persistence and the previously failed scenarios.
- [x] Independently review the final diff for requirements, correctness, privacy, accessibility and concurrent-work preservation.
- [ ] Build/archive and stage a new candidate when gates permit. Verify read-only store readiness and report physical upgrade, notification delivery, Watch/widget, assistive and purchase checks separately; do not invent passes or submit publicly.
- [ ] Review git status/diff and land only this task's verified changes with sanitized descriptive commits.

Verification evidence and remaining external/device gates: [release QA results](../../testing/2026-10-29-release-qa-fixes.md).

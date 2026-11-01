# Widget Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Ship the reviewed, configurable Medication and Usage widget experience while preserving the tested 1.2.0 app and push the completed branch.

**Architecture:** Keep existing widget kind identifiers and replace static providers with a shared AppIntent provider and immutable read-only projections. Use stable UUID navigation URLs to open native app detail/form/History/Trends; Home and cached legacy widget buttons never save immediately. Share pure projection and routing rules with the app test target, leaving storage and save transactions intact.

**Tech Stack:** SwiftUI, WidgetKit, AppIntents, Charts, Swift Testing, xcodebuild and git.

Spec: `docs/superpowers/specs/2026-10-28-widget-experience-design.md`. User's follow-up directs completion of all proposed work and committing/pushing the result.

## Task 1: Widget domain/configuration/rendering
- [x] Add pure shared projection tests first for automatic/explicit selection, unavailable IDs, complete-day usage, mixed units and timeline boundaries.
- [x] Create `AsNeeded/Services/WidgetExperienceProjection.swift`: snapshot selection, seven-day quantities/count fallback, primary data and timeline-boundary calculations. Read-only; inject date/calendar.
- [x] Create `AsNeededWidget/WidgetExperienceConfiguration.swift`: AppEntity query, medication selection, Show Names; immutable entries, async provider and synthetic gallery data.
- [x] Update existing four kind declarations/providers/views and add `MedicationUsageWidget.swift`. Reuse compact components with distinct layouts, privacy-sensitive information and rendering modes. Preserve kind IDs.
- [x] Replace legacy `LogDoseWidgetIntent` save with opening the exact dose form. Test its actual perform result via a shared target membership, proving the old cached entry point returns the exact opening destination without persistence effects. Keep stable intent parameter identity for cached archives.
- [x] Link shared sources and typography/symbol dependencies into the widget target; validate actual SDK APIs and project file.

## Task 2: Exact app navigation
- [x] Add `AsNeeded/Services/WidgetNavigationRoute.swift`, shared with widget, to build/parse exact ID-based detail, dose, History and Trends routes without medication names or writes.
- [x] Add parser/round-trip tests for malformed IDs/routes, selected medication, range, and no fallback behavior.
- [x] Extend QuickActionHandler/ContentView/NavigationManager to resolve active records after startup and dispatch exact destinations.
- [x] Add transient widget Trends selection/range overrides; do not overwrite existing saved tab filters. Restore normal saved filters when leaving the scoped view. Archived/deleted explicit selections must show unavailable, never another medication.
- [x] Handle duplicate taps and existing sheets without duplicate presentation or a dose write.

## Task 3: Verification/review/push
- [x] Run focused widget projection/navigation tests, then the full app suite and affected security/configuration/watch checks.
- [x] Review spec compliance, then code quality; fix valid findings and rerun affected tests.
- [x] Capture synthetic family previews/screenshots on a named simulator/runtime; check dark/tinted/large-text layouts where supported and document actual manual coverage and device-only gaps.
- [x] Check static-to-configurable continuity from existing installations; preserve kinds and safe defaults. If physical upgrade validation is unavailable, state it as a release gate rather than claiming it passed.
- [x] Commit all intended 1.2.0 files with security scans enabled, push to every configured remote (currently origin), and verify clean working tree, matching local/remote SHA and PR conflict status. Do not merge PR or publish a new TestFlight build.

## Commands

Focused: `xcodebuild test -project AsNeeded.xcodeproj -scheme AsNeeded -destination 'platform=iOS Simulator,id=F851B451-85A1-4471-8451-1D718BAE9956' -only-testing:AsNeededTests/WidgetExperienceProjectionTests -only-testing:AsNeededTests/WidgetNavigationRouteTests`.

Full: `TEST_DESTINATION='platform=iOS Simulator,id=F851B451-85A1-4471-8451-1D718BAE9956' TEST_WORKERS=2 ./scripts/test-parallel.sh`; inspect xcresult directly if formatter output conflicts. Run `git diff --check`, `plutil -lint AsNeeded.xcodeproj/project.pbxproj`, Python scanner/dependency suites and standalone watch availability harness. Use synthetic data and isolated preferences only.

Verification details and outstanding device-only checks are recorded in `docs/testing/1.2.0-widget-experience-verification.md`. Final push completion is recorded by Git and the task report.

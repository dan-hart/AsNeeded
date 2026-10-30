# 1.2.0 Regression Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Lock down the approved October 28 release behavior, resolve PR #10 against develop without changing that experience, and repair valid review findings.

**Architecture:** Extend Swift Testing suites around existing domain boundaries. Add only narrow injectable dependencies where global state or wall time prevents deterministic tests. Preserve the release UI; visual layout is documented separately rather than asserted through source-text tests.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, xcodebuild, Python unittest, git and GitHub CLI.

## Requested scope
The maintainer requests unit coverage of today's changes, commit/push to configured remotes, release-preferred conflict resolution against develop, evaluation of all PR review feedback, and a final test rerun. No new features or PR merge are authorized.

## Task 1: Baseline and coverage
Baseline: `ce1f51f`; raw baseline result: 861 passed, 5 failed in SettingsExportImportTests. Isolate that suite’s defaults before proceeding. Inventory October 28 behavior against `git log --since=2026-10-28`. Fetch all PR review threads/comments, record dispositions, and refresh at final head. Record the tested pre-merge tree and inspect the entire merge delta, project settings, pins, and retired-feature references; do not rely on conflict markers alone.
- [x] Run the full simulator suite and diagnose infrastructure failures from raw xcodebuild output.
- [x] Extend `AsNeededTests/LogDoseSessionTests.swift` and `QuickLogUndoRaceTests.swift` for preset times, draft continuity, manual confirmation/Undo, and explicit Undo identity after dismissal.
- [x] Add isolated Demo Mode tests in `AsNeededTests/DemoModeStateTests.swift`; inject name lookup into `AsNeeded/Services/DemoModeState.swift` without persisting session state.
- [x] Add deterministic numeric entry and filtered floating-target regression tests using small shared helpers wired into the current views, not duplicated test implementations.
- [x] Exercise existing persistence/import/backup/reminder/History/Trends suites; record the coverage inventory and visual-only limits.
- [x] Run focused suites, then full tests; commit and push `task/v1.2.0` to each configured remote (currently only origin).

## Task 2: Develop integration
- [x] Inspect incoming changes and conflicts, preserving the release's existing behavior and excluding retired capabilities.
- [x] Merge origin/develop into the release branch without rebasing or force pushing. Prefer release versions at conflicts and inspect nonconflicting incoming changes for alternate implementations.
- [x] Compare the resulting source tree with the tested release, rerun regression suites and full tests, then commit/push the merge.

## Task 3: PR review
- [x] Reproduce the credential-log leak for filenames containing colons. Repair `.github/workflows/security-scan.yml` so unparsed locations cannot print credentials; extend `scripts/tests/ci-password-pattern.test.py` and verify real detection stays enabled.
- [x] Inspect model-aware widget availability and extension notification ownership. Add regression coverage for migrated intervals, rolling quantity, indeterminate history, and post-save notification reconciliation; fix the smallest owning boundary in `AsNeededWidget/` and shared services.
- [x] Update ANModelKit/RevenueCat dependency metadata to the actual shipped Package.resolved revisions and test metadata consistency.
- [x] Rerun all Swift tests plus affected Python/security checks, push final changes, and verify the PR head/base/conflict status.

## Verification
Run simulator tests on F851B451-85A1-4471-8451-1D718BAE9956, iOS 26.5, two workers. Use `./scripts/test-parallel.sh` with TEST_DESTINATION and TEST_WORKERS; retain raw xcodebuild/xcresult diagnostics if the formatter suppresses errors. Use synthetic medications and isolated storage/defaults. No UI snapshots, test doubles replacing the tested business logic, scanner bypasses, or unrelated branch mutations.

# App UX and Accessibility Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. The user has requested the audit and improvements; execute within that scope without another approval gate.

**Goal:** Review every app, watch, widget, and intent view; fix verified usability, plain-language, and accessibility issues while preserving medication data and safety calculations.

**Architecture:** Keep existing SwiftUI state ownership, font choices, storage, and model contracts. Use native controls and adaptive layout. Split work by file ownership; one coordinator owns builds and simulator actions. Distinguish source review from actual rendered, assistive-technology, and device evidence.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, iOS/watchOS, existing simulator tools.

## References and scope

- Apple Human Interface Guidelines: Accessibility, Writing, Layout, VoiceOver, Typography.
- Repository rules: design-accessibility, swiftui, ios-development, testing, and storage-safety when applicable.
- Review all declarations in app, watch, widgets, and intent results; distinguish previews, shared components, legacy unused views, and reachable screens.
- Preserve the existing untracked screenshot artwork. Do not upload a new release or modify the physical phone during this UX pass.

## Tasks

- [x] Inventory every view and route; record coverage, evidence, severity, and remaining gaps in `docs/testing/1.2.0-ux-accessibility-audit.md`.
- [x] Establish reproducible baseline captures on an isolated small iPhone, using synthetic medication/history data only. Inspect standard and accessibility text sizes, light/dark appearance, and iPad layout where available.
- [x] Core medication screens (coordinator): shorten and clarify saved-limit copy; stop clipping timing; make log actions semantic controls and preserve long-press behavior; reduce repeated hero/section copy; retain all optional fields and clear units; make Trends controls/grids and reflections responsive to large text.
- [x] Settings/onboarding/recovery (settings owner): name every switch and icon action; remove misleading share-success copy; separate font selection from external links; keep recovery/restore content scrollable; simplify settings descriptions and ordering; honor font choices and preserve warnings/data callbacks.
- [x] Shared components (components owner): remove nested actionable controls in date/note cards; label and size search clearing; expose color selection state; honor Reduce Motion and readable preview/default colors. Do not replace search/persistence architecture in a visual cleanup.
- [x] Watch/widgets/intents (surfaces owner): fix cancellation changing displayed stock; label medication logging controls; distinguish absent recorded data from actual doses; avoid unsupported readiness promises. Add meaningful behavior regression tests where business behavior changes. Keep synchronization failures and unverified surfaces explicit.
- [x] Run the smallest behavior tests for changed logic first, then a bounded integrated suite appropriate to changed domains. Do not add UI/snapshot test targets. Do not mask known legacy fixture failures.
- [x] Build the app, widgets, and watch targets; fix compile errors; inspect resulting screens on named simulators with text-size/theme variants.
- [x] Review the final diff for accidental data changes, force unwraps, misleading medical copy, hidden controls, and unverified claims. Record fixes and remaining manual VoiceOver/Full Keyboard Access/physical-device checks honestly.

## Verification commands

Use `scripts/test-parallel.sh` with the available simulator destination and focused `-only-testing` selections; inspect the saved xcresult and unformatted log. Use the existing incremental Xcode cache for a simulator build when the optimized dev script's pinned runtime is unavailable. Run `git diff --check` and inspect every changed file. Record exact commands/results in the audit report.

Copy-only and reversible presentation edits do not need tests that mirror strings or SwiftUI implementation. Regression tests should establish meaningful outcomes such as cancellation preserving quantity and asynchronous failures retaining recoverable input. A source accessibility scan is not proof of VoiceOver or contrast conformance.

Final rendered and regression evidence is recorded in `docs/testing/1.2.0-ux-accessibility-audit.md`; manual assistive-technology and physical-device gaps remain explicit there.

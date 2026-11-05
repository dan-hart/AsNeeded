# Repository hygiene audit — November 5, 2026

Audit baseline: `task/v1.3.0`, commit `1111ab670cc3ab5e12b45b3facb793110a0a0169`. This records the baseline inventory and maintenance scope; applied cleanup and verification are recorded in the implementation section below. The repository was clean before this audit. No feature, storage, dependency, or shipping-target changes were made during the audit.

## Summary

The app has a coherent existing boundary: ANModelKit records, deterministic guidance services, serialized persistence transactions, SwiftUI state owners, an iOS widget snapshot/projection layer, and Watch messages validated and persisted on iPhone. Static review did not establish a need for a broad architecture rewrite. The clearest maintenance opportunities are misleading inactive source, duplicate Xcode configuration, historical material presented as active guidance, and tests that cannot detect a regression.

The full existing unit suite passed on iPhone 17 Simulator, iOS 26.5: **1,008 tests, zero failures, zero skips**. Test execution in the result bundle took approximately 58 seconds; build/runner setup took additional time. This is a functional baseline, not a coverage percentage or physical-device verification.

## Inventory

| Area | Tracked entries | Approximate file bytes | Interpretation |
| --- | ---: | ---: | --- |
| Entire checkout | 879 | 122,190,173 | 874 regular files plus five Git links; not Git object/history size |
| Design | 210 | 94,305,166 | 77% of tracked file bytes; approved sources and provenance need deliberate retention |
| App | 196 | 16,525,804 | Includes a 13.8 MB production localization catalog; retain |
| Skills | 154 | 4,219,535 | Optional references and search data; retain licenses and hash manifest |
| Tests | 105 | 810,615 | 104 Swift files, 1,008 test declarations, no UI test target |
| Documentation | 77 | 5,673,678 | Includes historical release evidence and screenshots |
| Backlog | 18 | 45,368 | Legacy task-manager integration; seven of eight active tasks already marked Done |
| Superpowers plans/specs | 15 | 82,032 | Ten plans and five specs; navigation clutter, not a material size problem |

Counts are before cleanup. Swift source inventory contains 305 tracked files across app, targets, tests, and inactive prototypes. Moving documentation within Git improves navigation but does not shrink Git history.

## Prioritized findings

### Fix tooling reliability and security first

1. `.github/workflows/storage-review.yml` interpolates PR body text directly into a shell string. Pass untrusted event text through an environment variable and read it as quoted data. Also review its PR comment permissions and full push comparison range. Do not weaken storage review or secret scanning.
2. `scripts/dev-build.sh` pipes Xcode into `xcsift` without `pipefail`, allowing a successful formatter to conceal a failed compiler. Add strict pipeline handling and a stub-command regression that proves Xcode failure propagates. Use an installed or generic simulator destination rather than assuming a local runtime.
3. `.github/workflows/build.yml` omits active `task/v1.3.0` triggers and builds without running unit tests. Route the active branch and add a reproducible regression check before treating green CI as test evidence. Confirm hosted destinations rather than guessing a simulator version.

### Remove misleading inactive implementation

- Five Swift files under `AsNeeded.xcodeproj/` are prototypes outside configured source roots/build phases: `Medication.swift`, `MedicationDetailView.swift`, `MedicationEditView.swift`, `MedicationListView.swift`, and `MedicationFeatureTests.swift`.
- `WristAsNeededWidget/` has no configured target, source root, embedding phase, or target dependency. Its README describes creating a missing target. Retire/archive this unfinished implementation; do not add a new widget feature during cleanup.
- `worktrees/code-review-1` through `worktrees/code-review-5` are tracked Git links without `.gitmodules`. Remove index entries only and ignore local worktree folders. Do not delete working directories, registrations, or branches.
- Private `DataDocument` and `LogDocument` in `DataManagementView.swift` are not instantiated; exports use URLs and ShareSheet. `CapsuleButtonStyle` in `EnhancedMedicationSearchField.swift`, `FeedbackError` in `FeedbackService.swift`, and unapplied `ConfettiModifier`/`ConfettiPiece` in `ThankYouView.swift` are ordinary unreachable helpers.
- The app target links ANModelKit, SwiftRxNorm, and DHLoggingKit twice. Consolidate to the already package-associated product references without changing package versions.
- Contributor README and CLAUDE files are explicitly copied into the app bundle without a runtime reader. Remove their app resource membership; preserve license/privacy resources and StoreKit artifacts until their distribution role is reviewed.

A missing text caller alone is insufficient evidence for deleting AppIntents, Codable keys, previews, entry points, or other platform-discovered declarations.

### Improve tests by meaning, not count

Remove the isolated `2 + 2 == 4` placeholder in `AsNeededTests.swift`. Review no-op haptic tests, nonoptional/static-type assertions, nonnegative collection counts, self-equality assertions, and conditional checks that pass without exercising their fixture. Preserve actual preference, scaling, parsing, ordering, persistence, migration, and race coverage.

Strengthen `NotificationManagerTests` optional reminder fixtures with `#require` instead of silently succeeding on nil. Search enhancement tests currently reach a concrete RxNorm client; use deterministic injected fixtures before calling them isolated unit coverage. History/Trends/validation suites mutate standard selection preferences, and suite-local serialization does not isolate different suites. Use isolated injected defaults where available. Review wall-clock thresholds and calendar-relative fixture dates separately; do not simply delete the behavior they cover.

Keep `CommittedSnapshotTests`: these test persistence snapshot consistency, not screenshot UI tests. Keep retired-question decoding tests, removed HealthKit permission checks, Undo races, and migration tests: old-format compatibility still matters after a feature is retired.

### Organize documentation and historical work

- Keep a small current documentation index: contributor setup, architecture, business rules, storage safety, testing, releases, and optional skills.
- Archive historical plans/specs and release receipts with an explicit dated index. Preserve data-loss lessons and data-integrity evidence. Move related files together and repair links.
- Retire BACKLOG as an active workflow and preserve unresolved context in the archive. The sole stale In Progress entry is not evidence that its feature is still unfinished. Retire its root launcher and obsolete provider integration.
- Replace the duplicative root `CLAUDE.md` with a compatibility pointer after preserving any unique valid rule. It currently requires obsolete HealthKit services, optional review tooling, and fixed machine assumptions.
- Correct README's nonexistent `Packages/` and `Tests/` paths, missing `LICENSE` link, `.editorconfig` claim, and active-release wording. Align CONTRIBUTING style examples with the current rules and explain release-branch contribution targets.
- Simplify script guidance: remove nonexistent HealthKit test commands, unsupported speedup claims, and routine cache-deletion advice.
- Keep future scratch plans outside Git by default. Commit durable decisions and reproducible evidence, not every intermediate agent plan.

### Assets and ignore policy

Retain approved product screenshots, raw captures required by their reproducibility tooling, synthetic fixtures, upload receipts, icon sources, editable templates, and third-party frame licenses. Label the older build-306 capture set as superseded; it is distinct from the approved later product screenshot set. Verify ZIP member equivalence before removing the generated screenshot ZIP.

Add narrow ignores for local worktree directories, Python caches, and known generated logs/archives. Do not blanket-ignore JSON, screenshots, Design, or Markdown: those include deliberate release sources and evidence. No history rewrite is needed.

## Drift proposal

Use a maintained `BUSINESS_RULES.md` as the readable feature/rule map. Each rule should identify its implementation and meaningful regression tests. Start with logging/Undo and backdating, optional saved guidance, dose/stock atomicity, History/Trends ranges, reminders, and import/backup boundaries. Describe existing behavior from code; do not use this exercise to invent new requirements.

Drift's role is to flag that anchored code changed and the document needs review. It does **not** prove the implementation satisfies a sentence in Markdown. Behavioral tests remain the semantic check. The currently installed Drift v0.10.1 successfully linked a temporary Swift file and marked the document stale when that file changed. Prefer complete Swift-file anchors unless symbol support is verified for the pinned version; unsupported language parsing may use raw content comparison.

Begin with a small set of rule sections/source/test files rather than anchoring every file or historical plan. Pin the CI tool/version and preserve checksum verification. Review stale docs before refreshing signatures; never regenerate the lock merely to make CI pass. Keep contributor setup explicit and avoid optional agent-runtime dependencies.

Official reference: [Fiberplane Drift](https://github.com/fiberplane/drift). Installed-version behavior was checked locally; current upstream documentation may describe a newer lock format.

## Proposed sequence and verification

1. Review this inventory and cleanup scope.
2. Repair workflow/build correctness, add focused tooling regressions, and preserve existing scans.
3. Remove only verified inactive source/project references; archive historical materials and update navigation.
4. Trim/strengthen low-value tests with relevant suites before broad verification.
5. Add the current business-rule map and a small Drift pilot, including a controlled stale-anchor regression outside the working tree.
6. Run local link/path/ignore checks, script syntax and regression checks, app/widget/watch builds, and the full unit suite. Record exact results and remaining hardware/network checks.

No App Store or TestFlight release, device installation, broad observation migration, storage path/schema change, or local worktree deletion is part of this proposal.

## Implemented cleanup

The maintainer approved both conservative and deeper cleanup after reviewing the proposal. The cleanup is delivered on `task/v1.3.0`; no public app release is included.

- Fixed development pipeline exit handling, installed/compatible simulator selection, active release CI routing, unit/standalone CI execution, PR-body shell injection, full push-range storage detection, and guarded PR comment permissions. Existing secret scans and storage policy remain enabled.
- Removed the five accidental Git links from the index without deleting physical worktrees or registrations. Added narrow ignores for local worktrees, caches, scratch plans, and duplicate screenshot distribution ZIPs.
- Archived 111 historical files, preserving all non-Markdown content hashes and repairing documentation links. Retired the active backlog launcher and deprecated hook wrapper. The old ZIP's six images were verified byte-for-byte against the retained individual images before removing it.
- Removed excluded prototype files, the unconfigured Watch-widget implementation, proven unused helpers, duplicate package-product entries, and contributor-doc resource membership. Kept all configured targets, package revisions, persistence implementations, storage constants/settings keys, compatibility cleanup, and meaningful migration/race tests.
- Removed 72 low-value/timing-only tests, replaced 12 network-bound search tests with nine deterministic service tests, strengthened optional/font prerequisites, and isolated History/Trends/Search/Analytics/AppReview test preferences. Added explicit default-domain persistence/separation tests without changing live default storage or review behavior.
- Added current source/feature documentation and a pinned Drift v0.10.1 CI check: three maintained documents with 30 implementation/test/workflow anchors. The isolated Drift regression verifies detection without silently refreshing the lock. Historical archive material is not a semantic specification.

Independent specification and quality reviews found one introduced simulator-selection issue (older runtimes could be selected); it was fixed with mixed-runtime and old-only regressions. No other actionable regression was identified in those reviews. This is bounded evidence, not a guarantee that no bug exists.

### Final verification

- Final Xcode result bundle: **936 tests passed, zero failures, zero skips** on iPhone 17 Simulator/iOS 26.5. Parameterized executions are counted separately by Xcode. The baseline was 1,008; the smaller suite reflects removed weak checks, deterministic replacements, and new isolation regressions rather than removing compatibility requirements.
- App scheme build succeeded with app, iOS widget, and Watch products present; contributor README/CLAUDE resources are absent from the app bundle. Final unit-test compilation also passed after the last preference-injection changes.
- **50 standalone Python tests** across ten directly invoked files, **54 localization tests**, the setup-helper regression, and **three Watch availability tests** passed. The Watch harness required normal compiler-cache access after an initial sandbox-denied run.
- Drift v0.10.1 passes with **30 anchors across three maintained documents**, no stale anchors, and no broken local links. The controlled Swift-change regression passed without refreshing its lock. Relative Markdown path checks, Bash syntax, Xcode project lint, and diff whitespace checks passed.
- All **38 non-Markdown archived files** retain their original hashes. Physical worktrees remain registered; their accidental Git links are removed from the index. Persistence implementation, storage constants, typed settings keys, and dependency lock are unchanged.

Hosted GitHub Actions were not part of this local verification. No physical-device upgrade, UI/VoiceOver walkthrough, notification-delivery check, signing/export, or TestFlight rollout was performed. Static review and passing tests cannot guarantee the absence of every bug. Existing build metadata is retained; these local products are not a newly distributed beta.

The final commit check exposed a preexisting acknowledgement gap: the preflight CLI supports system review, but the commit hook forwarded only storage review. The hook now forwards an explicit `ASP_ACK_SYSTEM=1` to the existing flag. Real-hook regressions proved that unacknowledged changes still block and acknowledgement cannot bypass secret scanning; all ten hook tests pass. No security detector or exception was changed.

## Requested health follow-ups — base `9585849`

The follow-up adds the README App Store link, approved synthetic 1.2.0 screenshot and branch-specific live badges; a read-only human/JSON environment doctor; 13 stable business-rule IDs with source/regression traceability; a Mermaid recording/recovery diagram; feature-folder consolidation; shared target-neutral stored/wire identifiers; and an immutable synthetic export/upgrade fixture library.

All **51 moved UI/state files retain their source bytes**. The 11 production files using shared contracts restore to their original bytes when references are replaced with the independently pinned legacy literals. Storage containers, database filenames, preference keys, schema version, Watch payload spelling, dependency versions, entry-point behavior, and existing widget routing are preserved. All configured app/widget/Watch source memberships compile. The fixtures are schema-derived synthetic examples with explicit source references and limitations, not claimed historical-release backups or personal records.

Verification: **943 app tests** passed with no failures/skips (Xcode result readback), **59 standalone Python tests**, **54 localization tests**, and **five Watch tests** passed. App, iOS widget, and Watch builds succeeded. The live doctor returned healthy observations with normal simulator access; sandbox-restricted observation had correctly reported an inability to confirm simulator availability. Independent specification and quality reviews found no actionable regression. Local documentation links and README image/alt text are valid, rule IDs are unique and mapped, source-move hashes are intact, project lint passes, and Drift passes with **40 reviewed anchors**.

The excluded enforced-CI/branch-protection proposal and dependency-container rewrite were not implemented. No `.github` policy/workflow files changed in this follow-up. No commit/push, release, physical-device installation, actual phone upgrade, or native notification delivery test was performed for these local changes. Automated evidence and identical stored values do not establish every possible hardware/OS upgrade outcome.

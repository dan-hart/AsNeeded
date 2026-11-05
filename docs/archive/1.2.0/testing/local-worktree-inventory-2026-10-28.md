# Local worktree and branch inventory — October 28, 2026

Read-only inventory requested while restoring the large Medication-tab Log Dose action. No worktree was switched, reset, removed, pruned or merged. Other worktree files were left untouched.

## Why this work looked familiar

Commit `8fab48f` (September 15) added a Medication-tab floating Log Dose action, medication chooser, shared press gestures and quick-log hints on the other development line. `2196d8d` subsequently added the chooser to History's All view. These commits are reachable from the locally cached `origin/develop` (`3c75069`, October 1), not the current release HEAD `1d3d1ac`.

`git rev-list --left-right --count HEAD...origin/develop` reports 12 release-side and 90 develop-side commits. These are ancestry counts, not 90 missing features: current uncommitted stabilization work independently replaces some older behavior. No claim is made about the remote's latest state; this inventory did not fetch or alter remote refs.

## Worktrees

| Worktree branch | Local state | Meaning / handling |
| --- | --- | --- |
| `task/1.2.0-next-dose` | Current release checkout; ongoing uncommitted stabilization/UI work | Preserve all current changes. |
| `task/quick-log-undo-race` | Ref retained at `f56ee41`; registered temporary worktree directory is missing/prunable | `5357049` ties Undo quantity to the visible toast generation and tests acknowledgement/Undo races; the second commit bumps the build. Relevant stabilization follow-up; not merged here. |
| `task/native-mac-icloud` | Clean, `bdd0764` | Native Mac app and opt-in private iCloud sync, based on the other develop line; its plan explicitly places it after 1.2.0. Keep separate. |
| `task/fix-wrong-medication-log` | Clean, `8b514a9` | Misleading old worktree name: its tip contains the merged core-confidence/accessibility pass and earlier wrong-medication logging fix. Its tip is already an ancestor of current release HEAD. |
| `task/asneeded-issues-7-8-4e429c` | `9db5422`; only an untracked local Config directory | Old status checkout; no committed work beyond the current ancestry at its tip. Local configuration not read or copied. |
| `task/project-status-d14d3f` | Clean, `9db5422` | Old status checkout; no new committed implementation at its tip. |
| `task/an-design-kit` | Clean, `6e4f402` | ANDesignKit integration and list/dose-flow migrations; broad design-system work. Do not overwrite the current focused layout/contrast fixes. |
| `task/component-reference` | Clean, `1e584ff` | Stops at an older build-303 point on the other development line; no uncommitted reference-component work. |
| `task/remove-medication-guardrails` | Clean, `c6d3d1b` | Refill/guardrail replacement plus notification-removal cleanup. Guardrail removal conflicts with the currently requested optional dose guidance; isolate any relevant notification regression rather than merging the branch wholesale. |

Eight existing checkouts including the current one, plus one stale registration. Existing checkouts besides this release are clean except the noted untracked local Config directory. No cleanup performed.

## Additional work worth targeted review

- Quick-log Undo toast/quantity races (`5357049`), already inspected separately. The current release still clears its toast after an awaited Undo; replacement-toast protection needs a focused regression before any port.
- Notification reconciliation/acknowledgement and medication-removal cleanup (`405c194`, `89a10c1`, `ef9452b`, `c6d3d1b`). Compare against the current stabilization implementation before treating any as missing.
- Font double-scaling/accessibility fixes (`c9f20d9`, `0a7f07c`), backup picker/progress/overlap fixes (`caf7224`, `f091609`), and shared Log Dose gesture work. These are audit candidates, not approval to pull all of the other develop history into the feature-frozen release.
- Mac/iCloud and ANDesignKit remain separate work; neither is part of restoring this button.

## Scoped restoration in this release

Build 315 adapts the earlier chooser-to-dose-form handoff from `8fab48f` while preserving the current atomic persistence, retained dose drafts, compact rows, row color choices, and five time presets. It uses a large accent action in a bottom safe-area inset so it reserves its own space above the tab bar. One active medication opens the existing form directly; multiple medications open a searchable native chooser in current list order. Archived/deleted items are excluded/revalidated. Closing the chooser records nothing. No hold-to-log behavior, hint system, unrelated History change, design-system migration, storage key or dependency is added with this action.

Completed restoration and verification: [build 315](1.2.0-315-large-log-dose.md).

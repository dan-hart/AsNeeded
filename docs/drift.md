# Documentation freshness with Drift

Drift flags changes to source/test files linked from a maintained document. It prompts review; it does not execute a Markdown business rule or prove that code satisfies prose. Keep behavioral tests as the semantic check. See [the business-rule map](../BUSINESS_RULES.md) and [architecture](architecture.md).

## Required human review

A stale Drift binding or a proposed change to a business rule, its bindings, or the checks that enforce them requires a pull request and an explicit decision from a human maintainer before merge. A green check after refreshing or removing a binding does not count as approval.

1. In the PR, list the affected rule IDs or documents. Explain what changed, whether the behavior is intentional, and which regression evidence supports it.
2. A human maintainer reviews the current diff and records **Approve** or **Request changes** in the PR. An approval may accept a refreshed binding for unchanged behavior or approve an intentional rule change with updated documentation and regression evidence.
3. Keep the change out of the target branch while review is pending or changes are requested. Fix rejected changes and ask for a new decision. Get a fresh approval if the relevant code, rule, tests, or lock changes after approval. Automated reviews, CI results, and unrecorded decisions do not substitute for human approval.

GitHub uses the base branch’s [CODEOWNERS](../.github/CODEOWNERS) to request review of changes to the rules, lock, and review controls. Branches that enforce this at merge time need required code owner review and a required Drift status check. GitHub does not let PR authors approve their own PRs.

## Local workflow

The repository uses Drift **v0.10.1**. Local installation is optional; CI runs the pinned checker without depending on an agent runtime. To install on macOS, use the official Homebrew package (`brew install fiberplane/tap/drift`) and check `drift --version`. If it installs a different version, consult that version's documentation before rewriting the lock format.

```bash
drift status
drift check
drift refs AsNeeded/Services/MedicationDoseGuidanceService.swift
```

When an anchored file changes, review the affected rule and its tests. Update the document if behavior changed. If the document remains accurate, explicitly review the change before refreshing that document's signatures:

```bash
drift link BUSINESS_RULES.md --doc-is-still-accurate
```

Review `drift.lock` before committing. Never auto-refresh it in hooks/CI or merely to silence a stale warning. When adding or changing a business rule, list its implementation and regression evidence in the traceability table. Add a binding for each file in that row:

```bash
drift link BUSINESS_RULES.md AsNeeded/Services/MedicationDoseGuidanceService.swift
```

## Scope and verification

The maintained anchors cover business rules, architecture, the checker workflow, and the read-only doctor documentation. Business rule anchors include code, regression tests, upgrade fixtures, and supported localization catalogs. Use `drift status` to see the current bindings. The main strings catalog exceeds the pinned version’s file size limit and compiled resource tests verify representative strings and locale bundles. Use whole-file anchors for Swift. A formatting-only change may still trigger review.

The CI workflow pins the setup action and binary version. The action verifies the release archive checksum. [The Drift tests](../scripts/tests/drift.test.py) check that every rule has a table row and that the implementation and regression references in each row have bindings. They also verify that editing a linked Swift fixture makes its document stale without refreshing the lock. Run it directly when Drift is available:

```bash
python3 scripts/tests/drift.test.py
```

Missing local Drift skips this optional tool-specific regression; the CI Drift job installs the pinned tool and runs the regression plus `drift check`. Unit tests still run separately in the Build workflow.

Official source: [Fiberplane Drift](https://github.com/fiberplane/drift). This repo uses its verified v0.10.1 behavior rather than assuming the latest upstream lock syntax.

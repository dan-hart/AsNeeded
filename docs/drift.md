# Documentation freshness with Drift

Drift flags changes to source/test files linked from a maintained document. It prompts review; it does not execute a Markdown business rule or prove that code satisfies prose. Keep behavioral tests as the semantic check. See [the business-rule map](../BUSINESS_RULES.md) and [architecture](architecture.md).

## Local workflow

The pilot uses Drift **v0.10.1**. Local installation is optional; CI runs the pinned checker without depending on an agent runtime. To install on macOS, use the official Homebrew package (`brew install fiberplane/tap/drift`) and check `drift --version`. If it installs a different version, consult that version's documentation before rewriting the lock format.

```bash
drift status
drift check
drift refs AsNeeded/Services/MedicationDoseGuidanceService.swift
```

When an anchored file changes, review the affected rule and its tests. Update the document if behavior changed. If the document remains accurate, explicitly review the change before refreshing that document's signatures:

```bash
drift link BUSINESS_RULES.md --doc-is-still-accurate
```

Review `drift.lock` before committing. Never auto-refresh it in hooks/CI or merely to silence a stale warning. Add a new file anchor only when it supports a concrete maintained statement:

```bash
drift link BUSINESS_RULES.md AsNeeded/Services/MedicationDoseGuidanceService.swift
```

## Scope and verification

The maintained anchors cover business rules, architecture, the checker workflow, and the read-only doctor documentation. Selected logging, guidance, date-range, persistence, notification, backup, shared-contract and upgrade-fixture sources/tests are included; `drift status` shows the current bindings. Historical plans, archived receipts, generated exports, and vendored skills are not freshness specifications. Complete-file Swift anchors are deliberate: the installed version does not establish Swift symbol-level parsing, so formatting-only changes may require review.

The CI workflow pins both the setup action commit and binary version. The official action verifies the release archive checksum. `scripts/tests/drift.test.py` proves a linked Swift fixture starts fresh, becomes stale after a code change, and is not silently refreshed by checking. Run it directly when Drift is available:

```bash
python3 scripts/tests/drift.test.py
```

Missing local Drift skips this optional tool-specific regression; the CI Drift job installs the pinned tool and runs the regression plus `drift check`. Unit tests still run separately in the Build workflow.

Official source: [Fiberplane Drift](https://github.com/fiberplane/drift). This repo uses its verified v0.10.1 behavior rather than assuming the latest upstream lock syntax.

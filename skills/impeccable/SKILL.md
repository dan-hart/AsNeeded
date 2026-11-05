---
name: impeccable
description: Review and refine native AsNeeded UI, including hierarchy, accessibility, typography, adaptive layout, and final polish.
---

# Impeccable for AsNeeded

Read [repository rules](../../AGENTS.md) and [design/accessibility guidance](../../ai-rules/design-accessibility.md). AsNeeded is native SwiftUI on iOS and watchOS. Preserve existing navigation, reusable components, custom font choices, `.accent`, medication colors, and supported OS versions. Use [SwiftUI Expert](../swiftui-expert-skill/SKILL.md) for implementation. Repository and user instructions override generic examples.

Use synthetic medication data for screenshots and examples. Keep manual visual/device checks separate from unit tests; do not add UI or snapshot test targets. Installing a skill does not authorize unrelated redesigns, dependency changes, downloads, account changes, or publication.

## Native workflow

Read the relevant playbook below and inspect the existing screen and task scope. Treat this app as a task-focused medication tracker: clarity and familiar native behavior take priority over visual novelty. Check all states the change actually affects, fix within scope, then verify in a bounded pass.

| Task | Reference |
| --- | --- |
| UX critique | [Critique](reference/critique.md) |
| Technical accessibility/performance review | [Native audit](reference/audit.native.md) |
| iOS conventions | [iOS](reference/ios.md) |
| Compact/wide layouts | [Native adaptivity](reference/adapt.native.md) |
| Final spacing and consistency | [Polish](reference/polish.md) |
| Resilience and localization | [Harden](reference/harden.md) |
| Clear interface language | [Clarify](reference/clarify.md) |

The copied references retain upstream wording. AsNeeded's custom typography, per-medication colors, native materials, existing navigation, and scoped workflow take precedence over conflicting aesthetic defaults. Read [Liquid Glass guidance](../../docs/LIQUID_GLASS.md) for material work.

This is a reference-only adaptation. No engine, launcher, browser detector, automatic hook, or agent configuration is installed. Ignore reference instructions to run engine commands, initialize product files, download assets, or delegate by default. Read existing project context directly and use the permitted local tools appropriate to the task. A source review or accessibility outline cannot establish visual correctness; inspect actual screenshots when making layout claims. Report what was and was not verified.

---
name: harden
description: Improve AsNeeded UI resilience for long names, Dynamic Type, RTL, localization, invalid input, and recoverable failures.
---

# Harden for AsNeeded

Read [repository rules](../../AGENTS.md) and [design/accessibility guidance](../../ai-rules/design-accessibility.md). AsNeeded is native SwiftUI on iOS and watchOS. Preserve existing navigation, reusable components, custom font choices, `.accent`, medication colors, and supported OS versions. Use [SwiftUI Expert](../swiftui-expert-skill/SKILL.md) for implementation. Repository and user instructions override generic examples.

Use synthetic medication data for screenshots and examples. Keep manual visual/device checks separate from unit tests; do not add UI or snapshot test targets. Installing a skill does not authorize unrelated redesigns, dependency changes, downloads, account changes, or publication.

## Workflow

Use [the hardening playbook](../impeccable/reference/harden.md) as a checklist, translating CSS/JavaScript examples into native SwiftUI behavior. No frontend framework or additional skill setup is required.

Inspect the affected flow with long synthetic names, fractional quantities, missing optional data, empty history, large fonts, and relevant localization/RTL cases. Include cancellation, repeated taps, denied permissions, and failures when the task touches those states. Preserve accurate units, original timestamps, stock counts, and Undo behavior. Saved guidance must not be presented as medical clearance.

Before persistence, import, migration, or settings changes, read [storage safety](../../ai-rules/storage-safety.md). Prefer native formatting and localized string catalogs over concatenated user-visible strings. Preserve critical names with the repo's `.noTruncate()` conventions; do not copy web truncation examples literally.

Add deterministic domain/service regression coverage for changed behavior and visually inspect layout changes on a named simulator/device. Report remaining evidence gaps.

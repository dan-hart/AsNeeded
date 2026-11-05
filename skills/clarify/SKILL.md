---
name: clarify
description: Improve AsNeeded labels, medication guidance, notifications, validation, and recovery copy while preserving meaning and localization.
---

# Clarify for AsNeeded

Read [repository rules](../../AGENTS.md) and [design/accessibility guidance](../../ai-rules/design-accessibility.md). AsNeeded is native SwiftUI on iOS and watchOS. Preserve existing navigation, reusable components, custom font choices, `.accent`, medication colors, and supported OS versions. Use [SwiftUI Expert](../swiftui-expert-skill/SKILL.md) for implementation. Repository and user instructions override generic examples.

Use synthetic medication data for screenshots and examples. Keep manual visual/device checks separate from unit tests; do not add UI or snapshot test targets. Installing a skill does not authorize unrelated redesigns, dependency changes, downloads, account changes, or publication.

## Workflow

Use [the clarity playbook](../impeccable/reference/clarify.md). No frontend framework or product-context initialization is required.

Read the full interaction before changing isolated strings. Identify the fact the user needs, the next action, and any useful recovery instruction. Use short, calm, specific language. Keep scheduled reminders distinct from next-dose availability alerts, and distinguish backdated records from doses taken now. Do not describe saved-limit checks as proof that a dose is safe.

Preserve prescription terminology, quantity units, privacy promises, billing terms, and explicit user-approved wording. User instructions about existing alert text take precedence over generic advice about button labels. Use Danvoice for requested drafts when available; it does not authorize sending or publishing.

Update applicable string catalogs and format placeholders consistently, including notifications, widgets, and Watch when affected. Check long translations, RTL, and screen-reader reading order where relevant. Explain factual changes for review; do not invent clinical, legal, or product claims.

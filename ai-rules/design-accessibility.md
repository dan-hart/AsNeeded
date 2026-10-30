# Native Design and Accessibility

Load for screen flows, forms, visual review, navigation, motion, and accessibility.

- Start with the task, platform, current screen, and existing components. This is native SwiftUI on iOS/watchOS; design references do not authorize React Native, Expo, or a visual identity replacement.
- Preserve the app's font-family choices and semantic text styles through `.customFont()`. Check large accessibility sizes, long medication names, localized labels, and multiline quantities/units without clipping critical information.
- Use `.accent` and existing adaptive colors/materials. Give timing, warnings, and confirmation states clear words/icons as well as color. Review light/dark appearance and increased contrast.
- Keep the main log action easy to find. Optional guardrails should explain saved limits; they must not silently disable basic recording. Show units beside quantity inputs and actionable validation near the affected field.
- Account for empty, loading, error, missing-configuration, denied-permission, and success states. Distinguish a scheduled reminder from an optional availability alert. Ask for permissions in context and explain how denial affects the feature.
- Keep controls comfortably tappable, names meaningful to VoiceOver, reading/focus order coherent, and decorative elements hidden from accessibility. Check VoiceOver and hardware/assistive input when relevant, not just an accessibility text dump.
- Respect safe areas, keyboard coverage, rotation, compact/wide layouts, and watch screen constraints. Preserve navigation state when containers resize. Read `docs/LIQUID_GLASS.md` for scoped material work.
- Use purposeful, restrained motion and respect Reduce Motion. Avoid celebration or decorative effects that obscure medication status or encourage taking a dose.
- Inspect screenshots on a named device/runtime/build for visual claims. An outline proves exposed labels, not typography, spacing, animation, or clipping. Record what was actually checked and leave physical-device delivery/upgrade gaps explicit.

Optional deeper resources: [Mobile Design](../skills/mobile-design/SKILL.md), [SwiftUI Expert](../skills/swiftui-expert-skill/SKILL.md), and [device evidence](../skills/sim-use/references/device-verification.md). Manual review does not add UI/snapshot testing requirements.

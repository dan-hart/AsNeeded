# Liquid Glass in AsNeeded

Reviewed October 27, 2026 against Apple's current adoption documentation.

## Design contract

Liquid Glass is the controls/navigation layer above readable content. Use standard SwiftUI navigation bars, toolbars, tab bars, menus and sheets; the system supplies their material, grouping and accessibility adaptations. Ordinary medication/form cards use opaque adaptive system backgrounds.

For toolbar buttons:

- Use ordinary `Button`/`Menu` inside semantic `ToolbarItem` placements or `ToolbarItemGroup`.
- Apply `.tint(.accent)` at the host. Preserve destructive roles so destructive actions retain their system treatment.
- Let iOS choose icon size, button shape, shared background and hit area. Do not add a circular filled symbol, custom frame, background, border, shadow, glass modifier or prominent button style to simulate another button inside it.
- Use a plain `checkmark`, `xmark`, `plus` or `ellipsis` where appropriate. Provide meaningful accessibility labels for icon-only actions.
- Keep text buttons in the selected app font at the standard body style, without extra bold/size treatment. Native symbol labels use system sizing.
- Use `ToolbarItemGroup` for multiple items rather than placing a custom `HStack` in one item. Use a normal trailing placement for a visible More menu; `.secondaryAction` may place it in a system overflow menu.
- Keep one primary Save action per sheet. If a sticky Save button exists, do not repeat it in the toolbar.
- If X is the only navigation-toolbar action, place it at `.topBarTrailing`. With other navigation-toolbar actions, retain native leading cancel and trailing confirmation/action placements. Keep native labels so iOS can show symbols or text for the available space.

```swift
.toolbar {
	ToolbarItem(placement: .topBarTrailing) {
		Button { closeEditor() } label: {
			Image(systemSymbol: .xmark)
		}
		.accessibilityLabel("Close editor")
	}
}
.tint(.accent)
```

Existing system `.close`/`.confirm` roles can remain where their semantics apply. Keep discard confirmation, disabled/loading state and callbacks intact.

## Content and custom controls

- Keep critical medication names, amounts, units and timing on legible system content surfaces. The legacy `.glassCard()` helper now renders an opaque content card; its name is retained for compatibility.
- Do not combine a gradient fill, glass effect, decorative highlight stroke and shadow on the same action. Prefer a native button style. Medication color can still identify a medication in content; the toolbar uses the app accent.
- A regular SwiftUI material used for a floating action footer is not itself the Liquid Glass API. Evaluate its readability and purpose separately.
- Add custom Liquid Glass only when a distinct floating control needs it. Gate new APIs for supported OS versions and provide fallbacks. Apply layout before `.glassEffect`; use `GlassEffectContainer` for custom glass elements that need coordinated rendering. Standard toolbars manage their own rendering; do not wrap them in another glass layer.
- Do not add morphing, parallax or interactive glass to informational cards just for decoration.

## Accessibility and verification

Check actual rendered screens in light/dark appearance, large accessibility text, Increase Contrast, Reduce Transparency and Reduce Motion. Native controls provide system adaptations; custom surfaces still need inspection. Keep named actions and reading order. A source scan is not a VoiceOver or visual conformance test.

For this pass, see [the audit and verification record](testing/1.2.0-liquid-glass-audit.md). Test only with synthetic medication data.

## Sources and skill selection

- [Apple: Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) — primary authority for system adoption, restraint, grouping and customization.
- [Apple: Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views) — API composition and custom-control rendering.
- [Dimillian: SwiftUI Liquid Glass skill](https://github.com/Dimillian/Skills/tree/main/swiftui-liquid-glass) — selected as the most focused fit among the reviewed candidates for an existing native SwiftUI app. Its review workflow is useful; verify snippets/API details against Apple rather than importing every example.
- [SohrabZ: Liquid Glass skills](https://github.com/SohrabZ/liquid-glass-skills) — broader alternative covering UIKit, controls and troubleshooting; more scope than this toolbar correction needs.

The prior guide encouraged glass on content cards, repeated simulated highlights and unverified API snippets. This guide replaces those recommendations. Optional online skills are reference material, not a build/CI dependency.

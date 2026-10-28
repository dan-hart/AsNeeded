# Liquid Glass reference for this repository

Read [the repository guide](../../../docs/LIQUID_GLASS.md) before material or toolbar work. It overrides generic upstream examples for AsNeeded.

- Standard SwiftUI controls adopt the system design. Keep toolbar `Button`/`Menu` controls native and use `.tint(.accent)`.
- Keep medication content on readable adaptive content surfaces. Do not add glass to every card.
- Prefer built-in styles for custom actions over layered gradient/glass/shadow imitations.
- Custom glass uses `Glass` (`.regular`, `.clear`) with `.glassEffect(_:in:)`; the default shape is a capsule. There is no `GlassEffectStyle` or `.prominent` glass variant in the verified API. Prominent custom buttons use the separate `.glassProminent` button style.
- Apply layout before an effect. Use `.interactive()` for real interactive elements. Coordinate related custom glass with `GlassEffectContainer`; system toolbars manage themselves.
- Gate new Liquid Glass APIs for supported OS versions. Preserve older-system behavior when needed.
- Check accessibility, display settings and actual screenshots. Keep Reduce Motion/Transparency and focus behavior explicit in verification.

Sources: [Apple adoption guide](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Apple custom-view documentation](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views), [reviewed online skill](https://github.com/Dimillian/Skills/tree/main/swiftui-liquid-glass).

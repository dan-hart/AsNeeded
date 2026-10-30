# SwiftUI Rules

**Applies To**: SwiftUI views, components, styling, layout, and interaction work
**When to Load**: When touching UI or view code
**Priority**: Must

## Intent

Preserve AsNeeded's existing SwiftUI conventions, accessibility support, and reusable design patterns.

## Must

- Search `AsNeeded/Views/Components/` before creating a new reusable UI pattern.
- Use `.customFont()` for text and add `@Environment(\\.fontFamily)` to views that render text.
- Use `.accent` for interactive elements instead of hard-coded blue.
- Use SFSafeSymbols in app targets.
- Use `.customNavigationTitle(...)` for navigation titles.
- Use `.noTruncate()` for critical medication names.

For architecture/concurrency, also load `ai-rules/ios-development.md`; for screen-level UX and visual verification, load `ai-rules/design-accessibility.md`.

## Established Patterns

- Important actions should prefer sticky bottom buttons with scrollable content above and a material or glass-backed action area below.
- A sheet with only an X in its navigation toolbar places it at `.topBarTrailing`. Keyboard accessories and sticky bottom actions do not change this rule. With other navigation-toolbar actions, retain native leading cancel and trailing confirmation/action placements.
- For iOS 26+ Liquid Glass work, prefer the existing `docs/LIQUID_GLASS.md` guidance.

## Avoid

- Hard-coded system fonts like `.body`.
- New one-off styling patterns when an existing component already covers the use case.
- Regressions in accessibility, dynamic type, or touch target size.

## Checklist

- [ ] Checked for an existing reusable component first
- [ ] Typography uses `.customFont()`
- [ ] Interactive color uses `.accent`

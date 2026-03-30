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

## Established Patterns

- Important actions should prefer sticky bottom buttons with scrollable content above and a material or glass-backed action area below.
- Sheet toolbars should use a leading close action and an accent-styled confirmation action unless a sticky bottom CTA replaces the trailing action.
- For iOS 26+ Liquid Glass work, prefer the existing `docs/LIQUID_GLASS.md` guidance.

## Avoid

- Hard-coded system fonts like `.body`.
- New one-off styling patterns when an existing component already covers the use case.
- Regressions in accessibility, dynamic type, or touch target size.

## Checklist

- [ ] Checked for an existing reusable component first
- [ ] Typography uses `.customFont()`
- [ ] Interactive color uses `.accent`

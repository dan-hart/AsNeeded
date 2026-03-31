# Repository Guidelines

## Purpose

AsNeeded is an iOS and watchOS SwiftUI app for tracking as-needed medications. Keep repository guidance portable and high-signal so any coding agent can follow it without relying on provider-specific tooling.

## AI Guidance Model

Always load:

- `AGENTS.md`
- `ai-rules/general.md`
- `ai-rules/rule-loading.md`

Then load only the additional rule files triggered by the current task.

Optional local enhancements such as Codex superpowers are allowed for maintainers, but they are never required for contributors and must never be a dependency for hooks, CI, builds, or tests. Keep machine-local config out of git. See `docs/ai/README.md`.

## Build And Verification

- Prefer the optimized scripts:
  - `./scripts/dev-build.sh`
  - `./scripts/test-parallel.sh`
  - `./scripts/prod-build.sh`
- Run the smallest relevant verification before claiming a change works.
- Never leave the repo in a broken state.
- Optional external review tools are fine when available, but they must never be required for contributors or CI.

## High-Signal Project Conventions

- Use tabs, not spaces.
- Use `// MARK:` comments with no blank line after the marker.
- Swift 6 and SwiftUI-first. Prefer `struct` for views and models; mark classes `final` when appropriate.
- Never use force unwraps in app code or tests.
- Use `Image(systemSymbol:)` from SFSafeSymbols except in watchOS targets.
- Use `.accent` for interactive color treatment.
- Use `.customFont()` for app text and add `@Environment(\\.fontFamily)` in views that render text.
- Use `.customNavigationTitle(...)` for navigation titles.
- Use `.noTruncate()` for critical medication names.
- Check `AsNeeded/Views/Components/` before creating new reusable UI patterns.
- Use strongly typed keys from `UserDefaultsKeys.swift` for `@AppStorage` and `UserDefaults`.

## Safety Rules

- Never commit secrets, tokens, private keys, or personal data.
- Treat `AsNeeded/Services/Persistence/`, `UserDefaultsKeys.swift`, and `Info.plist` as high-scrutiny areas.
- Read `ai-rules/storage-safety.md` before touching storage paths, persistence, migrations, or settings keys.
- Do not use destructive git commands like `git reset --hard` or `git checkout --` unless explicitly requested.
- Do not assume AI tooling is available on another contributor's machine unless the repo explicitly provides it as optional documentation.

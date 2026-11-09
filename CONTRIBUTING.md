# Contributing to AsNeeded

Help keep medication recording clear, dependable, accessible, and private. Please be respectful and constructive in issues and reviews.

## Choose the right branch and scope

Current release development is `task/v1.3.0`; target that branch for agreed 1.3.0 work. Use `main` for a maintainer-requested released-version fix. Confirm the intended base for other release work instead of assuming that an old plan or `develop` is current. Keep unrelated work in separate changes.

For bugs, describe expected/actual behavior, reproduction steps, app build, iOS/watchOS version, and device class. Use synthetic medication data. Redact private information from logs and screenshots. For features, explain the use case and agree scope before a broad implementation.

## Set up

1. Clone your fork and open `AsNeeded.xcodeproj` in a compatible Xcode with an installed iOS 26+ runtime.
2. Select the AsNeeded scheme and simulator. Device builds need your own signing setup.
3. Install the repository security hooks with `./scripts/install-hooks.sh`. The helper checks its scanner prerequisites; optional AI tools are never prerequisites.
4. Create a focused branch from the intended base, for example `task/history-filter-fix`.

Run `python3 scripts/doctor.py` for a read-only setup check, then `./scripts/dev-build.sh` for a simulator build. Xcode’s Product → Run installs and launches the app on the selected simulator. Device builds need an authorized signing team and profiles.

A clean clone works without purchase credentials. Optional local RevenueCat configuration and build/test commands are documented in [the README](README.md) and [scripts](scripts/README.md).

## Implement and review

- Follow [AGENTS.md](AGENTS.md) and load only relevant [rule modules](ai-rules/rule-loading.md).
- Use tabs, meaningful names, and `// MARK:` sections with no blank line immediately after the marker.
- Use `.accent` for interactive treatment, `.customFont()` with `fontFamily`, and `.customNavigationTitle(...)` for titles. Preserve critical medication names and units at large text sizes.
- Use SFSafeSymbols in iOS targets; watchOS is the exception.
- Keep business logic deterministic and testable. Inject time, storage/defaults, and external clients where needed; preserve existing state ownership.
- Read [storage safety](docs/DATA_STORAGE_GUIDELINES.md) before storage/migration work. Include upgrade, recovery, rollback, and repeated-launch verification when applicable.
- Update authoritative docs rather than adding duplicate instructions. Changes to [business rules](BUSINESS_RULES.md) and stale Drift bindings require a human maintainer decision in a PR before merge. Follow the [Drift review policy](docs/drift.md#required-human-review).

## Verify

Run the smallest relevant tests first, then `./scripts/test-parallel.sh` for broader changes. See [scripts](scripts/README.md) for destination/worker overrides and standalone regression commands. Use Swift Testing (`import Testing`, `@Test`, `#expect`), isolated synthetic fixtures, and behavior-based assertions. Avoid live network calls, shared preferences, stopwatch thresholds, and checks that pass without reaching their fixture.

No UI/snapshot-test target is needed. Inspect real screenshots/device behavior for UI changes; state the device/runtime and remaining accessibility/hardware gaps. A build pass is not evidence of notification delivery or an upgrade on a physical device.

Review the final diff and changed documentation links. Keep security scans enabled and never commit secrets, local signing assets, build output, or personal records. Stage only the intended files. Use an imperative commit message describing the change, and give PR reviewers the problem, resulting behavior, validation, and any material limits. Do not merge or publish a release without maintainer authorization.

## Repository navigation

[Current docs](docs/README.md) · [Architecture](docs/architecture.md) · [Design sources](Design/README.md) · [Optional AI tooling](docs/ai/README.md) · [Historical records](docs/archive/README.md)

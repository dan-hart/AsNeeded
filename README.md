# AsNeeded

[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2026%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-GPL--3.0-green.svg)](LICENSE.txt)

[![Build and tests](https://github.com/dan-hart/AsNeeded/actions/workflows/build.yml/badge.svg?branch=task%2Fv1.3.0)](https://github.com/dan-hart/AsNeeded/actions/workflows/build.yml)
[![Documentation freshness](https://github.com/dan-hart/AsNeeded/actions/workflows/drift.yml/badge.svg?branch=task%2Fv1.3.0)](https://github.com/dan-hart/AsNeeded/actions/workflows/drift.yml)
[![Security scan](https://github.com/dan-hart/AsNeeded/actions/workflows/security-scan.yml/badge.svg?branch=task%2Fv1.3.0)](https://github.com/dan-hart/AsNeeded/actions/workflows/security-scan.yml)


Track as-needed medication doses, review history, and keep clear records with local storage. All tracking features are free. Optional tips and recurring support purchases fund development and do not unlock features.

**[Download As Needed on the App Store](https://apps.apple.com/us/app/as-needed/id6714469235)**

<a href="https://apps.apple.com/us/app/as-needed/id6714469235"><img src="Design/AppStoreConnect/1.2.0/product-screenshots/iphone/01-medication.png" width="300" alt="As Needed medication list showing three fictional medications with distinct icons, colors, stock quantities, and Log buttons."></a>

*Approved 1.2.0 screenshot with synthetic demonstration data. Workflow badges track the latest runs on `task/v1.3.0`; they do not certify a release or physical-device behavior.*


AsNeeded records medication amounts and times, optional notes/reflections, stock, and refill information. Saved dose intervals and rolling 24-hour quantity limits provide guidance based on recorded doses; they are not medical clearance. Follow your prescription and care team's instructions.

## Start here

- [Contribute and set up development](CONTRIBUTING.md)
- [Current documentation](docs/README.md)
- [Features and business rules](BUSINESS_RULES.md)
- [Architecture and target ownership](docs/architecture.md)
- [Build and test scripts](scripts/README.md)
- [Design and App Store sources](Design/README.md)
- [Privacy](PRIVACY.md), [security](SECURITY.md), and [medical disclaimer](DISCLAIMER.md)

## Features

- Log now or backdate an entry; hold to quick-log a default dose and Undo the exact entry.
- Track quantities and units, notes, symptoms, effectiveness, and side effects.
- Review History and Trends with medication/date filters, including calendar-year and custom ranges.
- Save optional dose intervals and rolling quantity limits, track stock, and review refill information.
- Set scheduled reminders and optional next-dose alerts; control notification-name privacy and per-medication urgency.
- Access medication forms through widgets and Shortcuts, and record with the paired Watch app.
- Use Dynamic Type, accessible font choices, VoiceOver labels, Dark Mode, and localized interfaces.
- Export/import records and choose a local or cloud-backed folder for optional automatic backups.

Current development is on `task/v1.3.0`. The 1.2.0 release and its earlier plans/verification are [historical records](docs/archive/README.md), not the active work queue. The maintained [business-rule map](BUSINESS_RULES.md) describes current behavior and its regression tests.

## Build and run

Use Xcode 26 or later with an installed iOS 26+ SDK/runtime and the Swift 6 toolchain supported by the project. Open `AsNeeded.xcodeproj`, select the AsNeeded scheme, choose an available simulator, and run. Device testing requires your own signing team and profiles.

```bash
git clone https://github.com/dan-hart/AsNeeded.git
cd AsNeeded
python3 scripts/doctor.py
./scripts/dev-build.sh
```

The read-only doctor reports local setup blockers and optional configuration warnings without installing tools, changing Git settings, resolving packages, or accessing Keychain. Run `python3 scripts/doctor.py --json` for machine-readable output. The development script builds for a generic iOS Simulator by default; it does not install or launch the app. In Xcode, use Product → Run for the selected device. For CLI overrides, test execution, release checks, and security hooks, see [scripts](scripts/README.md).

A clean checkout builds without private packages or purchase configuration. To enable support purchases locally, copy `Config/Secrets.example.xcconfig` to the ignored `Config/Secrets.xcconfig` and supply your RevenueCat public SDK key. Without a usable key, tracking still works and purchases are unavailable. Never commit credentials or local signing assets.

## Repository map

```text
AsNeeded/Features/        Screens, UI state, and view models grouped by feature
AsNeeded/Views/Components/ Reusable UI shared across features
AsNeeded/Shared/          Target-neutral platform and wire contracts
AsNeeded/Services/        App logic, integrations, persistence, and recovery
AsNeeded/Models/          App-level value types
AsNeededWidget/           iOS widget extension and navigation intents
WristAsNeeded Watch App/  watchOS app and phone messaging
AsNeededTests/            Swift Testing suites and versioned upgrade fixtures
AsNeeded.xcodeproj/       Targets, schemes, test plan, and resolved packages
scripts/                 Read-only doctor, build/test/release helpers
docs/                    Current guidance, business rules, and historical archive
Design/                  Editable artwork and versioned release assets
skills/                  Optional reviewed development references and search data
ai-rules/                Focused, agent-neutral contributor rules
```

ANModelKit, Boutique, SwiftRxNorm, and the other Swift package dependencies are remotely resolved. There is no required local `Packages/` checkout. Target ownership and persistence/Watch boundaries are documented in [architecture](docs/architecture.md).

## Verification

```bash
./scripts/test-parallel.sh
```

The script chooses an available iPhone simulator. `TEST_DESTINATION` selects an explicit target and `TEST_WORKERS` controls parallel test runners. The Build workflow compiles the app and runs unit/standalone regressions for the maintained branches; documentation freshness has a separate pinned Drift check. Hosted success, local simulator tests, release signing, and physical-device upgrades are distinct evidence.

No UI or screenshot-test target is required. Use synthetic data for manual visual verification, and never attach private medication records to public issues or commits.

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md). Keep changes scoped, preserve stored data and supported upgrades, and test changed behavior. Optional agent skills and formatter/review tools are not required to build or contribute.

AsNeeded is licensed under [GPL-3.0](LICENSE.txt).

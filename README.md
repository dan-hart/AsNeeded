# AsNeeded

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-GPL--3.0-green.svg)](LICENSE)

Track as-needed medications with privacy and clarity.

AsNeeded is a privacy-first iOS app designed to help people track as-needed medications with calm, dependable tools for day-to-day self-management. It focuses on quick logging, saved safety guardrails, refill awareness, and clear insights so you always know what you took, when you took it, when you may be able to take more, and how your patterns are changing over time.

## Table of Contents
- [Core Values](#core-values)
- [Features](#features)
- [Getting Started](#getting-started)
- [Development](#development)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Privacy](#privacy)
- [License](#license)

## Core Values

AsNeeded is built on three fundamental principles:

- **Privacy First**: Your health data stays private, local, and secure
- **Always Free**: All features free forever, no ads, no subscriptions required
- **Open Source**: Transparent, inspectable, and community-driven

Note on terminology: Some clinicians use the abbreviation "PRN" (from Latin "pro re nata") to mean "as needed." In this project and README, we use the plain phrase "as-needed" to keep things universally understandable.

---

## Features

### Key Features

- **Privacy-first storage and insights**: Local-first data, no tracking, full export/import, and on-device Trends questions that never send your logs off-device for processing
- **Medication safety guardrails**: Saved intervals, duplicate-dose checks, daily limits, caution windows, and next-dose guidance
- **Richer logging**: Quick dose logging, voice shortcuts, backdated entries, and optional post-dose reflections for symptoms, effectiveness, side effects, and notes
- **Refill awareness**: Inventory tracking, low-stock warnings, refill lead-time guidance, and projected run-out dates
- **Usage insights**: Visual charts, searchable history, clinician-friendly export, and private question-based exploration of your data
- **Ambient access**: Home Screen widgets, Lock Screen widgets, Live Activities, interactive quick actions, and watchOS support
- **Accessibility**: Dynamic Type, VoiceOver, high-contrast support, and customizable typography

---

## Getting Started

### Requirements
- macOS 14.0+ with Xcode 16+
- iOS 18.0+ device or simulator
- Swift 6

### Installation

1. **Clone the repository**
   ```bash
   # Using SSH (recommended)
   git clone git@github.com:dan-hart/AsNeeded.git

   # Using HTTPS
   git clone https://github.com/dan-hart/AsNeeded.git
   ```

2. **Open the project**
   ```bash
   cd AsNeeded
   open AsNeeded.xcodeproj
   ```

3. **Configure signing (for device testing)**
   - Select the AsNeeded target
   - Go to Signing & Capabilities
   - Select your development team

4. **Build and run**
   - Select target device/simulator (iOS 18+)
   - Press ⌘R or click the Run button

5. **First launch**
   - Add your first medication from the Home or Medications screen
   - Configure its typical dose, interval, and refill settings (optional)
   - Log your first dose to see the next-dose guidance and history summaries in action

---

## Development

### Building from Command Line
```bash
# Build for simulator
xcodebuild -scheme AsNeeded -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild test -scheme AsNeeded -testPlan AsNeededTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Code Style
- Tabs for indentation (configured in .editorconfig)
- Line length: ~120 characters
- Use `// MARK: -` comments for organization
- Follow Swift API Design Guidelines
- SF Symbols: Always use SFSafeSymbols (e.g., `Image(systemSymbol: .pills)`)
- Colors: Use `.accent` for interactive elements

---

## Project Structure

The codebase is organized for clarity and modularity. Each SwiftUI view is in its own file and grouped by feature.

```
AsNeeded/
├── AsNeededApp.swift           # App entry point
├── Views/                      # UI Components
│   ├── Screens/               # Main app screens
│   └── Components/            # Reusable UI elements
├── Medication/                 # Medication features
├── Services/                   # Business logic & APIs
│   ├── Persistence/           # Data management
│   ├── NotificationManager    # Reminders
│   └── Intents/              # Siri integration
├── Packages/                   # Local Swift packages
│   ├── ANModelKit/            # Core models
│   ├── DHLoggingKit/          # Logging utilities
│   └── SwiftRxNorm/           # Medication search
└── Tests/                      # Test suite
```

### Package Architecture

- **ANModelKit**: Core data models (Medication, Dose, Event, Unit concepts)
- **DHLoggingKit**: Modern Swift logging with OSLog integration
- **SwiftRxNorm**: RxNorm API client for medication search and information
- **Main App**: SwiftUI interface, business logic, and service integration

---

## Architecture

Lightweight, testable architecture with Swift 6 and SwiftUI:

- **Domain-driven**: Pure Swift models with no UI dependencies
- **Protocol-based services**: Swappable persistence and notification implementations
- **SwiftUI composition**: Small, focused views with unidirectional data flow
- **Swift Concurrency**: async/await for I/O and background tasks
- **Unit tested**: Business logic covered with Swift Testing framework

---

## Core Models (ANModelKit)

- **ANMedicationConcept**: Tracked medications with clinical names, nicknames, inventory
- **ANDoseConcept**: Dose amounts with standardized units
- **ANEventConcept**: Logged events (doses taken, reconciliation, side effects)

See implementations in `Medication/` views and `AsNeededTests/ANModelKitTests.swift`

---

## Design & Accessibility

- **Accessibility**: Dynamic Type, VoiceOver, high contrast, reduced motion support, Light/Dark Mode
- **Design system**: Calm clinical presentation, semantic colors, typography, spacing tokens, reusable components
- **Localization-ready**: Centralized strings

---

## Testing

Swift Testing framework (`@Test`, `#expect`) with focus on business logic:

```bash
# Run tests
xcodebuild test -scheme AsNeeded -destination 'platform=iOS Simulator,name=iPhone 16'
```

In Xcode: Product → Test (⌘U). See `AsNeededTests/` for examples.

---

## Troubleshooting

**Build issues**: Clean (⌘⇧K), reset packages, delete DerivedData  
**Simulator**: Check `xcrun simctl list devices`, download the current supported runtime  
**Notifications**: Verify permissions in Settings and app Reminders  
**Tests**: Run `swift package resolve`, check test plan configuration

---

## Contributing

**Issues**: Search existing, include iOS version and repro steps  
**Pull Requests**: Fork, create feature branch, follow code style (tabs, MARK comments, SFSafeSymbols, `.accent`), add tests, submit to `main`  
**Guidelines**: No force unwraps, UI-free packages, test business logic

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## Privacy

Privacy-first design: local storage only, no data collection, no analytics, no ads, full export control, open source transparency. When supported and enabled, question-based Trends exploration is processed entirely on device. Your health data belongs to you.

---

## License

GNU General Public License v3.0 (GPL-3.0)
See LICENSE file for details.

---

## Contact

Questions or feedback? Open an issue on GitHub or start a discussion:
- Issues: https://github.com/dan-hart/AsNeeded/issues
- Discussions: https://github.com/dan-hart/AsNeeded/discussions

We'd love to hear how you're using AsNeeded and what would make it more helpful.

---

## HealthKit Support

AsNeeded currently does not support HealthKit integration for the following reasons:

### 1. Platform Independence
AsNeeded is designed to be a standalone medication tracking platform. Adding HealthKit sync would create confusion about where your data lives and fragment the user experience between multiple apps.

### 2. Apple Platform Restrictions
Apple does not allow third-party apps to write medication data to HealthKit. This would force users to log doses in the Health app but view trends in AsNeeded—a poor and confusing user experience.

### 3. Privacy & Data Control
Users choose AsNeeded for its simplicity and complete data privacy. Your medication data stays entirely on your device, never touching the cloud or external services. You have full control over your sensitive health information.

---

We're focused on making AsNeeded the best standalone medication tracker, with features like local backups and exports that give you control without compromising privacy or simplicity.

# AsNeeded

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-GPL--3.0-green.svg)](LICENSE)

Track as-needed medications with privacy and simplicity.

AsNeeded is a privacy-first iOS app designed to help people track as-needed medications with clarity and confidence. It focuses on quick logging, safe spacing between doses, and clear insights so you always know what you took, when you took it, and when it's safe to take more.

## Table of Contents
- [Core Values](#core-values)
- [Features](#features)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Development](#development)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [Privacy](#privacy)
- [License](#license)
- [Contact](#contact)

## Core Values

AsNeeded is built on three fundamental principles:

- **Privacy First**: Your health data stays private, local, and secure
- **Always Free**: All features free forever, no ads, no subscriptions required
- **Open Source**: Transparent, inspectable, and community-driven

Note on terminology: Some clinicians use the abbreviation "PRN" (from Latin "pro re nata") to mean "as needed." In this project and README, we use the plain phrase "as-needed" to keep things universally understandable.

---

## Features

### 🔒 Privacy & Data Management
- **Local-only storage**: All data stays on your device
- **Export & Import**: Full data backup and restore in JSON format
- **Data transparency**: View technical logs for troubleshooting
- **No tracking**: No analytics, no data collection, no cloud sync

### 💊 Medication Tracking
- **Smart medication search**: RxNorm integration for accurate medication lookup
- **Flexible dosing**: Support for 29 different unit types (tablets, mg, mL, puffs, etc.)
- **Inventory management**: Track quantity on hand and refill dates
- **Custom nicknames**: Use familiar names alongside clinical terms

### 📝 Dose Logging
- **Quick dose entry**: Log medications with customizable amounts and units
- **Historical logging**: Backdate doses with specific times
- **Smart defaults**: Remembers your preferred doses and units
- **Comprehensive tracking**: Full medication event history

### 🔔 Smart Reminders
- **Privacy-focused notifications**: Optional medication name display
- **Flexible scheduling**: One-time, daily, weekly, or custom intervals
- **Quick actions**: "Mark as Taken" and "Skip" directly from notifications
- **Permission-aware**: Graceful handling when notifications are disabled

### 📊 Insights & Analysis
- **Usage trends**: Visual charts showing medication usage over time
- **Calendar heatmap**: GitHub-style visualization of daily usage patterns
- **Usage statistics**: Average daily intake and usage metrics
- **Medication history**: Searchable, filterable event timeline

### 🎙️ Siri Integration
- **Voice logging**: "I took 2 tablets of ibuprofen in AsNeeded"
- **Usage queries**: "How much aspirin have I taken today in AsNeeded?"
- **Medication lists**: "List my medications in AsNeeded"
- **Smart recognition**: Supports both clinical names and your custom nicknames

### 🎨 User Experience
- **Clean, modern design**: SwiftUI-first with consistent styling
- **Onboarding flow**: Welcoming first-time user experience
- **Support integration**: Easy access to help and support options
- **Accessibility**: Dynamic Type, VoiceOver, and Dark Mode support

### 📱 Platform Features
- **iOS & watchOS**: Full iPhone app with Apple Watch companion
- **Handoff support**: Seamless transition between devices
- **Local persistence**: Reliable SQLite-based storage
- **Background processing**: Efficient data management

---

## Requirements

- macOS 14.0+ (Sonoma or later)
- Xcode 16 or newer
- iOS 18.0 or newer device or simulator
- Swift 6

---

## Getting Started

### Prerequisites
- macOS 14.0+ (Sonoma or later)
- Xcode 16+
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
   - Configure its minimum interval and typical dose (optional)
   - Log your first dose to see the "Next dose available" timer in action

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
- Colors: Use `.accentColor` for interactive elements

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

AsNeeded follows a lightweight, testable architecture built with Swift 6 and SwiftUI:

- Domain‑driven core
  - Pure Swift models and use cases define app behavior.
  - No UI or persistence code in domain types.
- Services via protocols
  - Persistence and Notifications are abstracted behind protocols.
  - Concrete implementations can be swapped (e.g., in‑memory for tests, SwiftData/Core Data for production).
- SwiftUI composition
  - Views are declarative, small, and focused.
  - State flows from feature view models or domain use cases into views.
- Concurrency
  - Swift Concurrency (async/await) for async work (I/O, notifications).
- Testability
  - Business logic covered with unit tests via the Swift Testing framework.

This structure keeps UI responsive, logic reusable, and features easy to evolve.

---

## Key Domain Types (from ANModelKit)

- ANMedicationConcept
  - A medication the user tracks (clinical name, optional nickname, quantity on hand, refill dates).
- ANDoseConcept
  - A dose with amount and unit (e.g., 400 milligram, 2 puffs).
- ANUnitConcept
  - Standardized units (milligram, tablet, puff, milliliter, etc.), with display names and abbreviations.
- ANEventConcept
  - A logged event (e.g., dose taken, reconciliation) associated with a medication and optional dose.
- ANEventType
  - The type of event (dose taken, reconcile, suspected side effect).

You can see these in action in:
- `Medication/LogDoseView.swift`
- `Medication/MedicationDetailView.swift`
- `AsNeededTests/ANModelKitTests.swift`

---

## Accessibility and Localization

- Dynamic Type: All text scales gracefully.
- VoiceOver: Controls have descriptive labels and hints.
- Contrast & Color: Colors meet contrast guidelines; supports Light/Dark Mode.
- Localization‑ready: Strings are centralized and prepared for localization.

Contributions to improve accessibility and localization are welcome.

---

## Design System

A small design system ensures consistency:
- Semantic color roles (background, primary, warning)
- Typography styles (title, headline, body, footnote)
- Spacing and corner radius tokens
- Reusable components (buttons, rows, empty states, badges)

---

## Testing

### Running Tests
```bash
# Run all tests
xcodebuild test -scheme AsNeeded -testPlan AsNeededTests

# Run with specific simulator
xcodebuild test -scheme AsNeeded -destination 'platform=iOS Simulator,name=iPhone 16'

# Generate coverage report
xcodebuild test -scheme AsNeeded -enableCodeCoverage YES
```

### In Xcode
- Run all tests: Product → Test (⌘U)
- Run specific test: Click the diamond next to test method
- View coverage: Editor → Show Code Coverage

### Test Coverage Goals
- Domain models: 95%+ coverage
- Services: 80%+ coverage
- View models: 70%+ coverage

### Writing Tests
Tests use Swift Testing framework (`@Test`, `#expect`). Example:
```swift
@Test func medicationInitialization() {
    let medication = ANMedicationConcept(name: "Ibuprofen")
    #expect(medication.name == "Ibuprofen")
}
```

See `AsNeededTests/` for more examples.

---

## Troubleshooting

### Common Issues

**Build fails with "No such module"**
- Clean build folder: ⌘⇧K
- Reset package caches: File → Packages → Reset Package Caches
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`

**Simulator not available**
- Check available simulators: `xcrun simctl list devices`
- Download iOS 18+ runtime: Xcode → Settings → Platforms
- Try: `xcodebuild -showdestinations -scheme AsNeeded`

**Notifications not working**
- Ensure notification permissions are granted in Settings
- Check notification settings in the app's Reminders section
- Verify `NotificationManager` is properly initialized

**Tests failing**
- Ensure all packages are resolved: `swift package resolve`
- Check test plan configuration in Xcode
- Run tests individually to isolate failures

---

## Contributing

We welcome contributions! Here's how to get started:

### Reporting Issues
- Search existing issues first
- Include iOS version, device model, and steps to reproduce
- Attach screenshots for UI issues
- Use issue templates when available

### Submitting Pull Requests
1. Fork and create a feature branch (`feature/your-feature`)
2. Follow existing code patterns and style:
   - Use tabs for indentation
   - Add `// MARK: -` comments for organization
   - Use SFSafeSymbols for icons
   - Use `.accentColor` for interactive elements
3. Add tests for new functionality
4. Update documentation as needed
5. Submit PR against `develop` branch

### Code Review Process
- All PRs require one approval
- CI must pass (tests, build verification)
- Maintainers may request changes
- Be patient and respectful

### Development Guidelines
- No force unwraps (`!`) in code or tests
- Keep packages UI-free (ANModelKit, SwiftRxNorm)
- Test business logic, not UI
- Follow Swift API Design Guidelines

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## Privacy

AsNeeded is designed with privacy as a core principle:

- **Local-only storage**: All medication data stays on your device
- **No data collection**: We don't collect, store, or transmit any personal health information
- **No analytics**: No usage tracking, no crash reporting, no behavioral analytics
- **No ads**: No advertising networks or data brokers involved
- **Export control**: You maintain full control over your data exports
- **Open source**: All code is transparent and inspectable

Your health data belongs to you. AsNeeded will never compromise on this principle.

---

## License

GNU General Public License v3.0 (GPL-3.0)
See LICENSE file for details.

---

## Contact

Questions or feedback? Open an issue on GitHub or start a discussion:
- Issues: https://github.com/dan-hart/AsNeeded/issues
- Discussions: https://github.com/dan-hart/AsNeeded/discussions

We’d love to hear how you’re using AsNeeded and what would make it more helpful.


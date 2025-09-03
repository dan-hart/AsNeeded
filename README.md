# AsNeeded

Track as-needed medications with privacy and simplicity.

AsNeeded is a privacy-first iOS app designed to help people track as‑needed medications with clarity and confidence. It focuses on quick logging, safe spacing between doses, and clear insights so you always know what you took, when you took it, and when it's safe to take more.

## Core Values

AsNeeded is built on three fundamental principles:

- **Privacy First**: Your health data stays private, local, and secure
- **Always Free**: All features free forever, no ads, no subscriptions required  
- **Open Source**: Transparent, inspectable, and community-driven

Note on terminology: Some clinicians use the abbreviation "PRN" (from Latin "pro re nata") to mean "as needed." In this project and README, we use the plain phrase "as‑needed" to keep things universally understandable.

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

- Xcode 16 or newer
- iOS 18.0 or newer
- Swift 6

---

## Getting Started

1. Clone the repository
   - Using SSH:
`git clone git@github.com:dan-hart/AsNeeded.git`
    - Using HTTPS:
`git clone https://github.com/dan-hart/AsNeeded.git`
2. Open the project
   - Double‑click `AsNeeded.xcodeproj` (or `AsNeeded.xcworkspace` if present).
   - Select the `AsNeeded` app target.

3. Build and run
   - Choose an iOS 18+ simulator (e.g., iPhone).
   - Press Run (⌘R).

4. First launch
   - Add your first medication from the Home or Medications screen.
   - (Optional) Configure its minimum interval and typical dose.
   - Log your first dose to see the “Next dose available” timer in action.

---

## Project Structure

The codebase is organized for clarity and modularity. Each SwiftUI view is in its own file and grouped by feature.

```
AsNeeded/
├── AsNeededApp.swift                     # App entry point and scene configuration
├── Views/
│   ├── Screens/                         # Main screen views
│   │   ├── AboutView.swift             # App information and core values
│   │   ├── SupportView.swift           # Support options and donation
│   │   ├── WelcomeView.swift           # First-time user onboarding
│   │   ├── DataManagementView.swift    # Export/import functionality
│   │   ├── MedicationHistoryView.swift # Historical dose logging
│   │   └── MedicationTrendsView.swift  # Usage analytics and charts
│   ├── ContentView.swift               # Main tab view container
│   └── Components/                     # Reusable UI components
│       ├── SupportToastView.swift      # Support prompt overlay
│       └── EnhancedMedicationSearchField.swift # Smart search input
├── Medication/                         # Medication management features
│   ├── MedicationListView.swift        # List and search medications
│   ├── MedicationDetailView.swift      # Medication details and actions
│   ├── MedicationEditView.swift        # Add/edit medication form
│   ├── LogDoseView.swift               # Log dose entry form
│   ├── ReminderConfigurationView.swift # Notification setup
│   ├── ReminderListView.swift          # View scheduled reminders
│   └── ViewModels/                     # View model classes
├── Services/
│   ├── Persistence/
│   │   └── DataStore.swift             # Boutique-based data management
│   ├── NotificationManager.swift       # Local notification handling
│   ├── MedicationSearchService.swift   # RxNorm integration
│   ├── FeedbackService.swift           # User feedback handling
│   ├── WatchConnectivity/              # Apple Watch integration
│   └── Intents/                        # Siri Shortcuts integration
│       ├── LogMedicationIntent.swift   # "Log medication" voice command
│       ├── ListMedicationsIntent.swift # "List medications" query
│       ├── GetDailyUsageIntent.swift   # "How much today" query
│       ├── MedicationEntity.swift      # Siri medication recognition
│       └── MedicationUnitEntity.swift  # Siri unit recognition
├── Packages/                           # Local Swift packages
│   ├── ANModelKit/                     # Core data models and types
│   ├── DHLoggingKit/                   # Modern OSLog wrapper
│   └── SwiftRxNorm/                    # RxNorm API client
└── Tests/                              # Unit and integration tests
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
- Features/Log/LogDoseView.swift
- Features/Medications/MedicationDetailView.swift
- Tests/ANModelKitTests.swift

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

## Running Tests

- In Xcode: Product > Test (⌘U)
- The suite `ANModelKitTests.swift` demonstrates:
  - Model initialization for medication, dose, and events
  - Codable round‑trips for units and event types
  - CaseIterable, Equatable, and Hashable behavior

---

## Contributing

Contributions are welcome!

- Open an issue to discuss ideas or bugs.
- Fork the repo and create a feature branch.
- Follow the existing code style and architectural patterns.
- Include tests for new logic.
- Submit a PR with a clear description and screenshots if UI changes.

Please be respectful and constructive in discussions and code reviews.

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


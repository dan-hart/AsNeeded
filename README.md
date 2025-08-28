# AsNeeded

Clarity for medications used when symptoms arise.

AsNeeded is an iOS app designed to help people track as‑needed medications with clarity and confidence. It focuses on quick logging, safe spacing between doses, and clear insights so you always know what you took, when you took it, and when it’s safe to take more.

Note on terminology: Some clinicians use the abbreviation “PRN” (from Latin “pro re nata”) to mean “as needed.” In this project and README, we use the plain phrase “as‑needed” to keep things universally understandable.

---

## Features

- Track as‑needed medications with dose, time, and optional notes
- Enforce safe intervals between doses (configurable per medication)
- Quick‑add from Home with recent medications
- Clear “Next dose available” countdown and alerts
- Searchable history with filters and basic statistics
- SwiftUI‑first design with Dynamic Type, VoiceOver, and Dark Mode support
- Local persistence (designed to be storage‑agnostic)
- Modular architecture with testable business logic

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

- App/
  - AsNeededApp.swift — App entry point and scene configuration.
- Features/
  - Home/
    - HomeView.swift — Overview of recent meds, quick‑add actions, next‑dose timers.
  - Medications/
    - MedicationsListView.swift — List, search, and manage medications.
    - MedicationDetailView.swift — Details, dose logging, quantity and refill info.
    - AddEditMedicationView.swift — Create or edit a medication.
  - Log/
    - LogDoseView.swift — Add a dose with amount, unit, and notes.
    - HistoryView.swift — Dose history with filters and search.
- Components/
  - Shared reusable UI (e.g., PrimaryButton.swift, LabeledValueRow.swift, EmptyStateView.swift).
- Services/
  - Persistence/ — Storage interfaces and implementations.
  - Notifications/ — Local notifications for reminders (optional).
  - Analytics/ — Lightweight analytics hooks (optional).
- Domain/
  - Models/ — Core models (Medication, Dose, Event, Unit).
  - UseCases/ — Testable business logic (e.g., LogDoseUseCase, NextDoseCalculator).
- Support/
  - Extensions/ — Small, well‑scoped extensions.
  - DesignSystem/ — Colors, typography, spacing, and theming.
- Tests/
  - Unit tests for domain and services.
  - UI tests for critical flows (optional).
- README.md — You are here.

Note: File names above reflect intent; the actual repository may use similar names. Each view is self‑contained and reusable. Business logic is separated from rendering.

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

AsNeeded stores your data locally on‑device by default. If a cloud or sync feature is enabled in the future, the README and in‑app disclosures will be updated. The project does not collect personal data.

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


# Repository Guidelines

## Project Structure & Modules
- `AsNeeded/`: App sources (SwiftUI views, domain, services, assets). Example: `AsNeeded/Medication`, `AsNeeded/Views`, `AsNeeded/Extensions`.
- `AsNeeded.xcodeproj`: Xcode project and schemes.
- `AsNeededTests/`: Swift Testing tests (`import Testing`), includes `AsNeeded.xctestplan`.
- `WristAsNeeded Watch App/`: watchOS companion app.
- `build/`: Local build artifacts (ignored in VCS).

## Build, Test, Run
- Build (CLI): `xcodebuild -project AsNeeded.xcodeproj -scheme AsNeeded -configuration Debug build`.
- Run (Xcode): Open `AsNeeded.xcodeproj`, select an iOS 18+ simulator, press Run (⌘R).
- Tests (Xcode): Product → Test (⌘U).
- Tests (CLI): `xcodebuild test -project AsNeeded.xcodeproj -scheme AsNeeded -testPlan AsNeededTests -destination 'platform=iOS Simulator,name=iPhone 16'`.

## Coding Style & Naming
- Indentation: 2 spaces; wrap at ~120 cols.
- Swift 6, SwiftUI first; prefer `struct` for models/views; mark `final` for classes.
- Access control: keep minimal (default `internal`); prefer small, focused extensions in `AsNeeded/Extensions`.
- Protocol‑oriented services; inject dependencies for testability.
- Naming: Views end with `View` (e.g., `MedicationDetailView`), tests end with `Tests` (e.g., `AsNeededTests`). Filenames match primary type.

## Architecture Overview
- Domain: Pure models and use cases that encode business rules; no UI or persistence code. Keep calculation/validation logic here.
- Services: Protocol‑backed adapters (e.g., persistence, notifications). Provide swappable implementations and inject into features/tests.
- Views: Small SwiftUI views composed from domain state; avoid side effects. Prefer unidirectional data flow.
- Concurrency: Use async/await for I/O and scheduling; keep domain synchronous where possible for testability.
- Adding features: Create/extend a use case for behavior, add a service protocol if needed, then compose in a new `...View`.

## Data Store Usage
- Centralized store: Use `DataStore.shared` for Boutique access (`medicationsStore`, `eventsStore`).
- No direct Store in views: Interact via view models that depend on `DataStore` (inject in init for testability).
- Helpers: Prefer `DataStore` ops (`addMedication`, `updateMedication`, `deleteMedication`, `addEvent`) over raw insert/remove.
- Tests: Inject `DataStore` and, if needed, adapt it to use in‑memory storage; avoid file‑backed stores in tests.

## Package Boundaries
- No SwiftUI in packages: Do not add any SwiftUI code or imports to `AsNeeded/Packages/ANModelKit` or `AsNeeded/Packages/SwiftRxNorm`. These packages must remain UI‑free (domain models, use cases, networking only).
- UI lives in app targets: Place SwiftUI views and UI helpers under `AsNeeded/` (e.g., `Views/`, `Medication/`). Keep packages platform‑agnostic and testable.

## Testing Guidelines
- Framework: Swift Testing (`import Testing`, `@Test`, `#expect`).
- Scope: Unit tests for domain and services; add UI tests for critical flows when feasible.
- Conventions: Mirror source folder structure under `AsNeededTests`. Name tests descriptively, one behavior per test.
- Coverage: Aim for high coverage of business logic (calculators, use cases) over UI.

## Commits & Pull Requests
- Commits: Imperative, concise subject lines (e.g., "Add ANModelKit", "Refactor history view"). Group related changes.
- PRs: Clear description, rationale, and screenshots for UI changes. Link issues (e.g., "Closes #123"). Include test plan and notes on risk.
- Requirements: All tests pass locally; no unrelated formatting churn; update README/docs when behavior changes.

## Security & Configuration
- Do not commit signing certs, profiles, or secrets. Keep entitlements as‑is (`AsNeeded.entitlements`, watch entitlements).
- Verify `Info.plist` changes (e.g., `ITSAppUsesNonExemptEncryption`) are intentional.
- Local dev: Use a personal team for signing; avoid editing shared project settings unless necessary.

## Agent-Specific Instructions
> Take a deep breath, You are an expert in Swift 6, Xcode 26, and iOS 26. Also a skilled designer, you know how to write code that is clean, performant, and provides a good user experience. If there is a README, take a look and make sure all directives are followed. You prioritize architectural best practices by making SwiftUI views easy to re-use, always putting them in their own file according to functionality. Adhering to Apple, SwiftUI, and Swift6 best practices is of utmost importance.

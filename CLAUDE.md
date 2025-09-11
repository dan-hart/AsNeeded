# Repository Guidelines

## Project Structure & Modules
- `AsNeeded/`: App sources (SwiftUI views, domain, services, assets). Example: `AsNeeded/Medication`, `AsNeeded/Views`, `AsNeeded/Extensions`.
- `AsNeeded.xcodeproj`: Xcode project and schemes.
- `AsNeededTests/`: Swift Testing tests (`import Testing`), includes `AsNeeded.xctestplan`.
- `WristAsNeeded Watch App/`: watchOS companion app.
- `build/`: Local build artifacts (ignored in VCS).

## Build, Test, Run
- Build (CLI): `xcodebuild -project AsNeeded.xcodeproj -scheme AsNeeded -configuration Debug build`.
- Run (Xcode): Open `AsNeeded.xcodeproj`, select an iOS 18.6+ simulator, press Run (⌘R).
- Tests (Xcode): Product → Test (⌘U).
- Tests (CLI): `xcodebuild test -project AsNeeded.xcodeproj -scheme AsNeeded -testPlan AsNeededTests -destination 'platform=iOS Simulator,name=iPhone 16'`.

## Coding Style & Naming
- **Indentation**: Use tabs (not spaces) for indentation; wrap at ~120 cols.
- **Code Organization**: Use MARK comments to organize code sections (e.g., `// MARK: - Properties`, `// MARK: - View Components`, `// MARK: - Private Methods`). No blank lines should appear directly after MARK comments - code should begin immediately on the next line.
- **SF Symbols**: ALWAYS use SFSafeSymbols instead of string literals. Import `SFSafeSymbols` and use `systemSymbol:` for both Images AND Labels (e.g., `Image(systemSymbol: .pills)` not `Image(systemName: "pills")`, `Label("Text", systemSymbol: .pills)` not `Label("Text", systemImage: "pills")`). Function parameters should use `SFSymbol` type instead of `String`. Exception: WatchOS targets where SFSafeSymbols is not available - use string literals there.
- **Colors**: ALWAYS use `.accentColor` instead of `.blue` for interactive elements and tint colors. This ensures the app respects user's system-wide color preferences and maintains consistency across the UI. Use `.blue` only when specifically required for non-interactive content.
- **Typography**: NEVER use hardcoded font sizes (e.g., `.font(.system(size: 16))`). Always use semantic font styles (e.g., `.font(.body)`, `.font(.headline)`, `.font(.caption)`) to support Dynamic Type accessibility. Use font weights with semantic sizes (e.g., `.font(.body.weight(.medium))`).
- Swift 6, SwiftUI first; prefer `struct` for models/views; mark `final` for classes.
- Access control: keep minimal (default `internal`); prefer small, focused extensions in `AsNeeded/Extensions`.
- Protocol‑oriented services; inject dependencies for testability.
- Naming: Views end with `View` (e.g., `MedicationDetailView`), tests end with `Tests` (e.g., `AsNeededTests`). Filenames match primary type.
- **No force unwraps**: Avoid force unwraps (`!`) in both app code AND tests. Use safe unwrapping with `guard let`, `if let`, or optional chaining to prevent runtime crashes.

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
- Scope: Unit tests for domain and services ONLY. No UI tests, snapshot tests, or view testing.
- Conventions: Mirror source folder structure under `AsNeededTests`. Name tests descriptively, one behavior per test.
- Coverage: Focus exclusively on business logic, calculators, use cases, view models, and services.
- **NO UI/Snapshot Testing**: Do not create any UI tests, snapshot tests, or view-specific tests. Test view models and business logic only.

## Commits & Pull Requests
- Commits: Imperative, concise subject lines (e.g., "Add ANModelKit", "Refactor history view"). Group related changes.
- PRs: Clear description, rationale, and screenshots for UI changes. Link issues (e.g., "Closes #123"). Include test plan and notes on risk.
- Requirements: All tests pass locally; no unrelated formatting churn; update README/docs when behavior changes.

## Security & Configuration
- Do not commit signing certs, profiles, or secrets. Keep entitlements as‑is (`AsNeeded.entitlements`, watch entitlements).
- Verify `Info.plist` changes (e.g., `ITSAppUsesNonExemptEncryption`) are intentional.
- Local dev: Use a personal team for signing; avoid editing shared project settings unless necessary.

## .gitignore Requirements
- **Build artifacts**: Ensure all build folders (`.build/`, `Build/`, `DerivedData/`) are ignored
- **Xcode user data**: All user-specific files (`*.xcuserstate`, `xcuserdata/`, `.swiftpm/xcode/`)
- **macOS system files**: `.DS_Store` files must be ignored and removed from tracking
- **Swift Package Manager**: Ignore `.swiftpm/configuration/` and generated workspace files
- **Package dependencies**: Ignore `Packages/` directories and cached builds
- The main .gitignore should include comprehensive iOS/Swift exclusions for build artifacts, user data, and system files

## Agent-Specific Instructions
> Take a deep breath, You are an expert in Swift 6, Xcode 26, and iOS 26. Also a skilled designer, you know how to write code that is clean, performant, and provides a good user experience. If there is a README, take a look and make sure all directives are followed. You prioritize architectural best practices by making SwiftUI views easy to re-use, always putting them in their own file according to functionality. Adhering to Apple, SwiftUI, and Swift 6 best practices is of utmost importance.

### Critical Build Verification Requirement
**ALWAYS verify the app builds successfully after making large changes.** This is mandatory and non-negotiable:

1. **After significant code changes**: Run `xcodebuild -scheme AsNeeded -destination 'platform=iOS Simulator,name=iPhone 15' build` to verify the build succeeds.
2. **Before completing tasks**: Ensure the build is working and all new files are properly added to the Xcode project.
3. **When adding new files**: Verify files are added to the Xcode project and included in the build phase - files on disk are not automatically included.
4. **When modifying dependencies**: Test that imports resolve correctly and all required initializers/methods are public.
5. **Build failure response**: If builds fail, immediately investigate and fix compilation errors before proceeding with other work.

**Build testing commands:**
- Quick build: `xcodebuild -scheme AsNeeded -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet`
- Syntax check: `swiftc -parse [file_path]` for individual files
- Clean build: `xcodebuild -scheme AsNeeded clean build`
- **IMPORTANT**: Always check available simulators first with `xcodebuild -showdestinations -scheme AsNeeded` if builds fail. Use an available simulator (e.g., iPhone 16, iPhone 16 Pro) instead of wasting time on unavailable ones.

**Never leave the project in a broken state.** A working build is the foundation for all development work.

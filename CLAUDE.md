# Repository Guidelines

## Project Structure & Modules
- `AsNeeded/`: App sources (SwiftUI views, domain, services, assets). Example: `AsNeeded/Medication`, `AsNeeded/Views`, `AsNeeded/Extensions`.
- `AsNeeded.xcodeproj`: Xcode project and schemes.
- `AsNeededTests/`: Swift Testing tests (`import Testing`), includes `AsNeeded.xctestplan`.
- `WristAsNeeded Watch App/`: watchOS companion app.
- `build/`: Local build artifacts (ignored in VCS).

## Build, Test, Run

### Quick Start (Optimized Scripts)
**ALWAYS use these optimized scripts for maximum performance:**
- **Development build**: `./scripts/dev-build.sh` - Ultra-fast incremental builds using all 16 CPU cores
- **Run tests**: `./scripts/test-parallel.sh` - Parallel test execution (12 parallel workers)
- **Production build**: `./scripts/prod-build.sh` - Optimized release builds
- **Weekly cleanup**: `./scripts/clean-deriveddata.sh --asneeded` - Remove ~2.6GB of build cache

See `scripts/README.md` for complete documentation.

### Manual Build Commands (Fallback)
- **xcsift installation** (required): `brew tap ldomaradzki/xcsift && brew install xcsift` - Parses xcodebuild output into structured JSON.
- Build (CLI - Preferred): `xcodebuild -project AsNeeded.xcodeproj -scheme AsNeeded -configuration Debug build -quiet 2>&1 | xcsift`
- Build (CLI - Standard): `xcodebuild -project AsNeeded.xcodeproj -scheme AsNeeded -configuration Debug build`
- Run (Xcode): Open `AsNeeded.xcodeproj`, select an iOS 18.6+ simulator, press Run (⌘R)
- Tests (Xcode): Product → Test (⌘U)
- Tests (CLI): `xcodebuild test -project AsNeeded.xcodeproj -scheme AsNeeded -testPlan AsNeededTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcsift`

## Coding Style & Naming
- **Indentation**: Use tabs (not spaces) for indentation; wrap at ~120 cols.
- **Code Organization**: Use MARK comments to organize code sections (e.g., `// MARK: - Properties`, `// MARK: - View Components`, `// MARK: - Private Methods`). No blank lines should appear directly after MARK comments - code should begin immediately on the next line.
- **Semantic Naming**: Use semantic names for constants, not value-based names. Name variables based on their purpose, not their current value. This improves maintainability when values change.
  - ✅ CORRECT: `private var cardSpacing: CGFloat = 24`, `private var sectionPadding: CGFloat = 16`, `private var cornerRadius: CGFloat = 12`
  - ❌ WRONG: `private var spacing24: CGFloat = 24`, `private var padding16: CGFloat = 16`, `private var radius12: CGFloat = 12`
- **SF Symbols**: ALWAYS use SFSafeSymbols instead of string literals. Import `SFSafeSymbols` and use `systemSymbol:` for both Images AND Labels (e.g., `Image(systemSymbol: .pills)` not `Image(systemName: "pills")`, `Label("Text", systemSymbol: .pills)` not `Label("Text", systemImage: "pills")`). Function parameters should use `SFSymbol` type instead of `String`. Exception: WatchOS targets where SFSafeSymbols is not available - use string literals there.
- **Colors**:
  - ALWAYS use `.accent` instead of `.blue` for interactive elements and tint colors. This ensures the app respects user's system-wide color preferences and maintains consistency across the UI. Use `.blue` only when specifically required for non-interactive content. For tappable elements like buttons or links, use `.foregroundStyle(.accent)`.
  - **CRITICAL**: ALWAYS use `.accent` instead of `Color.accentColor`. The shorthand `.accent` is the modern SwiftUI approach and ensures the app's custom accent color is used, not the system default.
    - ✅ CORRECT: `.foregroundStyle(.accent)`, `.fill(.accent.opacity(0.1))`, `.tint(.accent)`
    - ❌ WRONG: `.foregroundStyle(Color.accentColor)`, `.fill(Color.accentColor.opacity(0.1))`, `.tint(Color.accentColor)`
  - All toolbar confirmation buttons (checkmarks) must have explicit `.foregroundStyle(.accent)` to ensure they use the app's accent color.
- **Typography & Custom Fonts**:
  - NEVER use hardcoded font sizes (e.g., `.font(.system(size: 16))`). Always use semantic font styles to support Dynamic Type accessibility.
  - **CRITICAL**: ALWAYS use `.customFont()` instead of semantic styles directly to support user-selected accessibility fonts:
    - ✅ CORRECT: `.font(.customFont(fontFamily, style: .body))`
    - ✅ CORRECT: `.font(.customFont(fontFamily, style: .headline, weight: .semibold))`
    - ❌ WRONG: `.font(.body)` or `.font(.headline)`
  - **Environment Setup**: Add `@Environment(\.fontFamily) private var fontFamily` to ALL views that display text
  - **Special Cases**:
    - Pickers: Apply `.font(.customFont(...))` to BOTH the picker AND each picker item
    - Segmented Controls: Apply fonts to the picker itself AND each option/label
    - Section Headers: `Section(header: Text("Title").font(.customFont(fontFamily, style: .subheadline)))`
    - Toolbar Buttons: Always use `.font(.customFont(fontFamily, style: .body, weight: .medium))`
    - Navigation Titles: Use `.customNavigationTitle("Title")` modifier for inline titles (large titles handled automatically by NavigationBarAppearanceManager)
  - **Performance**: The app uses `NavigationBarAppearanceManager` for global navigation bar fonts and caches font instances for performance
  - **Text Truncation & Growth**:
    - Use `.noTruncate()` for critical text that must never truncate (medication names, important labels)
    - Use `.lineLimit(n)` for preview text or when consistent row height is needed
    - ✅ CORRECT: `Text(medication.clinicalName).noTruncate()` - Clinical names always fully visible
    - ❌ WRONG: `Text(medication.clinicalName).lineLimit(1)` - May hide important medical information
    - The `.noTruncate()` modifier is especially important for accessibility and Dynamic Type support
    - Extension: `AsNeeded/Extensions/View+NoTruncate.swift`
- **Component Reusability**: ALWAYS search for existing reusable components in `AsNeeded/Views/Components/` before creating new UI elements. If a similar pattern exists, use or extend the existing component. When creating new views, prioritize making them reusable by extracting common UI patterns into standalone components. Examples: `SettingsRowComponent`, `SupportToastView`, `FeedbackButtonsView`. Create components for any UI pattern used in 2+ places.

## UI Patterns

### Sticky Bottom Buttons
For important actions (save, submit, log), use a sticky button pattern at the bottom of views instead of toolbar buttons:
- **Structure**: `VStack(spacing: 0)` containing scrollable content and sticky button container
- **Button container**: Includes `Divider()` with `.separator.opacity(0.5)` and button with appropriate padding
- **Background**: `.regularMaterial` for the button container
- **Examples**: LogDoseView, ColorPickerComponent, ExpandableNoteEditorComponent, MedicationHistoryView note editing
- **Benefits**: Primary action always visible, better accessibility, consistent across screen sizes

### Sheet Toolbar Patterns
All sheets and modal views must follow iOS 26 toolbar conventions for consistency:
- **Cancel action** (leading): Plain X icon (`Image(systemSymbol: .xmark)`) - no glass backgrounds, no text labels
- **Confirmation action** (trailing): Large plain checkmark (`Image(systemSymbol: .checkmark)`) with accent/medication color - no circle in the symbol
- **Font styling**: Cancel uses `.font(.customFont(fontFamily, style: .body, weight: .medium))`, confirmation uses `.font(.customFont(fontFamily, style: .title2, weight: .semibold))` for larger, more prominent appearance
- **Exception**: Sheets with sticky bottom CTA buttons should have NO top trailing confirmation button (only cancel X on leading side)
- Examples:
  ```swift
  // Standard sheet with both toolbar buttons
  .toolbar {
      ToolbarItem(placement: .cancellationAction) {
          Button { dismiss() } label: {
              Image(systemSymbol: .xmark)
                  .font(.customFont(fontFamily, style: .body, weight: .medium))
                  .foregroundStyle(.secondary)
          }
      }
      ToolbarItem(placement: .confirmationAction) {
          Button { performSave() } label: {
              Image(systemSymbol: .checkmark)
                  .font(.customFont(fontFamily, style: .title2, weight: .semibold))
                  .foregroundStyle(.accent)
          }
      }
  }

  // Sheet with sticky bottom CTA (only cancel button)
  .toolbar {
      ToolbarItem(placement: .cancellationAction) {
          Button { dismiss() } label: {
              Image(systemSymbol: .xmark)
                  .font(.customFont(fontFamily, style: .body, weight: .medium))
                  .foregroundStyle(.secondary)
          }
      }
  }
  ```

### Keyboard Focus in Sheets
When presenting sheets with text input that should auto-focus:
- Use `@FocusState` with the text field
- **Preferred**: Use `TextField` with `.axis(.vertical)` instead of `TextEditor` for better focus reliability
- Apply focus with 0.3s delay using both approaches for redundancy:
  - `.onChange(of: isPresented)` in the parent view
  - `.task` modifier in the sheet content
- Example:
  ```swift
  .onChange(of: isExpanded) { _, newValue in
      if newValue {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
              focusState = true
          }
      }
  }
  ```
- This minimal delay accounts for sheet presentation animation

### Liquid Glass Design (iOS 26+)
The app follows Apple's iOS 26 Liquid Glass design language for modern, translucent interfaces. See complete guide: **[docs/LIQUID_GLASS.md](docs/LIQUID_GLASS.md)**

**Quick Reference:**
- **Primary modifier**: `.glassEffect(.regular)` replaces `.regularMaterial`
- **Interactive controls**: Use `.glassEffect(.regular.interactive(true))` for all buttons
- **Tinted glass**: `.glassEffect(.regular.tint(.accent.opacity(0.3)))` for primary actions
- **Shape preference**: Use `Capsule()` for controls, `RoundedRectangle(cornerRadius:, style: .continuous)` for cards
- **Avoid**: Glass-on-glass stacking; use solid backgrounds for nested content

**Common Patterns:**
```swift
// Glass card (current implementation in GlassCardModifier)
.background {
	RoundedRectangle(cornerRadius: 20, style: .continuous)
		.glassEffect(.regular)
}

// Interactive button
Button("Action") { ... }
	.background {
		Capsule()
			.glassEffect(.regular.interactive(true))
	}

// Tinted CTA
.background {
	Capsule()
		.fill(.accent.gradient)
		.glassEffect(.regular.tint(.accent.opacity(0.2)))
}
```

**Documentation Contents:**
- Core principles and layer hierarchy
- Technical implementation with code examples
- Current app analysis and recommendations
- Migration guide from pre-iOS 26 materials
- Accessibility considerations
- Best practices and anti-patterns

## Feature Toggle System

The app includes a feature toggle system for managing experimental or debug features:
- **FeatureToggleManager**: Centralized manager (`AsNeeded/Services/FeatureToggleManager.swift`)
- **Debug-only**: Feature toggles are only available in DEBUG builds
- **Settings UI**: Toggle switches appear in Settings > Debug section
- **Default OFF**: All experimental features default to OFF
- **Current toggles**:
  - `quickPhrasesEnabled`: Shows/hides quick phrase suggestions in note editor

To add a new feature toggle:
1. Add key to UserDefaultsKeys constants: `static let featureToggleMyFeature = "featureToggle.myFeature"`
2. Add to `allKeys` array and `defaultValues` dictionary (default to `false`)
3. Add property to FeatureToggleManager: `@AppStorage(UserDefaultsKeys.featureToggleMyFeature) var myFeatureEnabled: Bool = false`
4. Add UI toggle in SettingsDebugSectionView
5. Check toggle in your component: `if featureToggleManager.myFeatureEnabled { ... }`

## Code Style

- Swift 6, SwiftUI first; prefer `struct` for models/views; mark `final` for classes.
- Access control: keep minimal (default `internal`); prefer small, focused extensions in `AsNeeded/Extensions`.
- Protocol‑oriented services; inject dependencies for testability.
- Naming: Views end with `View` (e.g., `MedicationDetailView`), tests end with `Tests` (e.g., `AsNeededTests`). Filenames match primary type.
- **No force unwraps**: Avoid force unwraps (`!`) in both app code AND tests. Use safe unwrapping with `guard let`, `if let`, or optional chaining to prevent runtime crashes.

## UserDefaults & AppStorage Best Practices

**ALWAYS use strongly-typed keys from `UserDefaultsKeys.swift` for all UserDefaults and AppStorage usage:**

- **Location**: All keys are centralized in `AsNeeded/Constants/UserDefaultsKeys.swift`
- **AppStorage usage**: `@AppStorage(UserDefaultsKeys.keyName) private var property: Type = defaultValue`
- **UserDefaults usage**: `UserDefaults.standard.string(forKey: UserDefaultsKeys.keyName)`
- **NEVER use string literals**: String literals like `"myKey"` are prohibited - always use the constant
- **Adding new keys**:
  1. Add constant to appropriate section in `UserDefaultsKeys.swift`
  2. Add to `allKeys` array
  3. Add to `defaultValues` dictionary if it should have a default value
  4. Add to `keysToRemove` set if it should be removed (not reset) during app reset
  5. Add to `keysToSkip` set if it requires special handling during reset

**Example:**
```swift
// ✅ CORRECT
@AppStorage(UserDefaultsKeys.hapticsEnabled) var hapticsEnabled: Bool = true
UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenWelcome)

// ❌ WRONG
@AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
UserDefaults.standard.bool(forKey: "hasSeenWelcome")
```

**Benefits**: Single source of truth, prevents typos, enables refactoring, supports testing and reset functionality.

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

## HealthKit Integration

### Overview
AsNeeded integrates with Apple HealthKit to provide medication data synchronization across devices. This feature is critical for v1.1 and enables cloud sync without backend infrastructure.

### Architecture

**Three Sync Modes:**
1. **Bidirectional Sync**: Keep data in sync between AsNeeded and Apple Health
   - Local storage: ✅ Yes (Boutique)
   - Export capability: ✅ Yes
   - Use case: Full feature set with cloud backup

2. **HealthKit as Source of Truth**: Manage medications in Apple Health, view in AsNeeded
   - Local storage: ❌ No (data lives in HealthKit only)
   - Export capability: ❌ No (data not stored locally)
   - Use case: Users who prefer Apple's native medication tracking

3. **AsNeeded as Source of Truth**: Manage in AsNeeded, backup to Apple Health
   - Local storage: ✅ Yes (Boutique)
   - Export capability: ✅ Yes
   - Use case: Full AsNeeded features with HealthKit backup

### Service Usage

**HealthKitSyncManager** (`Services/HealthKit/HealthKitSyncManager.swift`):
```swift
let syncManager = HealthKitSyncManager.shared

// Check availability
if syncManager.isHealthKitAvailable {
    // Request authorization
    try await syncManager.requestAuthorization()

    // Perform sync
    try await syncManager.performSync()
}
```

**HealthKitMigrationManager** (`Services/HealthKit/HealthKitMigrationManager.swift`):
```swift
let migrationManager = HealthKitMigrationManager.shared

// Get migration suggestion
let direction = await migrationManager.getMigrationSuggestion()

// Perform migration with progress tracking
try await migrationManager.performMigration(direction: .toHealthKit) { progress, message in
    print("Migration: \(progress * 100)% - \(message)")
}
```

### Conditional Write Logic

**DataStore respects HealthKit sync mode:**
```swift
// In DataStore
private func shouldWriteToLocalStorage() -> Bool {
    guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitSyncEnabled) else {
        return true // HealthKit disabled, always write locally
    }

    let mode = HealthKitSyncManager.shared.currentSyncMode
    return mode?.writesToLocalStorage ?? true
}
```

**All write operations check sync mode:**
- `addMedication()`: Writes locally only if `shouldWriteToLocalStorage()` returns true
- `updateMedication()`: Skips Boutique writes in HealthKit SOT mode
- `deleteMedication()`: Skips Boutique deletes in HealthKit SOT mode
- `addEvent()`: Respects sync mode for event storage

**Export restrictions:**
```swift
// DataStore checks export availability
var canExportData: Bool {
    guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitSyncEnabled) else {
        return true // HealthKit disabled, export available
    }

    let mode = HealthKitSyncManager.shared.currentSyncMode
    return mode?.allowsDataExport ?? true
}
```

### UI Integration

**Onboarding Card** (`Views/Components/HealthKitOnboardingCard.swift`):
- Show when medication list is empty OR in settings
- Check `healthKitShowOnboarding` preference
- Present authorization flow on connect

**Settings Section** (`Views/Screens/Settings/Sections/SettingsHealthKitSectionView.swift`):
- Summary card in main Settings
- Navigate to full HealthKit settings
- Show connection status

**Full Settings** (`Views/Screens/Settings/HealthKit/HealthKitSettingsView.swift`):
- Authorization status
- Sync mode selection
- Manual sync button
- Background sync toggle
- Disconnect option

### User Flow

1. **First-time Setup:**
   - User sees HealthKitOnboardingCard (if no medications)
   - Taps "Connect" → HealthKitAuthorizationView
   - Grants permissions → HealthKitSyncModeView
   - Selects sync mode → HealthKitMigrationView (if data exists)
   - Optionally migrates data → Setup complete

2. **Ongoing Sync:**
   - Background sync runs every 5 minutes (configurable)
   - Manual sync available in settings
   - Conflict resolution based on sync mode

3. **Mode Changes:**
   - User can change sync mode in settings
   - Warning shown about consequences
   - Migration offered if switching between modes

### Archived Medications

**Support for Apple Health archived status:**
```swift
// Medication extension
extension ANMedicationConcept {
    var isArchived: Bool { get set }
    mutating func archive()
    mutating func unarchive()
}

// Sequence extensions
extension Sequence where Element == ANMedicationConcept {
    var active: [ANMedicationConcept]
    var archived: [ANMedicationConcept]
}
```

**UI Integration:**
- MedicationEditView: Archive toggle
- MedicationListView: Archive filter button
- MedicationRowComponent: Archived badge
- Storage: UserDefaults array of archived medication IDs

### Testing

**Unit Tests:**
- `HealthKitSyncManagerTests.swift`: Sync modes, authorization, background sync
- `HealthKitMigrationManagerTests.swift`: Migration directions, progress tracking
- `HealthKitSyncModeTests.swift`: Mode properties, export availability
- `DataStoreTests.swift`: Conditional writes for each sync mode

**Testing Patterns:**
```swift
@Test("Medication skips local storage in HealthKit SOT mode")
func medicationSkipsLocalStorageInHealthKitSOT() async throws {
    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitSyncEnabled)
    UserDefaults.standard.set("healthKitSOT", forKey: UserDefaultsKeys.healthKitSyncMode)

    let medication = createTestMedication(name: "Test")
    try await dataStore.addMedication(medication)

    #expect(dataStore.medications.count == 0) // Not written locally
}
```

### Important Notes

- **Platform availability**: HealthKit requires iOS 26+, unavailable on iPad
- **Physical device testing**: HealthKit doesn't work fully in simulator
- **Per-object permissions**: Users can selectively share medications
- **Conflict resolution**: Newer data wins in bidirectional mode
- **Data privacy**: All HealthKit operations respect user permissions
- **ANModelKit integration**: Use `ANModelKitHealthKit` module for HealthKit operations
- **RxNorm codes**: Support for standardized medication codes from ANModelKit

### Common Patterns

**Check HealthKit availability before showing features:**
```swift
if HealthKitSyncManager.shared.isHealthKitAvailable {
    HealthKitOnboardingCard(context: .emptyState)
}
```

**Respect export restrictions:**
```swift
if DataStore.shared.canExportData {
    // Show export button
} else {
    // Show HealthKit warning, link to settings
}
```

**Handle authorization status:**
```swift
switch syncManager.authorizationStatus {
case .notDetermined:
    // Show connect button
case .authorized:
    // Show connected status
case .denied:
    // Show settings link
case .notAvailable:
    // Hide HealthKit features
}
```

## Package Boundaries
- No SwiftUI in packages: Do not add any SwiftUI code or imports to `AsNeeded/Packages/ANModelKit` or `AsNeeded/Packages/SwiftRxNorm`. These packages must remain UI‑free (domain models, use cases, networking only).
- UI lives in app targets: Place SwiftUI views and UI helpers under `AsNeeded/` (e.g., `Views/`, `Medication/`). Keep packages platform‑agnostic and testable.

## Package Dependencies Management
**CRITICAL**: The app dependencies displayed in the About screen are hardcoded in `AsNeeded/Services/PackageDependencyManager.swift`.

**When Package.resolved changes, you MUST manually update the hardcoded dependencies list:**
1. **Location**: `PackageDependencyManager.swift` lines 13-134 in the `getAllDependencies()` method
2. **What to update**:
   - Package version numbers (e.g., `versionInfo: .version("6.2.0")`)
   - Commit hashes (full hash, truncated to 7 chars automatically)
   - Branch names if using branch dependencies (e.g., `versionInfo: .branch("main")`)
   - Add new packages if dependencies are added
   - Remove packages if dependencies are removed
3. **How to update**:
   - Open `AsNeeded.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
   - Find the updated package in the `pins` array
   - Copy the new `revision` (commit hash) and `version`/`branch` to the hardcoded entry
   - Verify the package name, description, and license are still accurate
4. **Why hardcoded**: Package.resolved is a build-time file not bundled with the app, so runtime parsing isn't possible without bundling it as a resource.

**Example update process:**
```swift
// Before (outdated)
PackageDependency(
    id: "sfsafesymbols",
    name: "SFSafeSymbols",
    description: "Type-safe access to SF Symbols icons",
    repositoryURL: URL(string: "https://github.com/SFSafeSymbols/SFSafeSymbols")!,
    versionInfo: .version("6.2.0"),
    commitHash: "3dd282d3269b061853a3b3bcd23a509d2aa166ce",
    license: .mit,
    isDirect: true
)

// After (Package.resolved shows 6.3.0)
PackageDependency(
    id: "sfsafesymbols",
    name: "SFSafeSymbols",
    description: "Type-safe access to SF Symbols icons",
    repositoryURL: URL(string: "https://github.com/SFSafeSymbols/SFSafeSymbols")!,
    versionInfo: .version("6.3.0"),  // ← Updated version
    commitHash: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",  // ← Updated commit hash
    license: .mit,
    isDirect: true
)
```

**Testing after updates:**
- Navigate to Settings → About → App Dependencies
- Verify all packages display with correct versions and commit hashes
- Tap each package to ensure repository URLs still work

## Accessibility Guidelines
- **VoiceOver Support**: Add `.accessibilityLabel()` to all interactive elements and images. Use `.accessibilityHint()` for complex interactions. Hide decorative elements with `.accessibilityHidden(true)`.
- **Dynamic Type**: Always use semantic font styles (`.body`, `.headline`, `.caption`) instead of hardcoded sizes. Test with large accessibility font sizes.
- **Motion Sensitivity**: Import `@Environment(\.accessibilityReduceMotion)` and provide static alternatives when `reduceMotion` is true. Disable animations for users who prefer reduced motion.
- **Color and Contrast**: Use semantic colors (`.accent`, `.primary`, `.secondary`) that adapt to user preferences. Avoid relying solely on color to convey information.
- **Touch Targets**: Ensure interactive elements are at least 44x44 points for optimal usability.
- **Color Contrast**: ALWAYS use the `Color+Contrast` extension for custom colored backgrounds. Use `.contrastingForegroundColor()` for text on custom backgrounds, and `.contrastingSecondaryColor()` for secondary text. Never hardcode `.white` or `.black` text on colored backgrounds. The extension automatically meets WCAG AA standards (4.5:1 contrast ratio for normal text, 3:1 for large text).

## Component Reusability Guidelines
- **Check Before Creating**: Always search for existing components before creating new ones. Look in `AsNeeded/Views/Components/` and examine similar features for reusable patterns.
- **Documentation Requirements**: All reusable components MUST include comprehensive `///` documentation comments at the top, including:
  - Brief description of what the component looks like
  - Key features and capabilities
  - Visual appearance details
  - Multiple use cases where the component could be applied
  - Example: See `HeroSectionComponent`, `GlassCardModifier`, `DateCardComponent` for reference
- **Design Consistency**: Reusable components should follow the app's design system (glass cards, accent colors, semantic fonts, accessibility support).
- **Preview Support**: All components should include SwiftUI previews demonstrating different states and configurations.

### TestFlight Beta Access
- **Component**: Use `TestFlightAccessComponent` for linking users to the TestFlight beta program
- **Location**: `AsNeeded/Views/Components/TestFlightAccessComponent.swift`
- **URL Constant**: Use `AppURLs.testFlightBeta` from `AsNeeded/Constants/AppURLs.swift`
- **Usage**: Add to feedback, support, about, and thank-you views to invite users to test beta features
- **Localization**: Component is fully localized in 37 languages with proper translations
- **Styling**: Uses airplane icon (`.airplaneCircleFill`) with blue gradient background, follows app design system with custom font support
- **Example**:
  ```swift
  VStack(alignment: .leading, spacing: spacing16) {
      Text("Beta Testing")
          .font(.customFont(fontFamily, style: .title2, weight: .semibold))

      TestFlightAccessComponent()
  }
  ```

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

### Automated Code Review Requirement
**MANDATORY: Run automated code review after completing each user prompt.**

After completing any task (code changes, refactoring, bug fixes, new features), you MUST:
1. Run `coderabbit --plain` to perform automated code review
2. Review the feedback provided by CodeRabbit
3. Implement any critical issues or suggestions found
4. Only mark the task as complete after addressing CodeRabbit feedback

**When to run:**
- After making code changes (any `.swift` file modifications)
- After completing multi-step tasks
- Before marking tasks as "done" in the todo list
- Even for small changes (enforcement ensures consistency)

**How to run:**
```bash
coderabbit --plain
```

**Expected workflow:**
1. Complete the user's requested task
2. Run `coderabbit --plain`
3. If issues found: Fix them and verify build still passes
4. If no issues found: Task is complete
5. Report results to user with summary of any changes made

**Note:** CodeRabbit provides AI-powered code review checking for:
- Code quality and best practices
- Potential bugs and security issues
- Performance optimizations
- Style consistency with CLAUDE.md guidelines
- Architecture and design patterns

This ensures all code meets high quality standards before being committed.

### Performance Optimization for AI Agents
**CRITICAL: Always optimize for speed when working with this codebase:**

#### Search & File Operations
- **ALWAYS exclude build artifacts and localizations** when using Grep/Glob tools
- **Excluded paths**: `build/`, `*.lproj/`, `DerivedData/`, `.swiftpm/`, `*.xcuserstate`, `xcuserdata/`
- **Focus searches on**: `AsNeeded/`, `AsNeededTests/`, `scripts/`
- **Performance impact**: Excluding these paths reduces search time by 60-80%

**Examples:**
```bash
# ✅ CORRECT - Exclude build artifacts
grep "MedicationView" --exclude-dir=build --exclude-dir="*.lproj"

# ❌ WRONG - Searches ALL files including 76 localization directories
grep "MedicationView"
```

#### File Reading Strategy
- **Large files (500+ lines)**: Read specific sections using offset/limit when possible
- **Localization files**: NEVER read unless explicitly asked - they are auto-generated
- **Test files**: Read only when debugging specific test failures
- **Build artifacts**: NEVER read files in `build/` or `DerivedData/`

#### Build Verification Strategy
- **ALWAYS use optimized scripts** instead of raw xcodebuild commands:
  - `./scripts/dev-build.sh` instead of `xcodebuild build`
  - `./scripts/test-parallel.sh` instead of `xcodebuild test`
- **Expected performance**: Scripts are 50-70% faster than manual commands
- **Why**: Scripts use incremental compilation, max parallelization, and xcsift output

#### Memory & Context Management
- **Avoid reading multiple large files** in a single response (>3 files over 500 lines)
- **Use Task tool** for complex multi-file searches instead of reading files directly
- **Cache awareness**: Prefer targeted searches over broad file reads

### Critical Build Verification Requirement
**ALWAYS verify the app builds successfully after making large changes.** This is mandatory and non-negotiable:

1. **After significant code changes**: Run `./scripts/dev-build.sh` to verify the build succeeds
2. **Before completing tasks**: Ensure the build is working and all new files are properly added to the Xcode project
3. **When adding new files**: Verify files are added to the Xcode project and included in the build phase - files on disk are not automatically included
4. **When modifying dependencies**: Test that imports resolve correctly and all required initializers/methods are public
5. **Build failure response**: If builds fail, immediately investigate and fix compilation errors before proceeding with other work
6. **After tests**: Run `./scripts/test-parallel.sh` to verify all tests pass with maximum parallelization

**Build testing commands (in order of preference):**
1. **Preferred - Optimized script**: `./scripts/dev-build.sh`
   - Uses incremental compilation for 50-70% faster builds
   - Leverages all 16 CPU cores with parallel target building
   - Returns clean xcsift JSON output
   - **Use this for ALL routine build verification**

2. **Alternative - Manual with xcsift**: `xcodebuild -scheme AsNeeded -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet 2>&1 | xcsift`
   - Returns clean JSON: `{"status": "success", "summary": {"errors": 0, "failed_tests": 0}}`
   - Use only if scripts are unavailable

3. **Syntax check only**: `swiftc -parse [file_path]` for individual files

4. **Clean build**: `./scripts/clean-deriveddata.sh --asneeded && ./scripts/dev-build.sh`
   - Use when build behavior is inconsistent
   - Cleans ~2.6GB of cached data

5. **Nuclear option**: `./scripts/clean-all.sh` then `./scripts/dev-build.sh`
   - Only use when build system is completely broken
   - Requires confirmation and takes longer

**Test verification commands:**
1. **Preferred**: `./scripts/test-parallel.sh` - Run all tests in parallel (12 workers)
2. **Specific test**: `./scripts/test-parallel.sh TestClassName` - Run single test class
3. **Manual**: `xcodebuild test -project AsNeeded.xcodeproj -scheme AsNeeded -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcsift`

**Performance expectations:**
- Incremental build: ~15 seconds (vs ~45s standard)
- Full test suite: ~35 seconds (vs ~120s standard)
- Clean build: ~120 seconds (vs ~180s standard)

**Troubleshooting:**
- **Build fails mysteriously**: Run `./scripts/clean-deriveddata.sh --asneeded`
- **Simulator not found**: Check available with `xcodebuild -showdestinations -scheme AsNeeded`
- **Tests timeout**: May be resource contention; scripts handle this automatically

**Never leave the project in a broken state.** A working build is the foundation for all development work.

## Performance Optimization & Maintenance

### System Capabilities
This project is optimized for high-performance development machines:
- **CPU**: 16 cores (all utilized for parallel builds)
- **Memory**: High RAM usage enabled for faster compilation
- **Storage**: SSD required for optimal build performance
- **Parallelization**: Maximum concurrent jobs = CPU cores

### Build Performance Metrics

**Expected build times on 16-core system:**

| Build Type | Standard | Optimized | Improvement | Command |
|------------|----------|-----------|-------------|---------|
| Incremental (small changes) | ~45s | ~15s | 67% faster | `./scripts/dev-build.sh` |
| Clean build | ~180s | ~120s | 33% faster | `./scripts/prod-build.sh` |
| Full test suite | ~120s | ~35s | 71% faster | `./scripts/test-parallel.sh` |
| Single test class | ~25s | ~8s | 68% faster | `./scripts/test-parallel.sh TestClass` |

**Cache impact:**
- Fresh DerivedData: +20-30% build time
- After cleanup: -25% average build time
- Optimal cleanup schedule: Weekly

### Optimization Techniques

#### 1. Parallel Compilation (Active)
- **Dev builds**: Incremental mode + all 16 cores = ~70% faster
- **Prod builds**: Whole-module optimization + 16 cores = ~33% faster
- **Test runs**: 12 parallel workers = ~71% faster

#### 2. Smart Caching
- **DerivedData**: 2.6GB cached for AsNeeded (clean weekly)
- **SPM packages**: Cached in `~/Library/Caches/org.swift.swiftpm`
- **Index store**: Disabled for dev builds, enabled for production

#### 3. Compilation Modes
- **Development**: `SWIFT_COMPILATION_MODE=incremental` (fast rebuilds)
- **Production**: `SWIFT_COMPILATION_MODE=wholemodule` (optimized runtime)
- **Impact**: Incremental mode is 2-3x faster for small changes

#### 4. Excluded from Indexing
Build scripts automatically exclude:
- `build/` directory (local artifacts)
- 76 localization directories (`*.lproj`)
- DerivedData (system managed)
- SPM caches (`.swiftpm/`)

### Maintenance Schedule

#### Daily (During Active Development)
```bash
# Morning - fast build
./scripts/dev-build.sh

# After changes - verify tests
./scripts/test-parallel.sh

# Before commits - full verification
./scripts/test-parallel.sh
```

#### Weekly (Recommended: Monday Morning)
```bash
# Clean AsNeeded DerivedData (~2.6GB freed)
./scripts/clean-deriveddata.sh --asneeded

# Fresh build to verify
./scripts/dev-build.sh

# Full test suite
./scripts/test-parallel.sh
```

**Benefits:**
- 20-30% faster builds for the week
- Fixes accumulated build cache corruption
- Recovers disk space
- Total time: ~3 minutes

#### Monthly
```bash
# Clean all old DerivedData (all projects)
./scripts/clean-deriveddata.sh --old 30

# Deep clean (if needed)
./scripts/clean-all.sh  # Requires confirmation
```

#### Before Major Changes
```bash
# Nuclear cleanup for major version updates
./scripts/clean-all.sh

# Then rebuild
./scripts/dev-build.sh
```

### Troubleshooting Performance Issues

#### Builds Suddenly Slow
**Symptom**: Builds taking 2-3x longer than normal

**Solution:**
```bash
./scripts/clean-deriveddata.sh --asneeded
./scripts/dev-build.sh
```

**If still slow:**
```bash
./scripts/clean-all.sh
./scripts/dev-build.sh
```

#### Tests Timing Out
**Symptom**: Tests randomly failing or timing out

**Possible causes:**
1. Resource contention (too many parallel workers)
2. Simulator issues
3. Memory pressure

**Solution:**
```bash
# Kill simulators
killall Simulator

# Run tests with reduced parallelism
# Edit scripts/test-parallel.sh:
# TEST_WORKERS=$((CPU_CORES / 2))  # Use 50% instead of 75%

./scripts/test-parallel.sh
```

#### Xcode Indexing Forever
**Symptom**: Xcode stuck on "Indexing..." for minutes

**Solution:**
```bash
# Close Xcode first
killall Xcode

# Clean DerivedData
./scripts/clean-deriveddata.sh --asneeded

# Reopen Xcode
# Wait ~2-3 minutes for re-indexing
```

#### Disk Space Issues
**Symptom**: Low disk space warning

**Check sizes:**
```bash
du -sh ~/Library/Developer/Xcode/DerivedData
du -sh ~/Library/Caches/org.swift.swiftpm
```

**Solution:**
```bash
# Aggressive cleanup (frees 3-5GB typically)
./scripts/clean-all.sh
```

### Automated Optimization Scripts

All scripts located in `scripts/` directory:

| Script | Purpose | Frequency | Time |
|--------|---------|-----------|------|
| `dev-build.sh` | Fast incremental builds | Every dev session | ~15s |
| `test-parallel.sh` | Parallel test execution | Before commits | ~35s |
| `prod-build.sh` | Release builds | Before archiving | ~120s |
| `clean-deriveddata.sh --asneeded` | Weekly cleanup | Weekly | ~30s |
| `clean-all.sh` | Nuclear cleanup | As needed | ~5min |

See `scripts/README.md` for complete documentation.

### Advanced Optimizations

#### Git Hooks (Optional)
Add to `.git/hooks/pre-push`:
```bash
#!/bin/bash
cd /Users/danhart/Developer/AsNeeded
./scripts/test-parallel.sh || exit 1
```

Makes executable:
```bash
chmod +x .git/hooks/pre-push
```

#### Xcode Settings (Optional)
Add to Xcode build settings for even faster builds:
```
COMPILER_INDEX_STORE_ENABLE = NO  # Dev builds only
ENABLE_PREVIEWS = NO              # If not using SwiftUI previews
```

#### Shell Aliases (Optional)
Add to `~/.zshrc` or `~/.bashrc`:
```bash
alias asneeded-build='cd /Users/danhart/Developer/AsNeeded && ./scripts/dev-build.sh'
alias asneeded-test='cd /Users/danhart/Developer/AsNeeded && ./scripts/test-parallel.sh'
alias asneeded-clean='cd /Users/danhart/Developer/AsNeeded && ./scripts/clean-deriveddata.sh --asneeded'
```

### Performance Monitoring

**Track build times:**
```bash
# Add to dev-build.sh or run manually
time ./scripts/dev-build.sh
```

**Expected output:**
```
real    0m15.234s  # Total time (target: <20s for incremental)
user    2m30.456s  # CPU time (higher = more parallelization)
sys     0m5.678s   # System time
```

**Interpretation:**
- `real` time: Actual wall-clock time
- `user` time > `real` time: Good parallelization (using multiple cores)
- If `real` time exceeds expectations: Run cleanup

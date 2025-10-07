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
- Check `healthKitDontShowOnboarding` preference
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

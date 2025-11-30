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
- **xcsift installation** (required): `brew tap ldomaradzki/xcsift && brew install xcsift`
- Build (CLI): `xcodebuild -project AsNeeded.xcodeproj -scheme AsNeeded -configuration Debug build -quiet 2>&1 | xcsift`
- Tests (CLI): `xcodebuild test -project AsNeeded.xcodeproj -scheme AsNeeded -testPlan AsNeededTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcsift`

## Coding Style & Naming
- **Indentation**: Use tabs (not spaces); wrap at ~120 cols.
- **Code Organization**: Use MARK comments (e.g., `// MARK: - Properties`). No blank lines after MARK comments.
- **Semantic Naming**: Name variables by purpose, not value.
  - ✅ CORRECT: `private var cardSpacing: CGFloat = 24`
  - ❌ WRONG: `private var spacing24: CGFloat = 24`
- **Inclusive Terminology**: Use modern, inclusive terminology in all code, comments, and documentation.
  - ✅ CORRECT: `allowlist`, `blocklist`, `primary/replica`, `main branch`
  - ❌ WRONG: `whitelist`, `blacklist`, `master/slave`, `master branch`
- **SF Symbols**: ALWAYS use SFSafeSymbols: `Image(systemSymbol: .pills)` not `Image(systemName: "pills")`. Exception: WatchOS targets.
- **Colors**:
  - ALWAYS use `.accent` instead of `.blue` or `Color.accentColor` for interactive elements.
  - ✅ CORRECT: `.foregroundStyle(.accent)`, `.tint(.accent)`
  - ❌ WRONG: `.foregroundStyle(Color.accentColor)`
- **Typography & Custom Fonts**:
  - **CRITICAL**: ALWAYS use `.customFont()` for all text to support user-selected accessibility fonts.
  - ✅ CORRECT: `.font(.customFont(fontFamily, style: .body))`
  - ❌ WRONG: `.font(.body)`
  - Add `@Environment(\.fontFamily) private var fontFamily` to ALL views displaying text.
  - Navigation titles: Use `.customNavigationTitle("Title")` for inline titles.
  - **Text Truncation**: Use `.noTruncate()` for critical text (medication names). Use `.lineLimit(n)` for preview text only.
- **Component Reusability**: ALWAYS search `AsNeeded/Views/Components/` before creating new UI. Create components for any pattern used 2+ times.

## UI Patterns

### Sticky Bottom Buttons
For important actions, use sticky button at bottom:
- Structure: `VStack(spacing: 0)` with scrollable content + sticky button container
- Background: `.regularMaterial` with `Divider()` separator
- Examples: LogDoseView, ColorPickerComponent

### Sheet Toolbar Patterns
- **Cancel** (leading): `Image(systemSymbol: .xmark)` with `.font(.customFont(fontFamily, style: .body, weight: .medium))`
- **Confirmation** (trailing): `Image(systemSymbol: .checkmark)` with `.font(.customFont(fontFamily, style: .title2, weight: .semibold))` and `.foregroundStyle(.accent)`
- **Exception**: Sheets with sticky bottom buttons have NO trailing toolbar button.

### Keyboard Focus in Sheets
- Use `@FocusState` with 0.3s delay via `.onChange()` and `.task` modifiers
- Prefer `TextField` with `.axis(.vertical)` over `TextEditor`

### Liquid Glass Design (iOS 26+)
See complete guide: **[docs/LIQUID_GLASS.md](docs/LIQUID_GLASS.md)**
- Primary: `.glassEffect(.regular)` replaces `.regularMaterial`
- Interactive: `.glassEffect(.regular.interactive(true))` for buttons
- Tinted: `.glassEffect(.regular.tint(.accent.opacity(0.3)))` for CTAs
- Shapes: `Capsule()` for controls, `RoundedRectangle(cornerRadius:, style: .continuous)` for cards

## Feature Toggle System
- Location: `AsNeeded/Services/FeatureToggleManager.swift`
- Debug-only, default OFF
- Adding toggles: Update `UserDefaultsKeys.swift`, `FeatureToggleManager`, and `SettingsDebugSectionView`

## Code Style
- Swift 6, SwiftUI first; prefer `struct` for models/views; mark `final` for classes.
- **No force unwraps**: Use `guard let`, `if let`, or optional chaining in app code AND tests.

## UserDefaults & AppStorage
**ALWAYS use strongly-typed keys from `UserDefaultsKeys.swift`:**
- ✅ CORRECT: `@AppStorage(UserDefaultsKeys.hapticsEnabled) var hapticsEnabled: Bool = true`
- ❌ WRONG: `@AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true`

## Architecture Overview
- Domain: Pure models, business rules, no UI/persistence
- Services: Protocol-backed adapters (persistence, notifications)
- Views: Small SwiftUI views, unidirectional data flow
- Concurrency: async/await for I/O; keep domain synchronous

## Data Store Usage
- Use `DataStore.shared` for Boutique access
- Inject DataStore in view models for testability
- Prefer DataStore helpers over raw insert/remove

## Data Storage & Migration

**CRITICAL**: Read `docs/DATA_STORAGE_GUIDELINES.md` before making ANY storage changes.

### Storage Location
- **Current**: App Group container `group.com.codedbydan.AsNeeded`
- **Databases**: `medications.sqlite`, `events.sqlite`
- **Engine**: Boutique + SQLiteStorageEngine
- **Location**: `AsNeeded/Services/Persistence/DataStore.swift`

### The October 2025 Data Loss Incident
In October 2025, a storage path change (commit `61e6ad5`) caused complete data loss for all users. The app was migrated from default app container to App Group container WITHOUT migration logic, leaving all existing data orphaned and inaccessible.

**Lesson**: NEVER change storage paths without implementing data migration.

### Mandatory Rules for Storage Changes

1. **NEVER change storage paths without migration**
   - ANY path/filename change REQUIRES `DataMigrationManager`
   - Migration MUST merge data (not replace)
   - Migration MUST be non-destructive
   - Migration MUST be idempotent

2. **Migration Implementation Checklist**
   - [ ] Create migration manager class
   - [ ] Add migration flag to `UserDefaultsKeys.swift`
   - [ ] Implement data loading from both old and new locations
   - [ ] Implement merge logic (deduplicate by ID)
   - [ ] Add comprehensive logging
   - [ ] Call migration from `DataStore.init()` with semaphore
   - [ ] Create unit tests
   - [ ] Test on simulator AND physical device
   - [ ] Test all scenarios: fresh install, old data only, new data only, both
   - [ ] Verify idempotency (run migration multiple times)
   - [ ] Update `docs/DATA_STORAGE_GUIDELINES.md`

3. **Testing Requirements**
   - Test with real user data in old location
   - Test migration idempotency (run twice, verify no duplicates)
   - Test on physical device (NOT just simulator)
   - Test with large databases (1000+ items)
   - Verify old data still exists after migration

4. **Documentation Requirements**
   - Document all storage paths in `DATA_STORAGE_GUIDELINES.md`
   - Document migration strategy and rationale
   - Update version history table
   - Add migration to troubleshooting guide

### Migration Code Template
See `docs/DATA_STORAGE_GUIDELINES.md` for complete template and examples.

### Current Migration Status
- **DataMigrationManager**: Handles legacy → App Group migration
- **Status**: Active, runs on every app launch (cached after first run)
- **Flag**: `UserDefaultsKeys.dataMigrationCompleted`

## HealthKit Integration

### Overview
Three sync modes: Bidirectional, HealthKit SOT, AsNeeded SOT. Enables cloud sync without backend.

### Services
- **HealthKitSyncManager**: `Services/HealthKit/HealthKitSyncManager.swift`
- **HealthKitMigrationManager**: `Services/HealthKit/HealthKitMigrationManager.swift`

### Key Logic
DataStore respects sync mode via `shouldWriteToLocalStorage()`:
- Bidirectional/AsNeeded SOT: Writes to local Boutique store
- HealthKit SOT: Writes only to HealthKit, NOT local storage

Export availability via `canExportData` property based on sync mode.

### UI Components
- **HealthKitOnboardingCard**: Empty state or settings
- **SettingsHealthKitSectionView**: Main settings summary
- **HealthKitSettingsView**: Full sync configuration

### User Flow
1. Connect → Authorize → Select mode → Migrate (optional)
2. Background sync every 5 minutes
3. Mode changes show warnings and offer migration

### Archived Medications
- Extension: `ANMedicationConcept.isArchived`
- UI: Archive toggle in edit view, filter in list view
- Storage: UserDefaults array of archived IDs

### Testing
- Unit tests: `HealthKitSyncManagerTests`, `HealthKitMigrationManagerTests`, `DataStoreTests`
- Pattern: Set sync mode in UserDefaults, verify conditional writes

### Important Notes
- iOS 26+ only, unavailable on iPad
- Physical device testing required
- Per-object permissions supported
- Uses `ANModelKitHealthKit` module

## Package Boundaries
- No SwiftUI in `AsNeeded/Packages/ANModelKit` or `AsNeeded/Packages/SwiftRxNorm`
- Keep packages platform-agnostic

## Package Dependencies Management
**CRITICAL**: Hardcoded in `AsNeeded/Services/PackageDependencyManager.swift` (lines 13-134).

When `Package.resolved` changes:
1. Open `AsNeeded.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
2. Copy new `revision` (commit hash) and `version`/`branch` to hardcoded entry
3. Test in Settings → About → App Dependencies

## Accessibility Guidelines
- **VoiceOver**: Add `.accessibilityLabel()` to interactive elements
- **Dynamic Type**: Use semantic font styles via `.customFont()`
- **Motion**: Check `@Environment(\.accessibilityReduceMotion)`
- **Color Contrast**: Use `Color+Contrast` extension (`.contrastingForegroundColor()`) for custom backgrounds
- **Touch Targets**: Minimum 44x44 points

## Component Reusability
- Check `AsNeeded/Views/Components/` before creating
- Document with `///` comments: description, features, use cases
- Include SwiftUI previews

### TestFlight Beta Access
- Component: `TestFlightAccessComponent`
- URL: `AppURLs.testFlightBeta`
- Usage: Feedback, support, about views

## Testing Guidelines
- Framework: Swift Testing (`import Testing`, `@Test`, `#expect`)
- Scope: Unit tests for domain/services ONLY
- **NO UI/Snapshot Testing**: Test view models and business logic only

## Commits & Pull Requests
- Commits: Imperative subjects (e.g., "Add ANModelKit")
- PRs: Clear description, screenshots for UI, link issues
- Requirements: All tests pass, no formatting churn
- **NEVER add Claude as co-author** - omit the "Co-Authored-By: Claude" line from commits

## Security & Configuration
- No secrets in commits
- Verify `Info.plist` changes are intentional
- Use personal team for signing

## .gitignore Requirements
Ensure ignored: build artifacts (`build/`, `DerivedData/`), user data (`*.xcuserstate`, `xcuserdata/`), `.DS_Store`, SPM caches

## Agent-Specific Instructions

### Automated Code Review
**MANDATORY: Run `coderabbit --plain` after completing tasks.**
1. Complete task
2. Run code review
3. Fix issues found
4. Mark complete

### Performance Optimization for AI Agents
**CRITICAL optimizations:**
- **Exclude**: `build/`, `*.lproj/`, `DerivedData/`, `.swiftpm/` from searches (60-80% faster)
- **Focus**: `AsNeeded/`, `AsNeededTests/`, `scripts/`
- **Never read**: Localization files unless explicitly asked
- **Use Task tool**: For complex multi-file searches

### Build Verification
**ALWAYS verify builds after changes:**

**Commands (in order):**
1. **Preferred**: `./scripts/dev-build.sh` (incremental, 16 cores, ~15s)
2. **Alternative**: `xcodebuild -scheme AsNeeded -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet 2>&1 | xcsift`
3. **Tests**: `./scripts/test-parallel.sh` (12 workers, ~35s)
4. **Clean build**: `./scripts/clean-deriveddata.sh --asneeded && ./scripts/dev-build.sh`
5. **Nuclear**: `./scripts/clean-all.sh` then rebuild

**Performance expectations:**
- Incremental: ~15s (vs ~45s standard) = 67% faster
- Full tests: ~35s (vs ~120s) = 71% faster
- Clean build: ~120s (vs ~180s) = 33% faster

**Troubleshooting:**
- Slow builds: Run `./scripts/clean-deriveddata.sh --asneeded`
- Test timeouts: `killall Simulator` then retry
- Xcode indexing: Close Xcode, clean DerivedData, reopen

## Performance Optimization & Maintenance

### System Capabilities
16-core CPU, high RAM, SSD required, maximum parallelization enabled.

### Build Performance Metrics
| Build Type | Standard | Optimized | Improvement |
|------------|----------|-----------|-------------|
| Incremental | ~45s | ~15s | 67% faster |
| Clean build | ~180s | ~120s | 33% faster |
| Full tests | ~120s | ~35s | 71% faster |

### Optimization Techniques
1. **Parallel Compilation**: 16 cores for builds, 12 workers for tests
2. **Smart Caching**: 2.6GB DerivedData (clean weekly)
3. **Compilation Modes**: Incremental for dev, whole-module for prod
4. **Excluded Indexing**: build/, *.lproj/, DerivedData/, .swiftpm/

### Maintenance Schedule
**Daily**: `./scripts/dev-build.sh`, `./scripts/test-parallel.sh`

**Weekly** (Monday morning):
```bash
./scripts/clean-deriveddata.sh --asneeded  # Frees ~2.6GB
./scripts/dev-build.sh
./scripts/test-parallel.sh
```
Benefits: 20-30% faster builds, fixes cache corruption, ~3min total

**Monthly**: `./scripts/clean-deriveddata.sh --old 30`

**Before major changes**: `./scripts/clean-all.sh`

### Scripts Reference
| Script | Purpose | Time |
|--------|---------|------|
| `dev-build.sh` | Fast incremental builds | ~15s |
| `test-parallel.sh` | Parallel test execution | ~35s |
| `prod-build.sh` | Release builds | ~120s |
| `clean-deriveddata.sh --asneeded` | Weekly cleanup | ~30s |
| `clean-all.sh` | Nuclear cleanup | ~5min |

### Advanced Optimizations (Optional)
- Git hooks: Add `./scripts/test-parallel.sh` to `.git/hooks/pre-push`
- Xcode settings: `COMPILER_INDEX_STORE_ENABLE = NO` for dev
- Shell aliases: `alias asneeded-build='cd /Users/danhart/Developer/AsNeeded && ./scripts/dev-build.sh'`

**Never leave project in broken state.** Working builds are mandatory.

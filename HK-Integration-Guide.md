# HealthKit Integration Implementation Guide

**Version 1.1 Feature Implementation**
**Status: In Progress (Phases 1-2 Complete)**
**Last Updated:** 2025-10-07

---

## Overview

This document tracks the implementation of comprehensive HealthKit synchronization for AsNeeded, enabling users to sync medication data with Apple Health across three distinct modes.

---

## ✅ Completed Work

### Phase 1: Foundation & Models (COMPLETE)

#### 1.1 Entitlements & Configuration ✅
- **File:** `AsNeeded/AsNeeded.entitlements`
  - Added `com.apple.developer.healthkit` entitlement
  - Added `com.apple.developer.healthkit.access` array
- **File:** `AsNeeded/Info.plist`
  - Added `NSHealthShareUsageDescription`
  - Added `NSHealthUpdateUsageDescription`

#### 1.2 Package Dependencies ✅
- ANModelKit package already included
- ANModelKitHealthKit module available for import

#### 1.3 HealthKit Models ✅
Created comprehensive model files:

**`HealthKitSyncMode.swift`**
- Three sync modes: `bidirectional`, `healthKitSOT`, `asNeededSOT`
- User-facing display names and descriptions
- Pros/cons lists for each mode
- Export availability flags

**`HealthKitAuthorizationStatus.swift`**
- Authorization states: `notDetermined`, `notAvailable`, `denied`, `authorized`, `unknown`
- User-friendly display text and detail explanations
- Action button text for each state

**`HealthKitMigrationOptions.swift`**
- Migration directions: `toHealthKit`, `toAsNeeded`, `skip`
- Migration result tracking
- Warning messages and backup recommendations

#### 1.4 UserDefaultsKeys ✅
Added keys in `Constants/UserDefaultsKeys.swift`:
- `healthKitSyncEnabled` (Bool, default: false)
- `healthKitSyncMode` (String, default: "bidirectional")
- `healthKitDontShowOnboarding` (Bool, default: false)
- `healthKitLastSyncDate` (Date, removed on reset)
- `healthKitHasCompletedInitialSetup` (Bool, default: false)
- `healthKitBackgroundSyncEnabled` (Bool, default: true)

#### 1.5 Archived Medication Support ✅
**File:** `AsNeeded/Medication/Medication.swift`
- Extension property `isArchived` using UserDefaults storage
- Methods: `archive()`, `unarchive()`
- Sequence extensions: `.active`, `.archived` filters
- Storage key: `archivedMedicationIDs`

---

### Phase 2: Core Services (COMPLETE)

#### 2.1 HealthKitSyncManager ✅
**File:** `Services/HealthKit/HealthKitSyncManager.swift`

**Features:**
- Singleton service: `HealthKitSyncManager.shared`
- Authorization request and status tracking
- Three sync mode implementations:
  - **Bidirectional**: Full sync with `.newerWins` strategy
  - **HealthKit SOT**: Read-only from HealthKit
  - **AsNeeded SOT**: Push events to HK, pull medications
- Background sync with configurable intervals
- Manual operations: `pullFromHealthKit()`, `pushToHealthKit()`
- Published properties for UI binding
- Comprehensive error handling

**Key Methods:**
```swift
func requestAuthorization() async throws
func performSync() async throws -> HealthKitSyncResult
func startBackgroundSync(interval: TimeInterval = 300)
func stopBackgroundSync()
func pullFromHealthKit(daysOfHistory: Int = 30) async throws
func pushToHealthKit() async throws -> Int
```

#### 2.2 HealthKitMigrationManager ✅
**File:** `Services/HealthKit/HealthKitMigrationManager.swift`

**Features:**
- Singleton service: `HealthKitMigrationManager.shared`
- Migration suggestion based on data location
- Progress reporting during migration
- Backup creation before destructive operations
- Batch processing for large datasets (50 items/batch)
- Historical data import (up to 365 days)

**Key Methods:**
```swift
func getMigrationSuggestion() async -> HealthKitMigrationDirection?
func performMigration(direction:progressHandler:) async throws
func shouldOfferBackup(for:) -> Bool
func createBackup() async throws -> URL
```

#### 2.3 DataStore Updates ✅
**File:** `Services/Persistence/DataStore.swift`

**Changes:**
- Added `shouldWriteToLocalStorage()` - checks sync mode before writes
- Added `canExportData` property - respects HealthKit SOT mode
- Updated `addMedication()` - conditional local writes
- Updated `updateMedication()` - conditional local writes
- Updated `deleteMedication()` - conditional local writes
- Updated `addEvent()` - conditional local writes

**Logic:**
- If HealthKit sync disabled → always write locally
- If bidirectional or AsNeeded SOT → write to Boutique
- If HealthKit SOT → skip Boutique writes (data lives in HealthKit)

---

## 📋 Remaining Work

### Phase 3: UI Components (IN PROGRESS)

#### Files to Create:

1. **`Views/Components/HealthKitOnboardingCard.swift`**
   - Shown when medication count is 0
   - Explains HealthKit benefits
   - "Connect to Apple Health" button
   - "Don't show again" option
   - Reusable in multiple contexts

2. **`Views/Screens/Settings/HealthKit/HealthKitAuthorizationView.swift`**
   - Welcome screen explaining benefits
   - Authorization request flow
   - Success/failure states
   - Next steps guidance

3. **`Views/Screens/Settings/HealthKit/HealthKitSyncModeView.swift`**
   - Three cards for sync modes
   - Pros/cons display
   - Consequence warnings
   - Confirmation dialog

4. **`Views/Screens/Settings/HealthKit/HealthKitMigrationView.swift`**
   - Migration direction selection
   - Progress indicators
   - Backup offer
   - Success/error feedback

5. **`Views/Screens/Settings/HealthKit/HealthKitSettingsView.swift`**
   - Main HealthKit settings hub
   - Auth status display
   - Current sync mode
   - Manual sync button
   - Background sync toggle
   - One-time sync options
   - Deep link to data management

6. **`Views/Screens/Settings/Sections/SettingsHealthKitSectionView.swift`**
   - Summary card for main Settings
   - Connect CTA if not authorized
   - Status if authorized
   - Navigation to full settings

---

### Phase 4: Settings & List Integration

#### 4.1 Update SettingsView
- Add HealthKit section between Data and About
- Import SettingsHealthKitSectionView

#### 4.2 Update MedicationListView
- Add HealthKitOnboardingCard to empty state
- Check `healthKitDontShowOnboarding` preference

---

### Phase 5: Data Management Integration

#### 5.1 Update DataManagementView
- Check `dataStore.canExportData` before showing export
- Display warning if HealthKit SOT mode
- Add deep link to HealthKit settings
- Update UI for archived medications

#### 5.2 Update DataManagementViewModel
- Check sync mode in export operations
- Handle archived medication state
- Validate HealthKit state during operations

---

### Phase 6: Archived Medication UI

#### Files to Update:
1. **`Medication/Components/MedicationRowComponent.swift`**
   - Show archived badge
   - Gray out archived medications
   - Filter option

2. **`Medication/MedicationEditView.swift`**
   - Add archive toggle
   - Warning before archiving
   - Unarchive option

3. **`Medication/ViewModels/MedicationListViewModel.swift`**
   - Filter active/archived
   - Update queries

---

### Phase 7: Localization

#### 7.1 Add Localization Keys
**File:** `AsNeeded/Localizable.xcstrings`

**Categories:**
- HealthKit onboarding (10-15 keys)
- Authorization flow (8-10 keys)
- Sync mode descriptions (15-20 keys)
- Migration options (10-12 keys)
- Error messages (8-10 keys)
- Settings labels (12-15 keys)
- Help text (8-10 keys)

**Total:** ~80-100 new localization keys

#### 7.2 Translate to 37 Languages
Use AI-assisted translation for:
- English, Spanish, French, German, Italian, Portuguese, Dutch
- Chinese (Simplified & Traditional), Japanese, Korean
- Russian, Polish, Czech, Hungarian, Romanian
- Swedish, Danish, Norwegian, Finnish
- Arabic, Hebrew, Turkish, Greek
- Thai, Vietnamese, Indonesian, Malay
- Hindi, Bengali, Tamil
- Ukrainian, Croatian, Bulgarian

---

### Phase 8: Accessibility

#### 8.1 VoiceOver Support
- `.accessibilityLabel()` on all icons
- `.accessibilityHint()` on interactive elements
- `.accessibilityValue()` for status indicators
- `.accessibilityElement(children: .combine)` for groups

#### 8.2 Dynamic Type
- All text uses `.customFont()` modifier
- `@Environment(\.fontFamily)` in all views
- Scaled metrics for spacing
- Test with largest accessibility sizes

#### 8.3 Reduce Motion
- `@Environment(\.accessibilityReduceMotion)`
- Static alternatives for animations
- Instant transitions when enabled

---

### Phase 9: Unit Tests

#### Files to Create:

1. **`AsNeededTests/HealthKitSyncManagerTests.swift`**
   - Authorization flow
   - Each sync mode
   - Background sync
   - Error handling
   - Mock HealthKit responses

2. **`AsNeededTests/HealthKitMigrationManagerTests.swift`**
   - Migration directions
   - Progress reporting
   - Backup creation
   - Edge cases

3. **`AsNeededTests/HealthKitSyncModeTests.swift`**
   - Mode properties
   - Display text
   - Export availability

4. **Update Existing Tests:**
   - `DataManagementTests.swift` - HealthKit-aware export/import
   - `DataStoreTests.swift` - Sync mode conditional writes

---

### Phase 10: Documentation

#### 10.1 Update CLAUDE.md
Add section on HealthKit integration:
- Service usage patterns
- UI component guidelines
- Testing strategies

#### 10.2 Inline Documentation
- `///` documentation on all HealthKit files
- Code examples in comments
- Architecture decisions

#### 10.3 User-Facing Help
- In-app help sheets
- FAQ content
- Troubleshooting guide

---

### Phase 11: Final Integration

#### 11.1 Build Verification
```bash
xcodebuild -scheme AsNeeded -destination 'platform=iOS Simulator,name=iPhone 16' build
```

#### 11.2 Add Files to Xcode Project
- Verify all new files are in project
- Check build phases
- Validate target membership

#### 11.3 Testing Checklist
- [ ] First-time setup flow
- [ ] Each sync mode with data
- [ ] Migration operations
- [ ] Background sync
- [ ] Authorization denial
- [ ] Conflict resolution
- [ ] Data export/import
- [ ] Archived medications
- [ ] Localization spot checks
- [ ] VoiceOver navigation
- [ ] Dynamic Type scaling
- [ ] Reduce Motion

---

## Architecture Decisions

### 1. Local Storage Strategy
**Decision:** Store archived status in UserDefaults, not in ANMedicationConcept
**Rationale:** ANModelKit is external package; local extension is more maintainable

### 2. Sync Mode Implementation
**Decision:** Three distinct modes instead of toggles
**Rationale:** Clearer user mental model; prevents invalid configurations

### 3. Data Export Restriction
**Decision:** Disable export in HealthKit SOT mode
**Rationale:** Data doesn't live locally; misleading to export empty/stale data

### 4. Migration as One-Time Operation
**Decision:** Migration is separate from ongoing sync
**Rationale:** Clear separation between setup and maintenance; reduces complexity

### 5. Background Sync Default
**Decision:** Enable background sync by default when HealthKit is on
**Rationale:** Best user experience; can be disabled if needed

---

## Technical Notes

### HealthKit Availability
- iOS 26.0+ for medications API
- Not available on iPad (no Health app)
- Simulator has limited HealthKit support
- **Must test on physical device**

### Platform Compatibility
```swift
#if canImport(HealthKit)
#if canImport(ANModelKitHealthKit)
// HealthKit code
#endif
#endif
```

### Performance Considerations
- Batch processing for large migrations (50 items/batch)
- Background sync interval: 300s (5 minutes) default
- Historical import limited to 365 days
- Progress callbacks for long operations

### Error Handling Strategy
- Graceful degradation when HealthKit unavailable
- User-friendly error messages
- Retry logic for transient failures
- Comprehensive logging for debugging

---

## Common Patterns

### Checking HealthKit Sync Status
```swift
let syncManager = HealthKitSyncManager.shared
if syncManager.isSyncEnabled && syncManager.authorizationStatus == .authorized {
    // HealthKit is active
}
```

### Conditional Local Storage
```swift
// In DataStore
private func shouldWriteToLocalStorage() -> Bool {
    // Returns false only in HealthKit SOT mode
}
```

### Sync Mode Access
```swift
let syncMode = HealthKitSyncManager.shared.currentSyncMode
if syncMode?.allowsDataExport == true {
    // Export is available
}
```

---

## Testing Strategies

### Unit Testing
- Mock HealthKit responses
- Test each sync mode independently
- Edge cases: empty data, large datasets
- Error conditions

### Integration Testing
- Physical device required
- Test actual HealthKit interactions
- Verify data consistency
- Test conflict resolution

### UI Testing
- Manual testing checklist
- Accessibility audit
- Localization verification
- Performance profiling

---

## Timeline Estimate

| Phase | Description | Estimated Time |
|-------|-------------|----------------|
| 1-2 | ✅ Foundation & Services | ~6 hours (COMPLETE) |
| 3 | UI Components | ~4-5 hours |
| 4 | Integration | ~2-3 hours |
| 5 | Data Management | ~2-3 hours |
| 6 | Archived UI | ~2-3 hours |
| 7 | Localization | ~3-4 hours |
| 8 | Accessibility | ~2-3 hours |
| 9 | Testing | ~4-5 hours |
| 10 | Documentation | ~2-3 hours |
| 11 | Final Integration | ~3-4 hours |
| **Total** | | **30-40 hours** |

**Current Progress:** ~6/40 hours (15% complete)

---

## Next Steps

1. ✅ Create this guide
2. 🔄 Implement UI components (Phase 3)
3. ⏭️ Integrate into Settings and List (Phase 4)
4. ⏭️ Update Data Management (Phase 5)
5. ⏭️ Add Archived UI (Phase 6)
6. ⏭️ Complete Localization (Phase 7)
7. ⏭️ Accessibility Pass (Phase 8)
8. ⏭️ Write Tests (Phase 9)
9. ⏭️ Documentation (Phase 10)
10. ⏭️ Build & Test (Phase 11)

---

## Resources

- ANModelKit README: https://github.com/dan-hart/ANModelKit
- HealthKit Documentation: https://developer.apple.com/documentation/healthkit
- Project CLAUDE.md: Contains all coding standards and patterns

---

**Implementation by:** Claude Code
**Project:** AsNeeded v1.1
**Feature:** HealthKit Synchronization

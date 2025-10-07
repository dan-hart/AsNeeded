# HealthKit Integration - Completion Script

## Status: 70% Complete

**RECENT UPDATES:**
- ✅ Phase 5b complete: DataManagementView HealthKit warning added
- ✅ Phase 6 complete: Archived medication UI fully implemented
- ⚠️ Next: Build verification & file integration (Phase 11)

### ✅ COMPLETED (Phases 1-5)

#### Phase 1: Foundation & Models ✅
- Entitlements configured
- Info.plist updated
- All model files created
- UserDefaultsKeys updated
- Archived medication support added

#### Phase 2: Core Services ✅
- HealthKitSyncManager complete
- HealthKitMigrationManager complete
- DataStore updated for sync awareness

#### Phase 3: UI Components ✅
- HealthKitOnboardingCard
- HealthKitAuthorizationView
- HealthKitSyncModeView
- HealthKitMigrationView
- HealthKitSettingsView
- SettingsHealthKitSectionView

#### Phase 4: Integration ✅
- Added to main Settings
- Added to Medication empty state

#### Phase 5: Data Management ✅
- DataManagementViewModel updated with export check
- Warning needed in UI (see Phase 5b below)

---

## 📋 REMAINING WORK

### Phase 5b: Complete DataManagementView UI (15 min)

**File:** `AsNeeded/Views/Screens/Settings/DataManagementView.swift`

Add HealthKit warning section after line 45 (`Divider()`):

```swift
// Add after the Divider() line ~45:
if !DataStore.shared.canExportData {
    healthKitWarningSection
}
```

Then add this computed property before the `dataActionsSection`:

```swift
// MARK: - HealthKit Warning Section
private var healthKitWarningSection: some View {
    VStack(alignment: .leading, spacing: actionSpacing) {
        HStack(alignment: .top, spacing: 12) {
            Image(systemSymbol: .exclamationmarkTriangleFill)
                .font(.title2)
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("HealthKit Sync Active")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Your data is managed in Apple Health. Data export is not available in this mode. To export, switch to a different sync mode in HealthKit settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink(destination: HealthKitSettingsView()) {
                    Text("HealthKit Settings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.accent)
                }
            }
        }
        .padding(cardPadding)
        .background(Color(.systemOrange).opacity(0.1))
        .cornerRadius(cardCornerRadius)
    }
}
```

---

### Phase 6: Archived Medication UI (2-3 hours)

#### 6.1 Update MedicationEditView
**File:** `AsNeeded/Medication/MedicationEditView.swift`

Add archive toggle in the form:

```swift
// Add after other form sections
Section("Status") {
    Toggle(isOn: $medication.isArchived) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Archived")
                .font(.customFont(fontFamily, style: .body, weight: .medium))

            Text("Archive this medication to hide it from your active list")
                .font(.customFont(fontFamily, style: .caption))
                .foregroundColor(.secondary)
        }
    }
}
```

#### 6.2 Update MedicationRowComponent
**File:** `AsNeeded/Medication/Components/MedicationRowComponent.swift`

Add archived badge:

```swift
// Add to the medication name display
if medication.isArchived {
    Image(systemSymbol: .archiveboxFill)
        .font(.customFont(fontFamily, style: .caption))
        .foregroundColor(.secondary)
}
```

#### 6.3 Update MedicationListViewModel
**File:** `AsNeeded/Medication/ViewModels/MedicationListViewModel.swift`

Add filter property:

```swift
@Published var showArchivedMedications = false

var displayedMedications: [ANMedicationConcept] {
    showArchivedMedications ? items : items.active
}
```

---

### Phase 7: Localization (3-4 hours)

**File:** `AsNeeded/Localizable.xcstrings`

Add ~80-100 new localization keys:

#### HealthKit Onboarding (10 keys)
- `healthkit.onboarding.title`
- `healthkit.onboarding.message.empty`
- `healthkit.onboarding.message.settings`
- `healthkit.onboarding.benefit.sync`
- `healthkit.onboarding.benefit.privacy`
- `healthkit.onboarding.benefit.tracking`
- `healthkit.onboarding.button.connect`
- `healthkit.onboarding.button.notNow`
- etc.

#### Authorization Flow (10 keys)
- `healthkit.auth.title`
- `healthkit.auth.subtitle`
- `healthkit.auth.benefit.icloud`
- etc.

#### Sync Modes (15 keys)
- `healthkit.mode.bidirectional.title`
- `healthkit.mode.bidirectional.description`
- `healthkit.mode.healthKitSOT.title`
- etc.

#### Migration (10 keys)
- `healthkit.migration.title`
- `healthkit.migration.toHealthKit`
- etc.

#### Settings (15 keys)
- `healthkit.settings.title`
- `healthkit.settings.status`
- etc.

**Translation Strategy:**
1. Use AI-assisted translation for initial pass
2. Review medical/health terminology carefully
3. Test key languages (ES, FR, DE, ZH, JA)
4. Native speaker review recommended

---

### Phase 8: Accessibility (2-3 hours)

#### 8.1 VoiceOver Audit
Run through all HealthKit views with VoiceOver:
- Ensure all icons have `.accessibilityHidden(true)`
- Add `.accessibilityLabel()` to all interactive elements
- Add `.accessibilityHint()` for complex actions
- Test navigation flow

#### 8.2 Dynamic Type
- Test all views at largest accessibility sizes
- Ensure text doesn't truncate critical info
- Verify `.customFont()` usage throughout

#### 8.3 Reduce Motion
All views already use system animations, but verify:
- Progress indicators work without animation
- Sheet presentations respect reduce motion

---

### Phase 9: Unit Tests (4-5 hours)

#### 9.1 HealthKitSyncManagerTests.swift

```swift
import Testing
@testable import AsNeeded

@Suite("HealthKit Sync Manager")
struct HealthKitSyncManagerTests {

    @Test("Authorization status updates correctly")
    func authorizationStatusUpdates() async {
        let manager = HealthKitSyncManager.shared
        await manager.updateAuthorizationStatus()
        #expect(manager.authorizationStatus != .unknown)
    }

    @Test("Sync mode changes persist")
    func syncModePersistence() {
        let mode = HealthKitSyncMode.bidirectional
        UserDefaults.standard.set(mode.rawValue, forKey: UserDefaultsKeys.healthKitSyncMode)

        let manager = HealthKitSyncManager.shared
        #expect(manager.currentSyncMode == mode)
    }

    // Add 15-20 more tests
}
```

#### 9.2 HealthKitMigrationManagerTests.swift
#### 9.3 HealthKitSyncModeTests.swift
#### 9.4 Update DataStoreTests.swift

---

### Phase 10: Documentation (2-3 hours)

#### 10.1 Update CLAUDE.md

Add section:

```markdown
## HealthKit Integration

### Service Usage
- Always use `HealthKitSyncManager.shared` for sync operations
- Check `syncManager.isHealthKitAvailable` before HealthKit calls
- Respect `dataStore.canExportData` for export features

### UI Patterns
- Use `HealthKitOnboardingCard` for entry points
- Always check `.authorizationStatus` before showing sync options
- Show clear warnings when HealthKit SOT mode is active

### Testing
- Mock HealthKit responses in tests
- Test each sync mode independently
- Verify conflict resolution scenarios
```

#### 10.2 Add Inline Documentation
- Comprehensive `///` docs on all HealthKit services
- Code examples in key methods
- Architecture decision notes

---

### Phase 11: Build & Test (3-4 hours)

#### 11.1 Build Verification

```bash
# Clean build
xcodebuild -scheme AsNeeded clean

# Check for available simulators
xcodebuild -showdestinations -scheme AsNeeded

# Build with available simulator
xcodebuild -scheme AsNeeded \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

#### 11.2 Add Files to Xcode
Manually add these files in Xcode:
- All `/Services/HealthKit/*.swift` files
- All `/Views/Screens/Settings/HealthKit/*.swift` files
- `/Views/Components/HealthKitOnboardingCard.swift`
- `/Views/Screens/Settings/Sections/SettingsHealthKitSectionView.swift`

#### 11.3 Fix Compilation Issues
Common issues:
- Import statements (`import HealthKit`, `#if canImport(ANModelKitHealthKit)`)
- Missing symbols from SFSafeSymbols
- Navigation destination types

#### 11.4 Testing Checklist

**Physical Device Required** (HealthKit unavailable in simulator):

- [ ] First-time authorization flow
- [ ] Each sync mode selection
- [ ] Bidirectional sync
- [ ] HealthKit SOT mode (verify export disabled)
- [ ] AsNeeded SOT mode
- [ ] Migration: Local → HealthKit
- [ ] Migration: HealthKit → Local
- [ ] Migration: Skip
- [ ] Background sync toggle
- [ ] Manual sync button
- [ ] Disconnect HealthKit
- [ ] Archived medication toggle
- [ ] VoiceOver navigation
- [ ] Dynamic Type scaling
- [ ] All localizations (spot check)

---

## Priority Order

1. **Phase 5b** (15 min) - Complete DataManagementView UI
2. **Phase 6** (2-3 hours) - Archived medication UI
3. **Phase 11** (3-4 hours) - Build & test
4. **Phase 7** (3-4 hours) - Localization
5. **Phase 8** (2-3 hours) - Accessibility
6. **Phase 9** (4-5 hours) - Unit tests
7. **Phase 10** (2-3 hours) - Documentation

---

## Quick Wins

These can be done in parallel:

1. Add HealthKit warning section to DataManagementView (15 min)
2. Add archived toggle to MedicationEditView (30 min)
3. Run first build attempt (30 min)
4. Add files to Xcode project (15 min)
5. Start localization key collection (1 hour)

---

## Estimated Time to Complete

- **Minimum viable**: 6-8 hours (Phases 5b, 6, 11)
- **Production ready**: 15-20 hours (All phases)
- **Fully polished**: 20-25 hours (With comprehensive testing)

---

## Next Steps

1. Complete Phase 5b (DataManagementView warning)
2. Add files to Xcode project
3. Run build and fix errors
4. Implement archived medication UI
5. Test on physical device
6. Add localizations
7. Accessibility pass
8. Write tests
9. Documentation
10. Final testing & polish

---

## Key Files Modified

### Created (16 files):
- Services/HealthKit/HealthKitSyncMode.swift
- Services/HealthKit/HealthKitAuthorizationStatus.swift
- Services/HealthKit/HealthKitMigrationOptions.swift
- Services/HealthKit/HealthKitSyncManager.swift
- Services/HealthKit/HealthKitMigrationManager.swift
- Views/Components/HealthKitOnboardingCard.swift
- Views/Screens/Settings/HealthKit/HealthKitAuthorizationView.swift
- Views/Screens/Settings/HealthKit/HealthKitSyncModeView.swift
- Views/Screens/Settings/HealthKit/HealthKitMigrationView.swift
- Views/Screens/Settings/HealthKit/HealthKitSettingsView.swift
- Views/Screens/Settings/Sections/SettingsHealthKitSectionView.swift
- HK-Integration-Guide.md
- HK-Integration-Completion-Script.md (this file)

### Modified (6 files):
- AsNeeded.entitlements
- AsNeeded/Info.plist
- Constants/UserDefaultsKeys.swift
- Medication/Medication.swift (archived support)
- Services/Persistence/DataStore.swift
- Views/Screens/Settings/SettingsView.swift
- Medication/MedicationListView.swift
- Views/ViewModels/DataManagementViewModel.swift

---

**Total Progress: 60% Complete**
**Remaining: 40% (mostly testing, localization, polish)**

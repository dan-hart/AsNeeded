# Widgets & Quick Actions Integration Guide

This document explains how to integrate the AsNeeded widgets, app icon quick actions, and Apple Watch complications into the Xcode project.

## Overview

The following features have been implemented:
- **Home Screen Widgets**: Small, Medium, and Large widgets showing medication status
- **Lock Screen Widgets**: Circular, Rectangular, and Inline complications for iOS 16+
- **Live Activities**: Ongoing next-dose status on the Lock Screen and Dynamic Island
- **App Icon Quick Actions**: 3D Touch/Haptic Touch shortcuts
- **Interactive Quick Logging**: Direct logging from supported widgets and intents
- **Deep Linking**: URL scheme support for widget, Live Activity, and quick action navigation
- **Shared Data Container**: App Group for data sharing between main app and widgets

## Architecture

### File Structure

```
AsNeeded/
├── AsNeeded/
│   ├── Services/
│   │   ├── Persistence/
│   │   │   └── DataStore.swift (✅ Updated for App Group)
│   │   └── QuickActionHandler.swift (✅ NEW)
│   ├── Info.plist (✅ Updated with Quick Actions)
│   ├── AsNeeded.entitlements (✅ Already has App Group)
│   └── AsNeededApp.swift (✅ Updated with URL & shortcut handling)
│
└── AsNeededWidget/ (✅ NEW Widget Extension)
    ├── AsNeededWidget.swift (Widget bundle entry point)
    ├── WidgetDataProvider.swift (Shared data access)
    ├── MedicationSmallWidget.swift (Small widget)
    ├── MedicationMediumWidget.swift (Medium widget)
    ├── MedicationLargeWidget.swift (Large widget)
    ├── MedicationLockScreenWidget.swift (Lock screen widgets)
    ├── MedicationLiveActivityAttributes.swift (ActivityKit attributes)
    ├── MedicationLiveActivityBridge.swift (Shared refresh bridge)
    ├── MedicationLiveActivityWidget.swift (Live Activity UI)
    ├── LogDoseWidgetIntent.swift (Interactive logging intent)
    ├── Info.plist (Widget extension config)
    └── AsNeededWidget.entitlements (App Group entitlements)
```

## Step 1: Add Widget Extension Target to Xcode

Since the Xcode project file cannot be edited directly via script, you need to manually add the widget extension target:

### In Xcode:

1. **Add Widget Extension Target** (Option A - Recommended):
   - File → New → Target
   - Select "Widget Extension"
   - Product Name: `AsNeededWidget`
   - Bundle Identifier: `com.codedbydan.AsNeeded.AsNeededWidget`
   - **IMPORTANT**: Uncheck "Include Configuration Intent" (we don't need it)
   - Click Finish
   - **Delete** the auto-generated files (Xcode creates a template we're not using):
     - Delete `AsNeededWidget.swift` (Xcode's template)
     - Delete `AsNeededWidgetBundle.swift` (if created)

2. **Add Our Widget Files to Target**:
   - In Project Navigator, select all files in `AsNeededWidget/` folder
   - Right-click → "Add Files to AsNeeded..."
   - **Target Membership**: Check ONLY `AsNeededWidget` target
   - Click Add

3. **Configure Widget Target Settings**:
   - Select `AsNeededWidget` target in project settings
   - **General Tab**:
     - Bundle Identifier: `com.codedbydan.AsNeeded.AsNeededWidget`
     - iOS Deployment Target: 18.0 (or your minimum)
     - Supports multiple windows: OFF
   - **Signing & Capabilities Tab**:
     - Enable Automatic Signing
     - Add Capability: App Groups
       - Check: `group.com.codedbydan.AsNeeded`
   - **Build Settings Tab**:
     - Product Bundle Identifier: `$(PRODUCT_BUNDLE_IDENTIFIER)`
     - Marketing Version: Match main app
     - Current Project Version: Match main app
   - **Info Tab**:
     - Use custom Info.plist: `AsNeededWidget/Info.plist`

4. **Link ANModelKit to Widget Extension**:
   - Select AsNeeded project → AsNeededWidget target
   - Build Phases → Link Binary With Libraries
   - Click `+` → Add `ANModelKit` (local package)
   - Click `+` → Add `Boutique` (if not already added)

5. **Add URL Scheme (if not already present)**:
   - Select main `AsNeeded` target
   - Info tab → URL Types → Add (`+`)
     - Identifier: `asneeded`
     - URL Schemes: `asneeded`
     - Role: Editor

## Step 2: Build & Run

### Build the Widget Extension

```bash
# From project root
xcodebuild -scheme AsNeededWidget -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Or using our optimized script (update to include widget):

```bash
./scripts/dev-build.sh
```

### Test Widgets

1. **Run the main app** first to populate some data
2. **Add Widget to Home Screen**:
   - Long-press home screen
   - Tap `+` in top-left
   - Search for "As Needed"
   - Choose widget size
   - Add Widget

3. **Add Lock Screen Widget** (iOS 16+):
   - Lock iPhone
   - Long-press lock screen
   - Tap "Customize"
   - Tap lock screen area below time
   - Search for "As Needed"
   - Choose widget style

4. **Test Quick Actions**:
   - Long-press (3D Touch / Haptic Touch) app icon
   - Should see 4 quick actions:
     - Log Dose
     - View History
     - Add Medication
     - View Trends

### Test Deep Linking

Test widget deep links using command line:

```bash
# Test log dose link
xcrun simctl openurl booted "asneeded://log"

# Test log specific medication (replace UUID)
xcrun simctl openurl booted "asneeded://log/123e4567-e89b-12d3-a456-426614174000"

# Test history
xcrun simctl openurl booted "asneeded://history"

# Test trends
xcrun simctl openurl booted "asneeded://trends"
```

## Step 3: Verify Data Sharing

### Check App Group Container

Add this test code temporarily to verify shared container access:

```swift
// In DataStore.swift init() after sharedContainerURL is obtained
print("Shared container path: \(sharedContainerURL.path)")

// In WidgetDataProvider init()
print("Widget accessing shared container: \(sharedContainerURL.path)")
```

Both should print the **same path**, confirming data sharing works.

### Verify Widget Updates

1. Add a medication in the main app
2. Go to home screen
3. Widget should update within 15 minutes (or force-refresh by re-adding widget)

### Verify Live Activities

1. Log a dose for a medication with interval guidance enabled
2. Confirm the Live Activity appears on the Lock Screen or Dynamic Island
3. Log another dose or update inventory and verify the Live Activity refreshes to the newest guidance state

## Architecture Details

### Data Flow

```
Main App → DataStore → Shared Container (App Group)
                              ↓
                      Widget Extension
                              ↓
              WidgetDataProvider / Live Activity Bridge
                              ↓
                  Widget Views / Live Activity UI
```

### URL Scheme Format

```
asneeded://log                    → Log dose (any medication)
asneeded://log/<medicationID>     → Log specific medication
asneeded://history                → Open history tab
asneeded://trends                 → Open trends tab
asneeded://add                    → Add new medication
```

### Quick Action Types

Defined in `Info.plist` under `UIApplicationShortcutItems`:

1. `com.codedbydan.AsNeeded.quickaction.logdose`
2. `com.codedbydan.AsNeeded.quickaction.history`
3. `com.codedbydan.AsNeeded.quickaction.addmed`
4. `com.codedbydan.AsNeeded.quickaction.trends`

## Troubleshooting

### Widget Not Showing Data

**Problem**: Widget shows "No Medications" but main app has data

**Solutions**:
1. Verify App Group is configured in **both** targets (main app AND widget)
2. Check entitlements files have matching group IDs
3. Delete and re-add widget to home screen
4. Check Xcode console for DataStore errors

### Quick Actions Not Working

**Problem**: Long-press app icon doesn't show actions

**Solutions**:
1. Verify `UIApplicationShortcutItems` in main app's `Info.plist`
2. Check bundle identifiers match
3. Clean build folder (⌘⇧K)
4. Delete app from device/simulator and reinstall

### Deep Links Not Working

**Problem**: Tapping widget doesn't open app

**Solutions**:
1. Verify URL scheme registered in main app target Info
2. Check `.onOpenURL` modifier is present in `AsNeededApp.swift`
3. Ensure `QuickActionHandler` is properly injected as environment object
4. Test URL manually with `xcrun simctl openurl`

### Widget Not Updating

**Problem**: Widget shows old data after app update

**Solutions**:
1. Widgets update every 15 minutes by default
2. Force update: Remove and re-add widget
3. Check WidgetKit timeline policy settings
4. Use `WidgetCenter.shared.reloadAllTimelines()` in app after data changes

## Future Enhancements

### Immediate (Phase 1)
- [x] Home screen widgets (Small, Medium, Large)
- [x] Lock screen widgets (iOS 16+)
- [x] Live Activities for next-dose status
- [x] App icon quick actions
- [x] Deep linking support
- [x] Shared data container

### Phase 2
- [x] Interactive widgets (iOS 17+) with direct log button
- [ ] Widget customization options
- [ ] Multiple Live Activity presentation styles for medication-specific pinning
- [ ] Multiple widget configurations
- [ ] Smart Stack support
- [ ] Live Activities for active doses

### Phase 3
- [ ] Apple Watch complications (see Watch integration guide)
- [ ] Focus mode integration
- [ ] Shortcuts app actions

## Performance Considerations

### Widget Update Frequency

- Widgets refresh every **15 minutes** (configurable in provider)
- Balance between battery life and data freshness
- Consider reducing frequency for better battery

### Data Loading

- `WidgetDataProvider` loads data synchronously on widget render
- Boutique caches are fast (SQLite-backed)
- Limit displayed medications to 3-6 for performance

### Memory Usage

- Widgets run in separate process with strict memory limits
- Keep widget views lightweight
- Avoid heavy image processing

## Testing Checklist

Before submitting to App Store:

- [ ] All widget sizes work correctly (Small, Medium, Large)
- [ ] Lock screen widgets display properly
- [ ] Quick actions navigate correctly
- [ ] Deep links work from widgets
- [ ] Data syncs between app and widgets
- [ ] Widgets update within reasonable time
- [ ] Empty states display correctly
- [ ] Accessibility labels present
- [ ] Dark mode supported
- [ ] Dynamic Type scaling works
- [ ] No crashes in widget extension
- [ ] Performance acceptable on older devices

## References

- [Apple WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [App Groups Documentation](https://developer.apple.com/documentation/security/entitlements/com_apple_security_application-groups)
- [URL Scheme Documentation](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content)
- [UIApplicationShortcutItem](https://developer.apple.com/documentation/uikit/uiapplicationshortcutitem)

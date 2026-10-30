# WristAsNeeded Watch Widget Integration

## Overview

Watch complications for AsNeeded medication tracking app. Displays medication information directly on Apple Watch faces.

## Complications Provided

### 1. Next Medication Widget
Shows the next medication to take with its icon and name.

**Supported Families**:
- Circular (icon + name)
- Rectangular (icon + "Next Dose" label + name)
- Corner (name with icon label)
- Inline (text: "Next: [name]")

### 2. Medication Count Widget
Shows total medication count and doses taken today.

**Supported Families**:
- Circular (pills icon + count number)
- Rectangular (medications count + doses today)
- Inline (text: "X meds, Y today")

## Setup Instructions

### In Xcode:

1. **Add Watch Widget Extension Target**:
   - File → New → Target
   - Select "Widget Extension" (for watchOS)
   - Product Name: `WristAsNeededWidget`
   - Bundle Identifier: `com.codedbydan.AsNeeded.watchkitapp.WristAsNeededWidget`
   - **IMPORTANT**: Uncheck "Include Configuration Intent"
   - Click Finish

2. **Add Widget Files to Target**:
   - Select all files in `WristAsNeededWidget/` folder
   - Right-click → "Add Files to AsNeeded..."
   - **Target Membership**: Check ONLY `WristAsNeededWidget` target
   - Click Add

3. **Configure Widget Target Settings**:
   - Select `WristAsNeededWidget` target
   - **General Tab**:
     - Bundle Identifier: `com.codedbydan.AsNeeded.watchkitapp.WristAsNeededWidget`
     - watchOS Deployment Target: 10.0 (or your minimum)
   - **Signing & Capabilities Tab**:
     - Enable Automatic Signing
     - Add Capability: App Groups
       - Check: `group.com.codedbydan.AsNeeded`
   - **Build Settings Tab**:
     - Product Bundle Identifier: `$(PRODUCT_BUNDLE_IDENTIFIER)`
   - **Info Tab**:
     - Use custom Info.plist: `WristAsNeededWidget/Info.plist`

4. **Link Dependencies**:
   - Build Phases → Link Binary With Libraries
   - Add: `ANModelKit` (local package)
   - Add: `Boutique` (if not already added)

## Data Sharing

Complications use the same App Group (`group.com.codedbydan.AsNeeded`) as:
- Main iOS app
- iOS widgets
- Watch app

All access the same shared Boutique stores for medications and events.

## Testing

### Add Complications:

1. **On Physical Apple Watch**:
   - Edit watch face
   - Tap complication slot
   - Scroll to "AsNeeded"
   - Select desired complication

2. **In Simulator**:
   - Run watch scheme
   - Long-press watch face
   - Tap "Edit"
   - Add complications

### Verify Updates:

- Add medication in iOS app
- Complication should update within 30-60 minutes
- Force update: Remove and re-add complication

## Performance

- **Update Frequency**:
  - Next Medication: Every 1 hour
  - Medication Count: Every 30 minutes
- **Memory**: Keep complications lightweight
- **Battery**: Minimal impact with hourly updates

## Troubleshooting

### Complication Not Showing
1. Verify WristAsNeededWidget target builds successfully
2. Check App Group is configured in watch widget entitlements
3. Ensure watch app is paired and running
4. Delete and re-add complication

### Data Not Syncing
1. Verify App Group identifier matches across all targets
2. Check Boutique stores use same database filenames
3. Test with iOS app and watch app both installed
4. Check Xcode console for errors

## File Structure

```
WristAsNeededWidget/
├── WristAsNeededWidget.swift          # Widget bundle entry point
├── WatchWidgetDataProvider.swift      # Shared data access
├── NextMedicationWidget.swift         # Next medication complication
├── MedicationCountWidget.swift        # Count/doses complication
├── Info.plist                         # Widget extension config
├── WristAsNeededWidget.entitlements   # App Group entitlements
└── README.md                          # This file
```

## Future Enhancements

- [ ] Interactive complications (watchOS 9+) for quick dose logging
- [ ] Refill reminder complication
- [ ] Last dose taken complication
- [ ] Live Activities integration
- [ ] Customization options (color, display style)

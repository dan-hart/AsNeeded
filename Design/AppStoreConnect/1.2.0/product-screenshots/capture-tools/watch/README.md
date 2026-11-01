# Watch screenshot provenance

Captured October 29, 2026 on dedicated simulator `E57095CB-E19C-4CE4-A0EB-CBB421C020A0` (AsNeeded Marketing Watch 321, watchOS 26.5), native 416 x 496 PNG. Build 321 UI sources were copied verbatim from the working checkout; no production source was modified.

These four images are **capture-harness renders of production Watch views**, not evidence of successful companion sync. The separate nonshipping `com.codedbydan.AsNeeded.watchcapture` app supplies fictional in-memory data and directly selects the requested production view. Its sender never saves actions. The Watch app has no History or Trends screen; the approved alternatives are Medications, Details, Log Dose, and Update Quantity.

## Why a harness was used

The dedicated Watch/phone pair was active and connected. Watch-to-phone `getMedications` requests arrived, but iPhone WatchConnectivity reported `appInstalled: NO`, `reachable: NO` and `WCSession counterpart app not installed`, despite the actual installed matching Watch app and embedded companion bundle. Restarting the dedicated pair's `wcd` services and re-registering/relaunching the same iPhone build did not repair it. The production phone code only sends the response while `session.isReachable`, leaving Watch unavailable. No sync/storage code was changed.

## Unchanged source files

Copy these current production files into a temporary `Sources/` directory next to `CaptureApp.swift` (rename the saved `.swift.txt` file):

- `WristAsNeeded Watch App/MedicationListView.swift`
- `WristAsNeeded Watch App/MedicationDetailView.swift`
- `WristAsNeeded Watch App/DoseLoggerView.swift`
- `WristAsNeeded Watch App/QuantityEditorView.swift`
- `WristAsNeeded Watch App/WatchMedication.swift`

Do not copy production WCSender, ContentView or App entrypoint: the saved harness supplies only those boundaries. It preserves actual view layouts, including their native scroll extents, system font, blue/purple accent, truncated quantity navigation title, and two medication rows visible at this screen size. It does not add yellow/Atkinson styling inside the Watch UI. Marketing framing applies those outside the raw screenshot.

Fixture list: Headache Help 42 / 1 tablet; Breathe Easy 72 / 2 puff; Wind Down 14 / 0.5 tablet. The first is the selected medication for all detail/editor shots. Breathe Easy's next saved interval is 150 minutes after launch; other two meet their saved intervals. No historical screens or fake charts were fabricated.

## Reproduction

1. Create temporary `Capture.app` and `Sources` directories. Copy the five verbatim sources and saved CaptureApp.swift.txt to `Sources/CaptureApp.swift`.
2. Copy saved Info.plist.txt to `Capture.app/Info.plist`. Copy `Assets.car` from the existing production Watch app bundle into `Capture.app` to preserve actual accent assets.
3. Compile with the installed Xcode watch simulator SDK (local run used Xcode 27.2 RC):

```sh
CAPTURE_ROOT=/tmp/asneeded-watch-capture
WATCH_SDK=$(xcrun --sdk watchsimulator --show-sdk-path)
xcrun --sdk watchsimulator swiftc -module-cache-path "$CAPTURE_ROOT/ModuleCache" -sdk "$WATCH_SDK" -target arm64-apple-watchos26.0-simulator -module-name WristAsNeededCapture -o "$CAPTURE_ROOT/Capture.app/Capture" "$CAPTURE_ROOT"/Sources/*.swift
codesign --force --sign - "$CAPTURE_ROOT/Capture.app"
xcrun simctl install E57095CB-E19C-4CE4-A0EB-CBB421C020A0 "$CAPTURE_ROOT/Capture.app"
```

4. Launch each state with `xcrun simctl launch --terminate-running-process E57095CB-E19C-4CE4-A0EB-CBB421C020A0 com.codedbydan.AsNeeded.watchcapture STATE`, where STATE is `medications`, `details`, `dose`, or `quantity`.
5. Wait for SwiftUI layout, then use `xcrun simctl io E57095CB-E19C-4CE4-A0EB-CBB421C020A0 screenshot OUTPUT.png`.

Attempting `simctl status_bar ... override --time 9:41` returned NSPOSIXErrorDomain 45, Operation not supported, because status overrides are unsupported on this Watch platform. Screenshots retain the native simulator clock; no raw pixels were edited.

## Final real scroll positions

The final Details and Log Dose captures were scrolled upward with actual simulator HID swipes `(104,213) → (104,125)` and `(104,214) → (104,125)` respectively (0.7 seconds, simulator points). Details shows its real Log Dose and Quick Log buttons. Log Dose shows tablet units and the actual Log Dose CTA. Quantity used `(104,215) → (104,95)` (0.7 seconds), showing the actual New Quantity amount, minus/plus, and Add 5. Save Quantity is farther below; this native 416 x 496 viewport cannot display both amount controls and the Save CTA together. The screenshot preserves the real control viewport rather than altering layout. The Medications list retains its initial position. No UI source or raw screenshot pixels were modified to achieve these positions.

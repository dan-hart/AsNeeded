# Product-page screenshots — 1.2.0

Approved assets uploaded to App Store Connect for **1.2.0, en-US**. All images were read back as **COMPLETE**, with matching checksums, dimensions, and order. See `upload-receipt.json` for asset IDs and verification. The version remains in Prepare for Submission; this upload did not submit or release the app.

Open `preview.jpg` for the contact sheet. The device folders contain opaque RGB PNGs for upload; `raw/` contains the corresponding unframed UI captures.

The 20 approved images occupy four device families: iPhone (4), Duo (8, outer then inner), iPad (4), and Watch (4). Another eight size-matched copies replace the existing 6.5-inch iPhone and Watch Ultra slots. Those copies preserve aspect ratio and add the same yellow at the edges; they do not stretch the device artwork. The previous ten remote images were backed up outside Git before replacement.

## Design

- Icon background yellow: **#F1D89C**.
- Marketing text: bundled **Atkinson Hyperlegible** font.
- Four scenes for iPhone, iPad, and both Duo displays: Medication, History, Trends, Log Dose.
- Watch uses its actual Medications, Medication Details, Log Dose, and Update Quantity views. Watch does not offer History or Trends.
- iPhone, iPad, and Watch hardware frames come from Koubou 0.20.0. Duo inner and outer hardware frames come from MIT-licensed AppleFramer, pinned to revision `ad533b08fa6ce995b88f36c68a997d7293736cf7`; bundled assets, license, and hashes are under `capture-tools/duo-frames/`.

## Fictional records

The examples are Headache Help / Pain Relief (coral, brain icon), Breathe Easy / Rescue Inhaler (teal, wind icon), and Wind Down / Sleep Support (purple, moon icon). Ninety days of synthetic history contain 496 entries, notes, and symptom/effectiveness ratings. Headache Help decreases across the recent month; Breathe Easy increases, with modest variation in both. Phone and iPad Trends show the decrease; Duo Trends show the increase. These are fictional demonstrations, not dosing recommendations or claims that the app changes medication use. No personal records are included.

`sample-data.json` is a normal app export generated with the real models and imported through the existing importer. The capture-only bootstrap is retained as `capture-tools/MarketingCaptureSeed.swift.txt`; it is deliberately outside app and test targets. Its simulator-name guard restricts it to dedicated marketing simulators.

## Capture provenance

Source: 1.2.0 (321), commit bc3802e. No shipping UI changes were made for these assets.

- iPhone 17: iOS 26.5, 1206 × 2622.
- iPad Pro 13-inch: iOS 26.5, 2064 × 2752.
- Duo outer: iOS 27.2 simulator, 1398 × 2034.
- Duo inner: iOS 27.2 simulator, 2853 × 2007 (landscape).
- Watch Series 11 46mm: watchOS 26.5, 416 × 496.

Phone, iPad, and Duo images are captures of the running app with imported synthetic data. Watch simulator companion registration failed despite an active pair; its capture-only harness renders unchanged production SwiftUI views with an in-memory fixture. These Watch captures demonstrate the actual views, but do not establish live WatchConnectivity sync.

`capture-tools/render.py` creates the marketing compositions and manifest. It needs Pillow and `asc` with Koubou 0.20.0 on PATH. Set `SKIP_FRAMES=1` to reuse existing phone/iPad frame renders. `capture-tools/frame_duo.py` composes the full native captures with the original frame assets/masks before proportional resizing onto yellow. It can also export transparent intermediates to the ignored `intermediate/` folder. `manifest.json` records final dimensions and SHA-256 hashes. Simulator UI was inspected for each capture; no device runtime regression testing is implied.

Screenshot dimensions: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications

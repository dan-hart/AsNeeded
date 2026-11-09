# Design sources and release assets

Keep editable originals, app icons, licensed frames, approved captures, synthetic fixtures, and generation/upload provenance. A release folder is a historical record; do not label it as a new app build without recapturing and verifying it.

- App icon and shipped image sources: `AsNeeded/AppIcon.icon/` and `AsNeeded/Assets.xcassets/` in the application tree. `IC AsNeeded Exports/` contains exported design assets; retain the editable `.xcf` templates in `AppStoreConnect/`.
- [1.2.0 release assets](AppStoreConnect/1.2.0/README.md): product screenshots, localized artwork, creative images, and store copy with their provenance.
- [Older build-306 captures](AppStoreConnect/archive/1.2.0-build306/README.md): superseded six-image set, retained for history. Its duplicate distribution ZIP was removed only after all six member hashes matched the retained individual files.
- `archive/v01/`: earlier icon exploration.

New release work should use a named version directory and synthetic data. Ignore local intermediate render output and distribution ZIPs; do not blanket-ignore the manifests, source captures, licenses, or approved final artwork needed to reproduce a release.

For maintenance, check project resource membership, renderer inputs, manifests, and incoming links before retiring an asset. Keep approved uploads and their editable sources together. The loose top/bottom pill PNG exports were removed after confirming byte-identical copies in the 1.2.0 creative assets folder. The editable XCFs and the app icon layers remain.

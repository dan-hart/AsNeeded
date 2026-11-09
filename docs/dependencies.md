# Dependency maintenance

The [Xcode project](../AsNeeded.xcodeproj/project.pbxproj) declares package requirements and target products. The committed [Package.resolved](../AsNeeded.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved) records exact revisions for direct and transitive packages. The About screen displays those pins through [PackageDependencyManager](../AsNeeded/Services/PackageDependencyManager.swift).

## Direct Swift packages

| Package | Linked targets and products | Role in AsNeeded |
| --- | --- | --- |
| ANModelKit | `AsNeeded`, `AsNeededWidgetExtension` · `ANModelKit` | Shared medication, dose, unit, and event records used in app workflows and widget data. |
| Boutique | `AsNeeded`, `AsNeededWidgetExtension` · `Boutique` | Persists medication and event records on iOS. The widget reads those stores through [WidgetDataProvider](../AsNeededWidget/WidgetDataProvider.swift). |
| DHFlatUIColors | `AsNeeded` · `DHFlatUIColors` | Historically supplied medication colors. The active [palette](../AsNeeded/Extensions/MedicationColors.swift) uses local definitions and the product remains linked without a current source import. Its project requirement follows `main`, with the committed lockfile selecting the build revision. |
| DHLoggingKit | `AsNeeded` · `DHLoggingKit` | App diagnostics for persistence, medication logging, notifications, Watch messages, and purchases. |
| purchases-ios | `AsNeeded` · `RevenueCat`, `RevenueCatUI`, `ReceiptParser` | [RevenueCatManager](../AsNeeded/Services/RevenueCatManager.swift) uses `RevenueCat` for optional tip purchases. The other two products are linked and have no direct source imports. |
| SFSafeSymbols | `AsNeeded`, `AsNeededWidgetExtension` · `SFSafeSymbols` | Type-safe SF Symbol names in app controls and widget views. |
| SwiftRxNorm | `AsNeeded` · `SwiftRxNorm` | RxNorm lookup, parsing, and result handling for [medication search](../AsNeeded/Services/MedicationSearchService.swift). |

The Watch app has no direct package products. The app-hosted `AsNeededTests` target has no package products of its own and imports some modules through the app build.

## Updating and rolling back

1. Review upstream source, release notes, minimum platform versions, licenses, and the resolved transitive changes. Keep a change scoped to the package or fix under review. For storage and shared model dependencies, follow the [storage safety rules](../ai-rules/storage-safety.md).
2. Update the project requirement when needed, resolve in Xcode, and review `Package.resolved`. Keep the lockfile and About metadata together. `python3 scripts/tests/dependency-metadata.test.py` checks that the displayed versions and revisions match the lockfile.
3. Verify the resolved graph from a fresh checkout using `xcodebuild -resolvePackageDependencies -project AsNeeded.xcodeproj -scheme AsNeeded -onlyUsePackageVersionsFromResolvedFile`. Run the affected target checks and the [simulator suite](../scripts/README.md#unit-tests). For purchase changes, verify both keyless and configured builds. For a persistence update, rehearse a synthetic in-place upgrade before release.
4. If verification fails after publication of a dependency change, revert that change as a unit so the project, lockfile, and About metadata agree. Repeat locked resolution and the relevant checks. A dependency revert after shipping a storage change still requires compatibility review for records written by the newer build.

## GitHub Actions

Keep remote `uses:` references in [the workflows](../.github/workflows/) at verified full commit SHAs with a version or source-ref comment. Resolve each new ref against its upstream repository. For example, `git ls-remote https://github.com/actions/checkout.git 'refs/tags/v4.4.0' 'refs/tags/v4.4.0^{}'` returns the tag and, for annotated tags, the underlying commit on the `^{}` line. Inspect the action manifest and inputs at that commit and run the affected workflows. The TruffleHog action still uses its upstream default CLI image tag. Its action commit pin covers the workflow code.

If an action update breaks a check, restore its last verified commit SHA and related inputs together, then rerun the affected job. Preserve secret scanners, scoped permissions, checksum verification, and storage-review checks during updates and rollback.

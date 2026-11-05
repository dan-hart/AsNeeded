# Architecture and source ownership

AsNeeded is a native SwiftUI iOS app, iOS widget extension, and independent watchOS app. The Xcode project also configures the Swift Testing unit-test target. Most source membership uses file-system synchronized groups; an empty explicit Sources list does not mean a target has no code.

## Boundaries

| Area | Responsibility |
| --- | --- |
| `AsNeeded/Medication/` and `AsNeeded/Views/` | SwiftUI screens, reusable components, and UI state owners |
| `AsNeeded/Services/` | Deterministic guidance/projections, notifications, purchase integration, search, and external-effect adapters |
| `AsNeeded/Services/Persistence/` | App Group storage, migration, recovery, import/export, and serialized dose/stock transactions |
| `AsNeededWidget/` | Timeline snapshots, configuration, projections, and medication-specific navigation |
| `WristAsNeeded Watch App/` | Watch presentation, local message DTOs, and WCSession transport |
| `AsNeededTests/` | Domain/service/view-model regressions with injected storage, time, and external clients |
| Remote Swift packages | ANModelKit records, Boutique persistence, RxNorm lookup, logging, symbols, colors, and purchase SDKs; exact resolved revisions are in `Package.resolved` |

ANModelKit contains medication, dose, event, and unit records. Calculations belong in testable services; UI state owners compose them with persistence and presentation. Keep state ownership and the surrounding Observation/ObservableObject pattern consistent when making a narrow change.

## Recording and recovery

The app's `DataStore` uses `MedicationPersistenceTransactions` to coordinate medication, event, stock, and preference updates. Await recovery/loading before deriving availability or acting on a snapshot. A failed or canceled operation must not be treated as a committed dose. Shared app/widget access is a cross-process storage boundary, not merely a main-actor concern.

The Watch app does not open the phone's Boutique databases. It sends identified requests through WCSession; the iPhone validates and persists them. Queued transport and completed recording are distinct outcomes.

Notification action handling and widget intents are platform-discovered entry points. A lack of direct Swift callers is not grounds for removing their identity. Background Log actions use the recording policy and an idempotent event identity; paths needing review navigate to the medication form instead. Home Screen widgets favor navigation to app review.

## Changes and verification

Read [business rules](business-rules.md), [storage safety](DATA_STORAGE_GUIDELINES.md), and the relevant [rule module](../ai-rules/rule-loading.md) before changing an ownership or persistence boundary. Prefer small reversible changes with an observed regression or a concrete new requirement. Do not introduce a broad architecture, dependency, storage, or observation migration as routine cleanup.

Build the app scheme after project/shared-source changes; it includes the iOS widget and Watch dependencies. Run relevant tests and check the actual Xcode result bundle. CI, simulator, and physical-device evidence prove different things. See [scripts](../scripts/README.md) and [Drift](drift.md).

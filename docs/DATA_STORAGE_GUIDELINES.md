# Data Storage Guidelines

## Overview

This document establishes mandatory guidelines for managing data storage in AsNeeded to prevent data loss incidents. These guidelines were created in response to a critical data loss bug discovered in October 2025 that affected all users.

**CRITICAL**: All developers and AI agents working on this codebase MUST follow these guidelines when making ANY changes to data storage.

---

## The October 2025 Data Loss Incident

### What Happened

On October 13, 2025, commit `61e6ad5` ("WIP Intents") migrated database storage from the app's default container to an App Group container to enable widget/extension support. **The migration was implemented without any data migration logic**, causing all existing user data to become inaccessible.

### Root Cause

The commit changed:
1. **Storage Location**: From `Library/Application Support/` to `group.com.codedbydan.AsNeeded/`
2. **Database Filenames**: From `medications.sqlite`/`events.sqlite` to `medications`/`events`

Without migration code, users who updated saw:
- Empty medication lists
- All dose logs disappeared
- Complete loss of historical data

### Impact

- **All users** who had data before October 13, 2025 lost access to their data
- Data was not deleted, but became orphaned in the old storage location
- Users likely assumed data was permanently lost

### Resolution

A `DataMigrationManager` was implemented to:
- Detect legacy database files
- Merge data from both old and new locations
- Preserve all user data (no data loss)
- Run automatically on app launch

**Location**: `DataMigrationManager.swift` (path: `AsNeeded/Services/Persistence`)

---

## The December 2025 Repeated Migration Bug

### What Happened

Users reported that medication quantity kept resetting to an old value (e.g., 192) on every app restart. This affected longtime users who had data from before the October 2025 migration.

### Root Cause Analysis

The `DataMigrationManager` was designed to be "data-driven" (no flags), checking for legacy data on every launch. However, **legacy database files were never deleted or archived after migration**, causing a critical bug:

1. **Legacy files persist forever**: `Documents/medications.sqlite/` was never removed after migration
2. **Migration runs on every launch**: Because legacy files still exist, `findLegacyDatabases()` always finds them
3. **Merge logic overwrites current data**: The `mergeByID()` function explicitly states "Legacy items overwrite current items with same ID"
4. **User data is lost on each restart**: Any changes made by the user get overwritten with stale legacy values

### The Bug Flow

```
App Launch #1 (after fix was deployed):
  ├─ User has legacy data in Documents/medications.sqlite/ (quantity=192)
  ├─ Migration runs, merges legacy → App Group
  ├─ User updates quantity to 30
  └─ App works correctly

App Launch #2:
  ├─ findLegacyDatabases() finds Documents/medications.sqlite/ (still exists!)
  ├─ Migration runs AGAIN
  ├─ mergeByID() overwrites current quantity (30) with legacy quantity (192)
  └─ User sees quantity reverted to 192 ❌
```

### Why "Data-Driven" Migration Failed

The original design claimed "No flags needed - purely based on presence of data". This was flawed because:

| Assumption | Reality |
|------------|---------|
| "If legacy data exists, migrate it" | Legacy data exists forever since it's never cleaned up |
| "Data-driven is simpler" | Simpler only if you clean up after migration |
| "Idempotent - running multiple times produces same result" | Running repeatedly **overwrites** user changes |

### Resolution (December 2025)

The fix archives (not deletes) legacy databases after successful migration:

1. **After `verifyMerge()` succeeds**: Call `archiveLegacyDatabases()`
2. **Rename legacy folders**: `medications.sqlite` → `medications.sqlite.migrated-YYYYMMDD`
3. **Track archived paths**: Store in UserDefaults for potential recovery
4. **Subsequent launches**: `findLegacyDatabases()` returns nil (renamed folders don't match)

### Why Rename Instead of Delete?

Given the October 2025 data loss incident, we chose the safest approach:

| Approach | Risk | Chosen |
|----------|------|--------|
| Delete legacy files | Irreversible if something goes wrong | ❌ |
| Rename legacy files | Recoverable, debugging possible | ✅ |
| Use UserDefaults flag | Flag can get stuck, doesn't fix root cause | ❌ |

### Files Changed

| File | Change |
|------|--------|
| `UserDefaultsKeys.swift` | Added `archivedLegacyMedicationsPath`, `archivedLegacyEventsPath` |
| `DataMigrationManager.swift` | Added `archiveLegacyDatabases()`, `findArchivedLegacyDatabases()` |

### Recovery Helper

If you need to access archived legacy data:

```swift
let archived = DataMigrationManager().findArchivedLegacyDatabases()
// archived.medications → URL to Documents/medications.sqlite.migrated-20251203/
// archived.events → URL to Documents/events.sqlite.migrated-20251203/
```

Archived paths are also stored in UserDefaults:
- `UserDefaultsKeys.archivedLegacyMedicationsPath`
- `UserDefaultsKeys.archivedLegacyEventsPath`

### Lessons Learned

1. **"Data-driven" migration must include cleanup** - Presence of data is not sufficient; you must also clean up after migration
2. **Test migration across multiple app restarts** - Single-launch testing missed this bug
3. **Prefer rename over delete** - Data safety trumps disk space
4. **Track what you change** - Store archived paths for recovery/debugging
5. **Red-team your hypotheses** - Initial hypothesis (Watch Connectivity) was wrong; thorough analysis found the real cause

---

## January 2026 Migration Safety Hardening

### What Changed

Migration verification and archival were tightened to prevent silent data loss during legacy merges:

1. **ID-preservation verification**: `verifyMerge()` now checks that **all legacy IDs** exist post-merge, not just that counts are >= legacy counts.
2. **Flat legacy DB archival**: Legacy databases stored as flat files are archived by moving only the DB + WAL/SHM into a dedicated archive folder, avoiding accidental parent directory moves.
3. **Fail-safe on verification errors**: If verification fails, migration throws and **does not archive** legacy DBs so recovery remains possible.

### Why This Matters

Count-based verification can pass even if some legacy IDs are missing (e.g., collisions, overwrite bugs). ID-based verification ensures **no legacy record is lost** in the merge.

Flat legacy databases can live alongside other files. Moving the parent directory risks moving unrelated data. The new approach isolates archival to the DB artifacts only.

### Tests Added

- **Legacy ID preservation** after migration.
- **Migration failure does not archive** legacy databases.
- **Flat legacy DB archival** does not move the parent directory.
- **Backup → migrate → restore** end-to-end test via `BackupManager`.

### Files Updated

- `DataMigrationManager.swift` (path: `AsNeeded/Services/Persistence`)
- `DataMigrationManagerTests.swift` (path: `AsNeededTests`)
- `DataIntegrityTests.swift` (path: `AsNeededTests`)

---

## Mandatory Storage Change Procedures

### RULE #1: Never Change Storage Paths Without Migration

**ANY** change to database storage locations REQUIRES a migration strategy:

❌ **NEVER DO THIS:**
```swift
// Old code
medicationsStore = Store<ANMedicationConcept>(
    storage: SQLiteStorageEngine.default(appendingPath: "medications"),
    cacheIdentifier: \ANMedicationConcept.id.uuidString
)

// Changed to (WITHOUT MIGRATION)
medicationsStore = Store<ANMedicationConcept>(
    storage: SQLiteStorageEngine(
        directory: FileManager.Directory(url: newContainerURL),
        databaseFilename: "medications"
    )!,
    cacheIdentifier: \ANMedicationConcept.id.uuidString
)
```

✅ **ALWAYS DO THIS:**
1. Create migration manager
2. Implement data transfer logic
3. Test migration thoroughly
4. Update documentation
5. Then change storage paths

### RULE #2: Test Migration on Real User Data

Before deploying ANY storage change:

1. **Create test data** in the old location
2. **Run migration** in simulator/device
3. **Verify** all data appears in new location
4. **Test edge cases**: empty database, large database, partial data
5. **Test idempotency**: Run migration multiple times
6. **Verify non-destructive**: Old data still exists after migration

### RULE #3: Document Storage Architecture

Any storage change MUST update this document with:
- Current storage locations
- Database file names and formats
- Migration history
- Testing procedures

---

## Current Storage Architecture

### Primary Database Location

**Current** (as of October 2025):
- **Location**: App Group container `group.com.codedbydan.AsNeeded`
- **Medications DB**: `medications.sqlite` (Boutique adds `.sqlite` extension)
- **Events DB**: `events.sqlite`
- **Full Path**: `~/Library/Group Containers/group.com.codedbydan.AsNeeded/medications.sqlite`

**Legacy** (before October 13, 2025):
- **Location**: App's default Application Support directory
- **Medications DB**: `medications.sqlite`
- **Events DB**: `events.sqlite`
- **Full Path**: `~/Library/Application Support/<bundle-id>/medications.sqlite`

### Why App Group?

App Group containers enable data sharing between:
- Main app
- Widgets
- Extensions
- Intents (Siri Shortcuts)

Without App Group, widgets/extensions cannot access the main app's database.

### Storage Engine

**Technology**: Boutique + SQLite
- **Framework**: [Boutique](https://github.com/mergesort/Boutique)
- **Backend**: SQLite via `SQLiteStorageEngine`
- **Cache**: In-memory cache of items
- **Persistence**: Automatic background persistence to SQLite

**Key Files**:
- `DataStore.swift` - Primary data access layer
- `DataMigrationManager.swift` - Migration logic

---

## Migration Code Template

When you need to migrate data to a new storage location, use this template:

```swift
import ANModelKit
import Boutique
import DHLoggingKit
import Foundation

@MainActor
public final class DataMigrationManager {
    private let logger = DHLogger.data

    /// Data-driven migration: checks for legacy data on every launch
    /// No UserDefaults flags - migration state is determined purely by data presence
    public func migrateIfNeeded() async {
        // 1. Check if legacy data exists (data-driven approach)
        guard let legacyPaths = findLegacyDatabases() else {
            logger.debug("No legacy data found - migration not needed")
            return
        }

        logger.info("Starting data migration from legacy location...")

        do {
            // 2. Load data from legacy location
            let legacyData = try await loadLegacyData(legacyPaths)
            logger.info("Loaded legacy data: \\(legacyData.count) items")

            // Skip if legacy is empty
            guard !legacyData.isEmpty else {
                logger.info("Legacy database empty - nothing to migrate")
                return
            }

            // 3. Load existing App Group data
            let currentData = try await loadCurrentData()
            logger.info("Loaded current data: \\(currentData.count) items")

            // 4. Recover missing IDs; preserve edits in the current store
            let mergedData = mergeByID(legacy: legacyData, current: currentData)
            logger.info("Merged data: \\(mergedData.count) items")

            // 5. Write merged data to App Group
            try await writeMergedData(mergedData)

            // 6. Verify migration succeeded
            let verifyData = try await loadCurrentData()
            guard verifyData.count >= legacyData.count else {
                throw MigrationError.verificationFailed
            }

            logger.info("✅ Migration completed successfully")

        } catch {
            logger.error("Migration failed: \\(error)")
            // Will retry on next launch (data-driven, checks for legacy data again)
        }
    }

    private func mergeByID<T: Identifiable>(legacy: [T], current: [T]) -> [T] {
        var itemsById = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        for item in legacy where itemsById[item.id] == nil {
            itemsById[item.id] = item // Current records take precedence
        }
        return Array(itemsById.values)
    }
}
```

### Data-Driven Migration: Critical Requirements

The migration approach is **data-driven** (no UserDefaults flags), but this requires **cleanup after migration**:

1. **Self-healing**: If migration fails, it automatically retries on next launch
2. **Idempotent**: Running multiple times produces the same result (no duplicates)
3. **Simple**: No flag state to manage or get stuck in wrong state
4. **Automatic**: Migration runs when legacy data exists, skips when it doesn't

**⚠️ CRITICAL**: Data-driven migration MUST archive/rename legacy files after success. Otherwise, migration runs on every launch and overwrites user changes. See "The December 2025 Repeated Migration Bug" section.

### Checklist for Implementing Migration

- [ ] Implement `findLegacyDatabases()` to detect legacy data locations
- [ ] Implement `loadLegacyData()` method
- [ ] Implement `loadCurrentData()` method
- [ ] Implement `mergeByID()` logic (current records take precedence; recover missing legacy IDs)
- [ ] Implement `writeMergedData()` method
- [ ] Add verification step
- [ ] **⚠️ Implement `archiveLegacyDatabases()` to rename legacy files after success**
- [ ] **⚠️ Track archived paths in UserDefaults for potential recovery**
- [ ] Call migration from `MigrationCoordinator` before DataStore init
- [ ] Create unit tests (test data-driven behavior, not flag state)
- [ ] **Test across MULTIPLE app restarts** (not just single launch)
- [ ] Test with real data in simulator
- [ ] Test on physical device
- [ ] Document in this file
- [ ] Update CLAUDE.md

---

## Testing Migrations

### Simulator Testing

1. **Create test data in old location:**
```swift
let oldStore = Store<ANMedicationConcept>(
    storage: SQLiteStorageEngine.default(appendingPath: "medications_old"),
    cacheIdentifier: \ANMedicationConcept.id.uuidString
)
try await oldStore.insert(testMedication)
```

2. **Restart app** and verify data migrated (migration is data-driven, no flag reset needed)

3. **Verify idempotency**: Restart again and ensure no duplicates

### Device Testing

**CRITICAL**: Always test on physical device before release
- Simulators may have different file system behavior
- App Group containers work differently on devices
- Permission issues may only appear on devices

### Test Scenarios

| Scenario | Expected Result |
|----------|----------------|
| Fresh install (no old data) | Migration skipped, empty database |
| Old data only | All old data migrated to new location |
| New data only | New data preserved, migration skipped |
| Both old and new data | Data merged, deduplicated by ID |
| Run migration twice | Same result, no duplicates |
| Large database (1000+ items) | All items migrated, acceptable performance |
| Corrupted old database | Migration fails gracefully, logs error |

---

## Storage Best Practices

### 1. Always Use Strongly-Typed Keys

❌ **WRONG:**
```swift
let path = "medications.sqlite"
```

✅ **CORRECT:**
```swift
private static let medicationsDatabaseName = "medications"
```

### 2. Log All Storage Operations

```swift
logger.info("Initializing store at: \\(path)")
logger.debug("Loaded \\(items.count) items from database")
logger.error("Failed to access database: \\(error)")
```

### 3. Never Force Unwrap Storage Paths

❌ **WRONG:**
```swift
let containerURL = FileManager.default.containerURL(...)!
```

✅ **CORRECT:**
```swift
guard let containerURL = FileManager.default.containerURL(...) else {
    logger.error("Unable to access container")
    // Fallback logic
    return
}
```

### 4. Version Your Migration Managers

```swift
DataMigrationManager()        // V1: Legacy → App Group
DataMigrationManager_V2()     // V2: Future migration
DataMigrationManager_V3()     // V3: Another future migration
```

### 5. Document Storage Format Changes

Any change to data models (adding fields, changing types) should be documented here with:
- Date of change
- Reason for change
- Migration strategy (if applicable)
- Backward compatibility notes

---

## Pre-Deployment Checklist

Before deploying ANY storage-related changes:

### Development
- [ ] Storage paths documented in this file
- [ ] Migration code implemented (if paths changed)
- [ ] Migration code tested in simulator
- [ ] Migration code tested on physical device
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing

### Code Review
- [ ] Migration logic reviewed by team
- [ ] Edge cases considered
- [ ] Error handling validated
- [ ] Logging sufficient for debugging
- [ ] Documentation updated

### Testing
- [ ] Fresh install tested
- [ ] Upgrade from previous version tested
- [ ] Large database tested (1000+ items)
- [ ] Migration idempotency verified
- [ ] Data integrity verified
- [ ] Performance acceptable

### Deployment
- [ ] Beta testing completed
- [ ] No critical issues in beta
- [ ] Rollback plan documented
- [ ] Support team notified
- [ ] Release notes include migration notice (if user-visible)

---

## Troubleshooting

### Users Report Missing Data

1. **Check migration logs:**
```bash
# In Xcode Console, filter by "Migration" or "DataStore"
# Look for errors during migration
```

2. **Verify old data location:**
```swift
let appSupportURL = FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
).first
print("Check: \\(appSupportURL)/medications.sqlite")
```

3. **Manually trigger migration** (data-driven, no flag reset needed):
```swift
await DataMigrationManager().migrateIfNeeded()
```

### Migration Performance Issues

- Batch database writes (100 items at a time)
- Show loading indicator for large migrations
- Run migration on background queue (but block app launch)
- Consider incremental migration for very large datasets

### Migration Failures

- Always log detailed error information
- Never delete source data
- Provide user-visible error message with support contact
- Implement retry logic for transient failures
- Offer manual export/import as fallback

---

## References

- **Original Bug Report**: User reported all data missing after update
- **Root Cause Commit**: `61e6ad5` ("WIP Intents", October 13, 2025)
- **Fix Implementation**: `DataMigrationManager.swift`
- **Related Docs**:
  - `WIDGETS_INTEGRATION.md` - Why App Groups are needed
  - `CLAUDE.md` - Agent instructions for storage changes

---

## Appendix: SQLite File Structure

### SQLite Database Files

When using SQLite, you'll see multiple files:

```
medications.sqlite      # Main database file
medications.sqlite-wal  # Write-Ahead Log (performance optimization)
medications.sqlite-shm  # Shared Memory (concurrent access)
```

**IMPORTANT**: When copying/migrating databases, copy ALL three files to maintain data integrity.

### Boutique Storage Engine

Boutique's `SQLiteStorageEngine` automatically:
- Creates database files
- Handles WAL mode
- Manages in-memory cache
- Persists changes automatically

**Do NOT**:
- Manually modify SQLite files
- Delete WAL/SHM files
- Access SQLite directly (use Boutique)

---

## Version History

| Version | Date | Change | Migration Required |
|---------|------|--------|-------------------|
| 1.0 | Pre-Oct 2025 | Default container storage | N/A |
| 2.0 | Oct 13, 2025 | App Group migration | Yes - `DataMigrationManager` |
| 2.1 | Oct 28, 2025 | Data merge fix | No - same manager |
| 2.2 | Dec 3, 2025 | Archive legacy DBs after migration (fixes repeated overwrite bug) | No - same manager, adds cleanup |

---

**Last Updated**: December 3, 2025
**Maintained By**: Development Team
**Review Frequency**: After any storage-related changes

## 1.2.0 Optional Medication Dose Limits (October 2026)

`ANMedicationConcept` now optionally encodes `minimumHoursBetweenDoses`,
`maximumDailyDoseAmount` (quantity in `prescribedUnit`, rolling 24 hours), and
`nextDoseNotificationEnabled`. Missing keys decode to nil; old medication and
event records remain readable. Database paths, filenames and containers are unchanged.

`MedicationDoseLimitMigration` copies legacy safety-profile timing/quantity values
only into absent model fields, persists the medication first, then clears only
those two legacy values. Remaining guardrails are preserved. Failed persistence
keeps legacy values for retry. Once cleared, a later deliberate removal of a
model limit stays removed across restarts. Restore/import is checked again during
availability reconciliation. Existing installs never opt in automatically.

Regression tests cover fresh/model-only/legacy/both states, retry on write failure,
repeated execution, and deliberate removal. Beta testing must verify an upgrade,
multiple launches, backup/restore, watch sync and notification delivery on a physical
device before a public release. Downgrade readers ignore optional model keys;
old versions will not enforce new model-only limits.

### 1.2.0 Experimental Questions Removal

The optional `trendsQuestionsEnabled` setting is no longer read, written, exported,
or applied by the shipping app. Older settings JSON containing that key decodes
successfully because unknown keys are ignored. An existing unused boolean in
UserDefaults does not enable any functionality; no destructive cleanup or data
migration is needed. Medication/event storage paths and schemas are unchanged.
Compatibility tests cover decoding older settings and medication exports,
preserving supported preferences, and omitting the retired key from new exports.

### 1.2.0 Stabilization: Legacy Reads, Imports and Migration Backups

The October 27 stabilization pass changes no primary database paths, containers,
filenames or model schemas. Bodega appends `.sqlite3`
to engine names; discovered legacy `.sqlite`, `.db` and extensionless files must
therefore be copied with their WAL/SHM sidecars into a disposable reading directory
using that required filename. The original remains available until merge
verification and archival succeed. Corrupt sources throw rather than appearing empty.

**Conflict policy correction:** current same-ID medications and events take
precedence over legacy records. The repaired reader can recover old files that
previous versions ignored; historical legacy-first merging would revert newer
quantities, names, limits, doses, dates and notes during that recovery. Import
missing IDs, preserve whole current records, and retain the archived source for
recovery instead of guessing which individual fields are newer. Existing records
are not removed/reinserted. This changes the historical policy shown in the
incident sections above. It can retain incomplete current metadata; the original
legacy metadata stays archived. Without deletion tombstones, missing-ID recovery
cannot distinguish an orphaned record from an intentional past deletion; this
existing limitation still needs a release decision for affected upgrade fixtures.

Record replacement during JSON import preserves device preferences and backup
bookmarks. Imported settings remain opt-in. Resolve medication identity by exact
ID before any unique-name fallback, include existing medications for merges, and
validate unresolved/ambiguous history references before replacing records.

Migration backup directories retain `pre_migration_` and their timestamp, with a
unique suffix to prevent same-second collisions. Existing backup discovery and
restore paths remain compatible. File-based migration restore is an offline
operation performed before Boutique stores open; it does not refresh live caches.
It rejects empty sources, stages the requested snapshot before retention cleanup,
and requires a successful safety backup before replacing files. The shipping
automatic-backup restore UI uses the separate JSON import path.

Failure/retry and repeated-launch coverage uses disposable directories/defaults,
not permission changes to the shared container. See the [stabilization evidence](testing/1.2.0-data-integrity-stabilization.md).
The October 28 pass routes dose/stock, history changes and JSON imports through
`MedicationPersistenceTransactions`. It keeps the existing databases and adds
`.persistence.lock` plus a version-1 `pending-data-transaction.json` undo journal
in their directory. Cooperating app/widget writers load fresh records under the
same lock. The journal is flushed before writes and removed only after completion.
Ordinary failures restore affected records and exact persisted imported preferences;
interruption or failed rollback retains the journal for recovery before access.
Malformed journals fail closed. Widgets cannot recover app-owned preferences and
show an unavailable state until the app recovers them. Registered defaults and
unrelated preference changes are not captured as persisted import values.

History edits/deletes and Undo adjust compatible stock in the same operation.
Retries with the same event ID cannot deduct twice; Watch messages retain that ID.
No unit conversion is inferred. Existing database paths/schema are unchanged.
Older releases cannot recover this journal: do not downgrade with one pending.
These are process-interruption guarantees, not certification against every device
power-loss/filesystem failure. See [build 310 verification](testing/1.2.0-310-stabilization-verification.md).

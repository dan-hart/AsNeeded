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

**Location**: `AsNeeded/Services/Persistence/DataMigrationManager.swift`

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

            // 4. Merge data (deduplicate by ID, legacy takes precedence)
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
        for item in legacy {
            itemsById[item.id] = item // Legacy takes precedence
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
- [ ] Implement `mergeByID()` logic (legacy takes precedence)
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

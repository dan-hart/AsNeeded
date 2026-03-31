# Storage Safety Rules

**Applies To**: Persistence, migrations, stored settings, HealthKit sync mode, and risky project configuration
**When to Load**: Before touching storage-related code or settings
**Priority**: Must

## Intent

Protect user data and avoid repeating past storage regressions.

## Must

- Read `docs/DATA_STORAGE_GUIDELINES.md` before changing anything under `AsNeeded/Services/Persistence/`.
- Never change storage paths, filenames, or containers without a migration plan.
- Keep migrations non-destructive and idempotent.
- Archive or rename legacy files after successful data-driven migration so the migration does not replay on every launch.
- Use strongly typed keys from `UserDefaultsKeys.swift`.

## High-Scrutiny Files

- `AsNeeded/Constants/StorageConstants.swift`
- `AsNeeded/Services/Persistence/DataStore.swift`
- `AsNeeded/Services/Persistence/DataMigrationManager.swift`
- `AsNeeded/Services/Persistence/StorageHealthChecker.swift`
- `AsNeeded/Services/Persistence/MigrationCoordinator.swift`
- `AsNeeded/UserDefaultsKeys.swift`
- `Info.plist`

## Required Analysis Before Storage Changes

1. Path analysis: does this move or rename stored data?
2. Schema analysis: does this change how existing data decodes?
3. Migration analysis: what happens for existing users?
4. Rollback analysis: what happens if the change fails halfway?
5. Test analysis: how will fresh install, legacy-only, new-only, both, and restart scenarios be verified?

## Verification

- Run relevant unit tests.
- Verify migration behavior across multiple app restarts when storage logic changes.
- Test on a physical device for storage-related changes.

## Avoid

- Flag-only migrations that ignore whether legacy data still exists.
- Replacing user data when merge behavior is required.
- Renaming keys or paths without backward-compatibility reasoning.

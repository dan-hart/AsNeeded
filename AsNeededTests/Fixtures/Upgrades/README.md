# Synthetic upgrade export fixtures, library version 1

These immutable JSON files exercise supported older export shapes through the real import transaction, SQLite reopen, and export APIs in `UpgradeFixtureTests`. All names, identifiers, quantities, notes, and timestamps are invented. They contain no personal history.

These are **synthetic schema examples, not backups captured from historical releases**. `appVersion` deliberately says `synthetic-schema-reference`; the export timestamp is test data, not capture provenance. No claim is made that a particular shipped app produced these bytes.

## Schema provenance

- Repository commit `4b9798e` (October 24, 2025), `AsNeeded/Services/Persistence/DataStore.swift`: `DataExport` contains medication/event arrays, ISO 8601 dates, `appVersion`, optional `dataVersion`, and optional settings. Export writes `dataVersion: "1.0"`.
- The same commit's `AsNeeded/Models/AppSettings.swift` defines the sparse settings keys used here, including the now retired `featureToggleQuickPhrases`. The current synthesized decoder ignores that unknown key. The fixtures omit newer safety profiles and do not prescribe behavior for them.
- Medication, event, dose, and unit wire fields were checked against ANModelKit revision `ee9eb9e1603f1832cace9dea4a5fa07247d5de51`, pinned in `Package.resolved`. This verifies the model decoding contract used by current imports; historical package provenance has **not** been established. Missing `isArchived` is explicitly supported by its current decoder and defaults to `false`.

| File | Contract exercised |
| --- | --- |
| `upgrade-export-v1-no-settings.json` | Version 1.0 export without settings; missing optional medication/event fields |
| `upgrade-export-v1-sparse-settings.json` | Same records with older sparse preferences, medication references/order, and a retired key |
| `upgrade-fixture-manifest.json` | Library version, source references, synthetic provenance, and SHA-256 of each frozen payload |

Both payloads include fixed medication/event/dose IDs, exact second-resolution event/refill dates, tablet and milliliter units, fractional stock and doses, and linked event medication snapshots. Importing historical events must not subtract their doses from stored stock again.

## Preservation rules

1. Do not regenerate or rewrite existing payloads to make a decoder change pass. Add a new uniquely named fixture and manifest entry for a newly supported shape. Preserve the old test case.
2. Hashes pin the committed bytes; changing a hash along with a payload is a reviewable compatibility decision, not an automatic update procedure.
3. Add only synthetic data. Record source commits, schema assumptions, and any unverified historical provenance explicitly. A real historical-release capture requires independent sanitized provenance before it can be labeled as such.
4. Keep JSON in this synchronized test group. Tests load it from the test bundle and deliberately have no source-tree fallback, so missing target resources fail visibly.

## Verification scope

The suite uses unique temporary SQLite directories and private UserDefaults domains; it does not write the app's shared container or normal preferences. It checks repeat replacement and merge semantics separately: repeated merge retains current records with matching IDs and does not duplicate history. It injects failure after preferences have applied (`beforeCommit`), checks rollback, and also leaves an undo journal by failing rollback, then checks recovery on a fresh DataStore instance and a clean retry.

This protects JSON export/import upgrades. It does not establish historical SQLite-format migration compatibility, OS process-termination behavior, physical-device behavior, or compatibility with every released app/package version. Existing migration tests cover the separate legacy database migration path.

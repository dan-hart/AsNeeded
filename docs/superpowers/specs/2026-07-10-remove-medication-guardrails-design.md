# Remove Medication Guardrails Design

**Date:** July 10, 2026

## Goal

Remove the medication dose-safety guardrails feature while preserving the user-configurable low-stock threshold and the unrelated confidence, refill, logging, history, privacy, and accessibility improvements that shipped alongside it.

## Product Boundary

The app will no longer collect, calculate, display, or enforce:

- Minimum hours between doses
- Caution windows
- Saved daily dose limits
- Duplicate-dose windows
- Next-eligible-dose times derived from those values
- “Can take now” claims derived from saved guidance
- Guardrail, caution, warning, or review messaging derived from saved guidance
- Configurable refill lead time

The app will retain:

- A configurable low-stock threshold for each medication
- Low-stock and refill projections based on medication quantity, recent usage, and refill dates
- A fixed internal five-day refill-soon window
- Last-dose summaries
- Quick-log confirmation and undo
- Medication history and trends improvements
- Clinician report refill information
- Privacy and accessibility improvements unrelated to guardrails

## Architecture

### Refill Profile

Replace `MedicationSafetyProfile` with `MedicationRefillProfile`. The new profile contains only an optional `lowStockThreshold`. An empty profile means the default threshold of 10 is used and no per-medication value needs to be stored.

`MedicationRefillProfileStore` becomes the single owner of refill profile persistence. Callers use typed APIs rather than reading raw `UserDefaults` values.

Settings export/import, app reset, clear-all-data behavior, and UserDefaults key allowlists are updated to use the refill-only keys. Archived legacy payloads are excluded from normal settings export because they are recovery data, not active preferences.

### Refill Projection

Replace the mixed-purpose `MedicationDoseGuidanceService` with `MedicationRefillProjectionService`. It retains only the calculations needed for:

- Average daily usage
- Estimated days remaining
- Projected run-out date
- Low-stock state
- Refill-soon state
- Urgent refill state
- Refill status copy

The service uses the saved low-stock threshold when present and otherwise uses 10. Refill-soon calculations use a fixed five-day lead window because refill lead time is no longer configurable.

No service will calculate dose eligibility, daily-limit proximity, caution severity, or duplicate-dose candidates.

### User Interface

Medication editing retains a refill section containing only “Low Stock Threshold.” The “Safety Guardrails” section, dose timing fields, daily limit, duplicate window, refill lead-time field, and explanatory guardrail copy are removed.

Medication rows continue to show last-dose and refill information. Guardrail badges, next-window text, daily-limit text, warning colors, and guardrail accessibility phrases are removed.

Log-dose and quick-log flows always present neutral success confirmation after a successful save. The undo action remains. Logging is never blocked, delayed, or presented as outside saved guidance.

Medication details, trends, clinician reports, widgets, Live Activities, App Intents, and watch payloads retain refill or last-dose information where useful, but remove next-dose eligibility and “can take now” behavior derived from guardrails.

The “Check Next Dose” App Intent is removed because the app no longer owns enough information to make that claim safely. Other intents remain.

### Documentation

README feature descriptions will describe refill awareness and medication history without claiming saved safety guardrails, next-dose guidance, duplicate checks, or daily limits. Historical design and plan documents remain unchanged because they describe prior decisions rather than current product behavior.

## Storage Migration

Introduce a new `medicationRefillProfiles` key and an archive key for the legacy raw profile payload. Migration is non-destructive and runs through `MedicationRefillProfileStore` before profiles are returned.

Migration behavior:

1. If the new refill-profile key exists, it is authoritative.
2. If the new key is absent and the legacy `medicationSafetyProfiles` payload exists, decode only each profile’s `lowStockThreshold`.
3. Persist non-empty refill profiles to the new key.
4. Decode the new payload and verify that every migrated threshold matches the legacy value.
5. Only after verification, copy the original legacy payload to the archive key and remove the active legacy key.
6. If no legacy profile has a custom threshold, archive the legacy payload and record migration completion without creating an empty active profile payload.
7. Mirror the same result to standard and App Group defaults so app and extensions agree.

The archive prevents destructive loss while removing the active legacy key prevents migration from replaying. When both active keys exist, the new refill profile wins and the legacy payload is archived without overwriting the new value.

If standard and App Group defaults contain different active refill profiles, standard defaults are authoritative. The store mirrors that authoritative payload to the App Group after decoding it successfully.

Deleting the last custom threshold removes the new active payload. A separate migration-completed marker prevents the archived legacy value from being restored on a later launch.

## Error Handling

- Invalid legacy data is left untouched and ignored; the app falls back to the default threshold.
- A failed encode or verification leaves the legacy active value in place so migration can be retried safely.
- A failed archive write does not remove the legacy active value.
- Refill projection remains available with defaults when no stored profile can be read.
- No migration path modifies medication or dose-history databases.

## Testing Strategy

Use test-first development for the surviving refill behavior and migration boundary.

Focused tests will cover:

- Custom and default low-stock thresholds
- Average usage and refill projections after the service split
- Legacy-only migration
- New-only storage
- Both keys present, with the new value winning
- Legacy payloads with no custom low-stock threshold
- Migration verification failure
- Migration idempotency across repeated store creation
- Removal of the final custom threshold without resurrection
- Standard/App Group mirroring
- Medication editing loads and saves only the low-stock threshold
- Status summaries contain last-dose and refill information without guardrail language
- Quick-log feedback remains a success state with undo metadata
- Clinician reports use refill profiles

Verification will include focused suites first, then the repository parallel test script, development build, production build, and searches confirming that active product code and current README copy no longer contain guardrail fields or claims. Historical design documents are excluded from that final text check.

The unchanged baseline currently exposes an existing full-suite test-host crash in Boutique/SQLite after hundreds of tests execute in one host. Focused suites will be run in isolation to provide reliable red/green evidence. The full repository script will still be run and its direct `.xcresult` inspected rather than trusting the wrapper’s exit status.

## Success Criteria

- Users cannot configure or encounter dose-safety guardrails anywhere in the product.
- The app, widget, watch app, intents, and Live Activities make no guardrail-derived eligibility claims.
- Existing custom low-stock thresholds survive upgrade.
- Users can still edit the low-stock threshold.
- Refill projections, last-dose status, quick-log undo, history, clinician reports, privacy information, and accessibility behavior continue to work.
- Focused tests and all build targets pass.
- Full-suite results are reported from the `.xcresult`, including any unchanged test-host infrastructure failure.

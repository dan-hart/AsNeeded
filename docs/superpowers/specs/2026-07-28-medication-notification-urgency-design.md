# Per-Medication Notification Urgency

## Context

AsNeeded currently schedules every medication reminder as a Time Sensitive notification. That behavior was introduced in PR #4 so reminders can break through Focus when iOS permits it, but users have no in-app control over which medications warrant that interruption level. The iOS Settings switch is app-wide and may also be unavailable when the signed build lacks the Time Sensitive capability.

The app needs a durable urgency preference for each medication. Urgent reminders use the Time Sensitive interruption level; normal reminders use the default active interruption level. The change must preserve PR #4's deterministic identifiers, duplicate reconciliation, mutation serialization, and delivered-notification acknowledgement.

## Goals

- Let the user choose urgent or normal reminder delivery independently for each medication.
- Apply one medication's preference to all its pending and future reminders.
- Preserve urgent delivery for medications that already have pending reminders when the feature first ships.
- Default medications without an existing preference or reminder to normal delivery.
- Explain when iOS is preventing Time Sensitive delivery.
- Keep notification urgency outside `ANMedicationConcept`.
- Add the implementation to the existing PR #4 branch.

## Non-Goals

- Critical alerts or bypassing the silent switch.
- Per-reminder urgency within one medication.
- A cross-platform reminder model in ANModelKit.
- Changing reminder schedules, notification actions, or dose-log acknowledgement.
- Proving Focus delivery without a correctly signed build and a physical device.

## Architecture

### Preference Store

Add `MedicationNotificationUrgencyStore` in AsNeeded. It owns a UserDefaults dictionary keyed by medication UUID string, with Boolean values:

- `true`: urgent delivery is explicitly enabled.
- `false`: urgent delivery is explicitly disabled.
- Missing entry: no preference has been established.

The key must be declared in `UserDefaultsKeys`. Explicit `false` entries must be retained so startup migration cannot enable urgency again after the user turns it off.

The store exposes operations to:

- Read the optional stored preference for a medication.
- Resolve a medication without a stored preference as normal.
- Save and verify a preference.
- Remove a medication's preference.
- Return and replace the complete dictionary for migration and settings import/export.
- Filter entries against a set of valid medication IDs.

Add a separate device-local migration-completed marker. The marker is not exported, imported, or cleared by an ordinary settings reset. It prevents future normal reminders from being mistaken for reminders that predate this feature.

The preference is an AsNeeded delivery setting, not medication-domain data. `ANMedicationConcept` and ANModelKit remain unchanged. If reminders later become shared cross-platform records, they should receive a separate reminder model instead of adding notification behavior to the medication concept.

### Notification Request Construction

`MedicationReminderRequest.make` receives an explicit urgency value. It sets:

- `.timeSensitive` when urgent.
- `.active` when normal.

Urgency is not part of `MedicationReminderRequest.Identity`. Changing urgency therefore replaces the content of the same canonical request without changing its schedule or identifier.

Reconciliation receives the desired urgency for each medication and canonicalizes both request identity and interruption level. It must no longer upgrade every medication reminder to Time Sensitive unconditionally.

### Notification Manager

`NotificationManager` owns an injected urgency store and uses it for scheduling, migration, reconciliation, and preference changes.

Replace automatic reconciliation launched directly from `AsNeededApp.init()` with an idempotent startup operation invoked from the app root after `MigrationCoordinator` reports completion. Constructing `NotificationManager.shared` may still configure the singleton early, but it must not finalize urgency migration before application persistence is ready.

The startup operation receives an asynchronous, throwing medication-inventory provider. A successful return means persistence loading is complete and the returned ID set is authoritative, including when it is empty for a new user. A thrown error means readiness or loading could not be established; in that case, log the failure, leave the urgency migration marker unset, and do not run medication-scoped reconciliation. Repeated app-root tasks may call startup safely, but only one startup pass runs at a time.

Scheduling reads the medication's resolved preference before constructing a request. If the medication has no stored entry, scheduling first establishes an explicit `false` preference. Existing serialization through the reminder mutation queue remains the only path for pending-reminder mutations.

Add an asynchronous operation that changes urgency for a medication:

1. Snapshot that medication's pending requests.
2. Rebuild each request with the requested interruption level and the same identifier and trigger.
3. Add each replacement through the serialized mutation queue.
4. Persist the preference only after every replacement succeeds.
5. If replacement or persistence fails, re-add the original requests, retain the old preference, and return an error.
6. If rollback also fails, log it; startup reconciliation uses the stored preference to retry convergence.

Changing urgency affects pending and future reminders. Already delivered notifications are not rewritten.

## Migration and Reconciliation

Before normal startup reconciliation, run a one-time migration when the migration-completed marker is absent:

- Await the readiness-gated medication-inventory provider.
- Treat its successfully returned medication IDs as the current authoritative inventory.
- Group pending medication reminders belonging to those current medication IDs.
- If a current medication has pending reminders and no stored entry, assign and persist `true`.
- If a stored entry exists, preserve it, including explicit `false`.
- Exclude stale reminder requests whose medication ID is no longer present.
- Mark migration complete only after the updated preference dictionary is verified.

After migration, and on every later launch, reconcile current medications' pending requests against stored preferences. Missing entries resolve to normal. Rebuild requests while preserving PR #4's add-before-remove ordering, deterministic identifiers, and duplicate cleanup.

If the inventory provider or migration persistence fails, leave the marker unset. A provider failure stops medication-scoped reconciliation because an empty-but-not-loaded inventory must not be treated as authoritative. A preference-persistence failure uses urgent as the effective value for eligible existing reminders during that reconciliation pass so they are not silently downgraded. Log either failure and retry at the next startup.

An ordinary settings reset clears the preference dictionary but preserves the migration marker. Consequently, pending reminders resolve to the normal default during the next reconciliation instead of being re-migrated to urgent. The marker is device-local and is never restored from an export.

Invalid or unrelated notification requests remain untouched.

## User Interface

Add an `Urgent Notifications` toggle to the Reminders card on `MedicationDetailView`. It appears with the existing reminder controls when authorization is `.authorized`, `.provisional`, or `.ephemeral`. The existing permission-request presentation remains responsible for `.notDetermined`, and the disabled-notification presentation remains responsible for `.denied` or unknown states.

Supporting text:

> Can notify you through Focus and Scheduled Summary.

The toggle loads the medication's resolved preference. When changed, it waits for `NotificationManager` to finish updating all pending reminders:

- On success, retain the new value.
- On failure, restore the previous value and show an actionable error.
- Disable repeated changes while an update is in progress.

The notification settings refresh also reads iOS's Time Sensitive setting:

- Enabled: no warning is shown.
- Disabled while the medication preference is urgent: explain that Time Sensitive alerts are disabled in iOS and offer `Open Settings`.
- Not supported while the preference is urgent: explain that urgent delivery is unavailable for the current build or device.

The in-app preference remains enabled when iOS disables Time Sensitive alerts. Pending requests still carry the Time Sensitive level so delivery becomes urgent if the user later enables the system control.

When ordinary notifications are denied, preserve the existing disabled-notification presentation and `Open Settings` action.

## Deletion and Settings Portability

Deleting a medication removes its urgency preference. Cleanup failure is logged but does not restore a medication that was otherwise deleted successfully.

Classify the preference key and migration marker in the repository's key registry. An ordinary reset clears the preference dictionary but skips the migration marker. Include the preference dictionary in settings export/import because it is a user-authored setting. Import must discard entries whose medication IDs do not exist in the imported or current medication set. The migration marker is device-local and must never be exported or imported.

## Error Handling

- Preference updates are best-effort transactional: pending requests and stored state either both move to the new value or the manager attempts to restore the previous state.
- The UI never claims a change succeeded when the manager returned an error.
- Startup migration and reconciliation log privacy-safe failures and retry on a later launch.
- Failure for one medication does not stop reconciliation for other medications.
- No medication names or other health data are added to the preference payload or logs.

## Testing

Use Swift Testing and focused suites.

### Preference Store

- Missing values resolve to normal.
- Explicit `true` and `false` remain distinct from a missing entry.
- Preferences are isolated by medication ID.
- Save, removal, complete replacement, filtering, and persistence verification behave correctly.
- Deletion cleanup removes only the selected medication's entry.

### Request Construction and Reconciliation

- Urgent requests are Time Sensitive.
- Normal requests are active.
- Urgency changes do not change identifiers or triggers.
- Existing requests without preferences migrate to urgent.
- The one-time marker prevents migration from running again.
- Migration considers current medication IDs only.
- Scheduling establishes explicit normal state before adding a first reminder.
- Explicitly normal requests remain active after reconciliation.
- A settings reset preserves the migration marker and makes missing preferences resolve to normal.
- Duplicate and legacy request cleanup still uses canonical identifiers and add-before-remove ordering.

### Notification Manager

- Startup waits for the medication-inventory provider before migration or reconciliation.
- A provider failure leaves the completion marker unset and schedules no medication-scoped reconciliation work.
- An authoritative empty inventory may complete migration for a new user.
- Repeated startup calls are idempotent and serialized.
- New schedules use the stored preference.
- Changing urgency updates every pending reminder for the selected medication and no others.
- Successful updates persist the preference.
- Replacement and persistence failures retain the old preference and attempt rollback.
- Serialized mutations prevent reconciliation from racing with scheduling, cancellation, or urgency changes.

### Settings

- The new key is covered by the key-completeness test.
- Reset removes urgency preferences without removing the migration marker.
- Export/import preserves valid preferences and filters unknown medication IDs.
- Export/import never transfers the migration marker.

No ViewInspector, snapshot, or UI test dependency is added. The UI is covered through the tested store and manager boundaries plus build verification.

## Verification

Run the focused preference-store, medication-request, notification-manager, settings, and deletion tests, followed by a direct Debug build. Do not treat wrapper output as proof if it masks the underlying `xcodebuild` exit status.

Keep these release gates separate:

- Source entitlement exists in `AsNeeded.entitlements`.
- The signed Release application contains `com.apple.developer.usernotifications.time-sensitive`.
- A physical device confirms an urgent medication reminder breaks through Focus while a normal reminder does not.

If signing or device access is unavailable, report those items as unverified rather than as implementation failures or successes.

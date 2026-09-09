# Medication Notification Reliability Design

## Goal

Address user feedback that medication reminders are filtered by Focus and can appear repeatedly after the user logs a dose with the medication-row `+` button.

## Selected Behavior

- Medication reminders use the Time Sensitive interruption level so they can break through Focus and Notification Summary when the user allows Time Sensitive notifications for As Needed.
- Critical alerts are intentionally out of scope because they bypass the mute switch and require Apple approval.
- Scheduling the same logical reminder again replaces the existing request instead of creating a duplicate.
- A successful medication-row quick log acknowledges delivered reminders for that medication.
- Acknowledgement removes only already-delivered notifications. It does not cancel pending daily, weekly, or custom recurring reminders.
- Failed quick logs do not acknowledge notifications.

## Considered Approaches

### Selected: Targeted Notification Coordination

Keep notification behavior in `NotificationManager`, expose small deterministic helpers for content, identifiers, and medication matching, and inject a quick-log acknowledgement closure into `MedicationListViewModel`.

This keeps the persistence layer unchanged, makes the behavior unit-testable, and limits the production diff to notification coordination and the existing quick-log success path.

### Rejected: Cancel All Medication Reminders After Logging

This would stop duplicate alerts, but it would also silently delete the user's future recurring schedule.

### Rejected: Add Notification Side Effects To `DataStore`

Centralizing acknowledgement in persistence would cover more logging paths, but it would couple storage to system notification state and expand a focused bug fix into a higher-risk architectural change.

## Design

### Time Sensitive Delivery

`NotificationManager` will construct reminder content with `UNNotificationInterruptionLevel.timeSensitive`. The app target will declare the Time Sensitive Notifications entitlement. Existing alert, badge, sound, privacy, category, and user-info behavior remains unchanged.

### Stable Reminder Identity

Reminder identifiers will be derived from the medication ID and the trigger's effective calendar components:

- one-time: year, month, day, hour, and minute
- daily: hour and minute
- weekly/custom: weekday, hour, and minute

The identifier will not include seconds or an unrelated date for recurring reminders. `UNUserNotificationCenter.add` replaces a pending request with the same identifier, preventing logically identical schedules from stacking.

Existing releases already have pending reminders with timestamp-based identifiers. To repair those schedules:

- `NotificationManager` will reconcile pending medication reminders during initialization.
- Requests with the same medication ID and effective trigger components will be grouped as one logical reminder.
- Duplicate identifiers in each group will be removed while preserving one pending request, preferring an existing deterministic identifier.
- Scheduling will add the deterministic request successfully before removing matching legacy requests, so an add failure leaves the user's prior reminder intact.

This reconciliation changes only pending notification requests. It does not modify medication data or stored user settings.

### Delivered Reminder Acknowledgement

After quick-log persistence succeeds, `MedicationListViewModel` will ask `NotificationManager` to acknowledge delivered reminders for that medication.

`NotificationManager` will:

1. Fetch delivered notifications.
2. Select requests in the medication-reminder category whose `medicationId` matches the logged medication.
3. Remove those delivered request identifiers.

It will not remove pending notification requests, preserving the next recurrence.

The view model will receive acknowledgement as an injected async closure with a production default. Tests can therefore verify the integration without scheduling real system notifications.

## Error Handling

Notification acknowledgement and post-add legacy cleanup are best effort and nonthrowing. A successfully persisted dose remains successful even if the system has no matching delivered notification. Scheduling errors continue to use the existing reminder configuration error path, and failed scheduling does not remove the prior pending reminder.

## Tests

Use Swift Testing for focused regression coverage:

- reminder content is Time Sensitive
- identical recurring schedules produce the same identifier across different source dates
- distinct schedules produce distinct identifiers
- existing timestamp-identified requests with the same medication and trigger are recognized as duplicates
- pending reconciliation retains one logical reminder and removes only duplicate identifiers
- delivered-request filtering matches only the intended medication-reminder requests
- successful quick logging invokes acknowledgement for the logged medication
- failed quick logging does not invoke acknowledgement
- delivered acknowledgement does not remove pending recurring requests

Run the focused notification and medication-list view-model tests first, then the repository's optimized broader test and development-build scripts.

# As Needed 1.2.0

- Save an optional minimum interval between doses for each medication.
- Save an optional maximum quantity in a rolling 24 hours, using the medication's unit.
- See the next saved dose window directly in medication details.
- Enable a separate next-dose availability alert, alongside existing scheduled reminders.
- Shortcuts use the same saved limits and explicitly explain missing timing information.

Timing is based on saved limits and recorded doses. Follow prescription and care instructions.

- Removed the experimental Private Questions feature from Trends and App Preferences.

## TestFlight verification

1. Upgrade with existing medication/history data and legacy guardrails; verify timing/quantity values and other settings survive two launches.
2. Save an interval alone, a quantity maximum alone, and both. Confirm limits remain optional and are clearable.
3. Log varying quantities and verify the next full saved dose waits until both limits allow it, including across midnight and the exact rolling 24-hour boundary.
4. Enable availability alerts and allow notifications. Confirm one future alert, distinct from scheduled reminders. Opt-out, archive/delete, edit/delete a dose, and change limits; confirm stale alerts are canceled or replaced.
5. Deny notification permission; confirm setup explains how to enable it. Check notification-name privacy in both modes.
6. Verify missing history, missing dose units, and incompatible units produce explanatory states rather than claims of safety.
7. Test backup/export/import and watch logging. Confirm model limits survive and alerts update.
8. On a physical device, confirm notification delivery while the app is backgrounded/terminated and after an upgrade. Device delivery and upgrade behavior require beta testing before public release.

Confirm Trends has no question input/answers and App Preferences has no questions toggle, including on Apple Intelligence-capable devices. Older settings exports must still import while preserving medication data.

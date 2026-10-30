# Background notification logging

The maintainer explicitly authorized background dose logging with visible feedback.

1. Keep notification body taps opening the dose form. Make Log an authenticated background action. Add separate success/history and failure/review categories without a Log action.
2. Prepare migration before writes; if startup is already running or fails, report that the dose was not logged rather than guessing or queuing a later save. Resolve the exact medication and prescribed amount/unit inside the existing transaction. Require a clear guidance assessment.
3. Derive an operation UUID from notification identity and delivery date. Recognize replay before consulting a changed prescription. Capture the logging time inside the transaction so overlapping operations assess all earlier commits.
4. Preserve the existing atomic stock/event save, recording order, reminder acknowledgement, availability reconciliation, and backup effects. No paths, schema, persisted keys, or model changes. Failed commits roll back through the existing journal.
5. Send a quiet confirmation notification only after durable success. Respect notification-name privacy. Scheduling feedback failure cannot turn a committed save into a reported save failure. Confirmation taps open History; failed-action taps open the dose form. No system-overlay toast, unsolicited app foregrounding, or new background Undo UI.
6. Add focused service, replay, transaction race/rollback, feedback, category, and main-thread callback tests. Run the full regression suite, review the final diff, then build and install on the affected phone. Physical background action delivery remains a separate real-device check.

Primary platform references: Apple’s “Declaring your actionable notification types”, “Handling notifications and notification-related actions”, and “Scheduling a notification locally from your app”. iOS supports background actions and local feedback notifications; presentation remains subject to user notification and Focus settings.

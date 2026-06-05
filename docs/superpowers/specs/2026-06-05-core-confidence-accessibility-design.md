# Core Confidence And Accessibility Design

## Goal

Make AsNeeded feel faster, safer, more trustworthy, and more accessible in the core medication-management loop while keeping the first implementation PR reviewable.

## Approved Scope

This PR targets the Core Confidence pass from the product brainstorm:

- Medication row status that surfaces last dose, next eligible window, daily guardrail state, and refill pressure.
- Quick log stays fast. It logs immediately even when saved guidance raises caution or warning, then shows explicit warning feedback with undo.
- Log confirmation becomes more specific, including dose, time, next window, and warning state when applicable.
- Add/edit medication remains one sheet, but the form is reorganized around essentials plus clearer optional safety, refill, and appearance sections.
- Settings gains a top-level Data & Privacy hub that groups local privacy, RxNorm search disclosure, backup/export/import, clinician report, and destructive data actions.
- Detail and Trends gain compact situation-summary information where it clarifies current medication state.
- Accessibility work covers both functional and visual accessibility on touched screens: Medication list, Log Dose, History, Trends, Settings, and Data & Privacy.

Widgets, Watch, Live Activities, and broader App Intent polish are intentionally follow-up work unless a shared helper needs copy consistency.

## Product Behavior

### Medication List Status

Rows should answer the common scan questions without opening details:

- When was this last taken?
- Is another dose inside saved guidance, close to a guardrail, or worth review?
- Is supply/refill pressure relevant?
- What will happen if I quick log?

The status should use text plus symbols or labels, not color alone. The row should retain the existing medication color and quick log affordance.

### Quick Log Feedback

Quick log should preserve speed. When the proposed default dose is logged:

- If saved guidance is clear, show a concise success confirmation.
- If saved guidance returns caution or warning, still log, but show a higher-salience warning confirmation.
- The confirmation should include an Undo action that deletes the just-created event when possible.
- Duplicate taps should remain guarded by the existing operation handling.

### Progressive Add/Edit

The existing `MedicationEditView` remains the architecture. The form should feel progressive by copy and grouping:

- Essentials: medication identity and usual dose.
- Make this safer: minimum interval, caution window, daily limit, duplicate window.
- Track supply: quantity, refill dates, low-stock threshold, refill lead time.
- Personalize: color and symbol.

No storage paths, medication model schema, or migration behavior should change.

### Data & Privacy Hub

Settings should expose a top-level Data & Privacy destination. The hub should communicate the app's privacy posture and route to existing data operations:

- Local-only data summary.
- RxNorm search disclosure: typed medication names may be sent to NIH/NLM for lookup; logs, doses, notes, and personal data are not sent.
- Backup/export/import/clinician report entry points.
- App settings and data clearing entry points.

Where possible, existing data-management logic should remain in `DataManagementView` and its view model rather than being duplicated.

### Situation Summary

Detail and Trends should use a shared summary source where practical so the same medication has consistent status wording across screens.

The summary should stay descriptive. It must not make medication recommendations.

### Accessibility

Functional accessibility:

- Meaningful labels and hints for row status, quick log, warning feedback, chart/heatmap summaries, and privacy actions.
- Accessible actions for interactions that otherwise depend on swipe, long press, or visual-only affordances.
- Clear traits for headings, destructive actions, and primary actions.

Visual accessibility:

- Dynamic Type remains usable on touched screens.
- Critical medication names use no-truncation patterns.
- Warning states do not rely on color alone.
- Reduce Motion and Reduce Transparency should be respected where touched code uses animation or material effects.

## Architecture

Add small pure helpers for status and feedback text so tests can run quickly without UI automation:

- A medication status summarizer that combines medication, events, saved safety profile, and guidance service output.
- A quick-log result summary that converts a logged dose plus assessment into success or warning text and undo metadata.
- A lightweight Data & Privacy row model if the hub needs stable, tested navigation structure.

UI files should consume these helpers and keep layout changes scoped. Existing view models should continue owning persistence operations.

## Testing

Use fast Swift tests that avoid simulator UI automation:

- Status summary returns last-dose, next-window, daily-limit, and refill text.
- Status summary marks caution/warning with non-color text.
- Quick-log result summary uses warning copy when guidance severity is caution or warning.
- Quick-log undo calls the existing delete-event path where possible.
- Data & Privacy hub model exposes required privacy/data sections.
- Accessibility summary strings include medication name and important status.

Then run the smallest relevant targeted tests before broader verification.

## Risks And Safeguards

- Quick log with undo must not create a second logging path that bypasses existing duplicate-operation protections.
- Undo must only remove the event that was just logged, not an older matching event.
- No storage path, key, or migration behavior should change.
- The privacy hub must not overstate privacy: RxNorm search can send typed medication names.
- The accessibility pass should avoid cosmetic churn outside touched screens.

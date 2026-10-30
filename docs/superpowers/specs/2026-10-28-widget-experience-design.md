# AsNeeded widget experience proposal

Status: proceeding under Dan's follow-up instruction to finish all of the above and commit/push the completed 1.2.0 work. Independently reviewed; implementation verification is tracked separately.

## Goal and scope

Make widgets useful for checking medication data at a glance and opening the right place in AsNeeded. Home Screen widgets favor information and review before saving. Lock Screen widgets take a shorter path to the relevant dose form. Opening a read-only screen does not need an extra alert; saving a dose remains an explicit action in the app.

This is the maintainer's explicitly requested widget scope following the 1.2.0 freeze. Keep changes within widgets, their configuration, shared read-only projections and exact app navigation. Existing app screens, persistence transactions, saved medication formats and notification reliability remain the baseline. Live Activities remain removed. No Control Center controls, cloud service or new permission flow is proposed.

## Current verified state

- PR #10 targets develop and is MERGEABLE at `2ae1b75`.
- Existing Home Screen kinds are `MedicationSmallWidget`, `MedicationMediumWidget`, and `MedicationLargeWidget`; Lock Screen kind is `MedicationLockScreenWidget`.
- All four use StaticConfiguration, so users cannot choose their medication per widget.
- Home Screen interactive buttons currently invoke an immediate widget dose save. Lock Screen taps already open a specific medication's dose form.
- Home Screen lists use alphabetic active medications. Single-medication/Lock Screen selection uses the existing next-window selection.
- Current deep links support opening the dose form, History and Trends. Detail destinations and scoped Trends navigation need explicit routing support.
- Both app and widget minimum deployment target are iOS 26.0. Use supported iOS 26 APIs; this work does not raise that target.

## Approaches considered

1. **Polish the current action-oriented widgets.** Lowest change risk, but does not satisfy the requested customization or shift toward useful data.
2. **Focused Medication and Usage widgets (recommended).** Retain existing medication widget kinds, add native per-widget configuration, and offer a separate Usage widget. Each has one clear purpose and predictable navigation.
3. **One dashboard with many modes and action switches.** Flexible but harder to configure and harder to keep readable in small/accessory sizes.

## Proposed family designs

| Surface | Content | Tap destination |
| --- | --- | --- |
| Small Medication | One selected medication, medication symbol/color, last logged dose, and either its next saved window or supply if available. No empty-limit warnings. | Medication detail in the app. |
| Medium Medication | Up to three compact medication rows with concise timing/supply data. A selected-medication configuration uses the width for that medication's details rather than repeating one row. | Each row opens that medication's detail; a clearly labeled Log Dose link opens the review form/chooser. |
| Large Medication | More medication rows and relevant supply/refill context, with space used for information rather than enlarged controls. Reduce row count as text size grows. | Matching detail or dose review form. |
| Usage — small/medium/large | A selected medication's logged quantity over the last seven complete local-calendar days, ending yesterday. Small: total and compact seven-day bars; medium: readable bars and day labels; large: the same period with more context and comparison with the preceding seven complete days when meaningful. | Trends for that same medication and period when quantity data is complete; History for explicitly labeled incomplete-data summaries. |
| Lock Screen circular | Medication symbol and concise timing or logging glyph; no fabricated safety/progress ring when limits are absent. | Selected medication's dose form directly. |
| Lock Screen rectangular | Selected medication, latest recorded dose and next saved window when configured. | Selected medication's dose form directly. |
| Lock Screen inline | A short medication/timing summary that fits the native line. | Selected medication's dose form directly. |

Medication names remain the priority. Prefer omitting secondary facts or fewer rows over shrinking important names into unreadable text. Use the app's existing typeface and adaptive medication/app colors where appropriate. In tinted, clear and vibrant modes, information must remain distinguishable through text, symbols and hierarchy rather than color alone. Respect standard widget margins and removable backgrounds.

## Customization

Use native Edit Widget configuration, not a new app settings screen:

- **Medication:** choose a medication or Automatic. For overview widgets, the default shows all active medications up to the layout's capacity; choosing one focuses that medication. Automatic single-medication selection retains existing next-window behavior and does not imply a recommendation to take medication.
- **Show names:** allow names to be hidden per widget. Default preserves existing name visibility; sensitive content also honors the system's locked/Always On privacy treatment.
- **Usage:** choose a medication and show/hide its name. The seven-complete-day period is deliberately fixed and clearly labeled, keeping this first version's editor small and calculations consistent.

Multiple instances can show different medications. Resolve stored entity choices by stable medication UUID. If the chosen medication is archived, deleted or unavailable, show a neutral unavailable state and open the app; never silently select a different medication.

## Interaction contract

- Home Screen taps never create, delete or alter a dose. Medication content opens detail; the explicit Log Dose link opens the existing form with amount/time visible and a Save action.
- Lock Screen taps open that medication's form immediately, skipping the detail page. The form's Save action is the confirmation; no silent dose writes are proposed.
- Read-only navigation does not display a redundant confirmation alert.
- Update the existing Home Screen LogDoseWidgetIntent compatibility path as well as the new links: cached pre-upgrade button archives must open the dose form rather than silently saving. Keep unrelated Shortcuts and notification actions unchanged. Retain the tested atomic save/reconciliation services unless proven unused; do not remove regression coverage merely because the visible widgets become read-only links.
- Validate each incoming destination and medication UUID against current active records after app startup. Handle cold and warm launch, existing sheets and rapid repeated taps without duplicate presentation or saving.
- Usage navigation carries the medication and seven-day scope into Trends without saving an unrelated global preference or selecting the last-logged medication instead.

## Data, timing and privacy

- Use the existing App Group transaction reader for a consistent committed medication/event snapshot. The widget view only renders an immutable projection; it does not access live app singletons or perform disk/network work.
- Reuse the same model-aware availability semantics as the app. No limits means omit timing guidance. No history and indeterminate units remain unknown; do not display medical clearance or a recommendation.
- Usage quantity charts use the same preferred-unit selection, quantity aggregation and complete-day boundaries as app Trends. Do not sum quantities from different drugs/units. If incompatible units or missing amounts prevent a complete quantity summary, replace the quantity chart/comparison with a clearly labeled logged-dose count for that period and a Review History link scoped to that medication. This incomplete-data state opens History, not a different-measure Trends chart. Do not introduce a new count mode to app Trends or compare counts with quantities.
- Use complete-day buckets with local-calendar and daylight-saving boundaries consistent with the app's Trends. Compare like periods; no adherence scores, goals or encouragement to take more doses.
- Generate timeline entries for relevant boundaries such as a known saved window and local midnight, plus bounded fallback reloads. Ask WidgetCenter to reload after committed app changes. Do not depend on exact reload times or frequent polling for correctness; the app always rereads before saving.
- Provide real empty/unavailable states for installed widgets and synthetic populated samples only for gallery/preview/placeholder contexts. Storage failures must not be disguised as an empty medication list or known eligibility.
- Mark names and medication-specific history/quantity as privacy sensitive and respect the user's per-widget name choice in visible and accessibility text. Do not persist the session-only in-app Demo Mode to make widgets work.

## Implementation boundaries and continuity

- Preserve the existing widget kind identifiers when moving their providers to AppIntentConfiguration, with sensible defaults for existing installations. Static-to-configurable upgrade behavior is a verification gate, not an assumption.
- Prefer a small shared projection/configuration/route layer plus family-specific views. Reuse existing app components/conventions without loading whole app view models into the extension.
- Add only the new Usage kind. Do not remove existing widget kinds or require users to re-add them as the default upgrade path.
- Extend the app router only for exact detail/Trends/dose-form destinations and transient scope. Keep atomic dose/stock saves and Undo unchanged.
- Review the external skill as guidance, not executable setup. Its blanket App Intent process claims and iOS 27 examples must not override the actual target membership, SDK availability, or this repository's tested ownership model.

## Verification before claiming completion

Unit tests:
- Configuration/entity resolution: active, archived, missing, renamed and reordered medications; no fallback from an explicit unavailable selection.
- Navigation: widget taps, including cached legacy button intents, never mutate records; exact selected medication/period reaches detail, form or Trends; incomplete-quantity summaries route to scoped History; invalid URLs and duplicate requests are safe.
- Projection: optional fields, no history/limits, exact availability boundaries, indeterminate units, privacy labels, empty/unreadable storage, long names and fractional quantities.
- Usage: seven complete days, zero days, DST/time-zone changes, units/missing amounts and preceding-period comparisons.
- Timelines: upcoming boundaries, midnight transitions, and no stale assertion of clearance.
- Run all existing 898 iOS tests, relevant watch checks and security/configuration checks after integration.

Visual/manual evidence using synthetic data:
- Small, medium and large Medication/Usage widgets; inline, circular and rectangular Lock Screen widgets.
- Light/dark, tinted/clear/vibrant, large text, Increase Contrast, redaction, long names, no history and error states.
- Correct gallery samples and native Edit Widget controls; two instances with different selections.
- Existing installed widgets survive upgrade from current static configurations.
- Cold/warm app navigation, locked-device authentication, explicit Save/Undo and widget refresh after app edits.
- Capture previews/screenshots and record device/runtime/build. Simulator checks do not substitute for final physical Lock Screen/Always On validation.

## Reviewed references

- [Widgets Agent Skill v1.2](https://github.com/n0an/Widgets-Agent-Skill/blob/06567e152df00df1db50a2935bbe62fda9e27c19/widgets/SKILL.md), MIT, author Anton Novoselov. Reviewed configuration, design/gallery, Lock Screen and navigation references; selected for its focused WidgetKit coverage. Read as reference material; no installer or global skill setup executed.
- [Alternative reviewed: swift-ios-skills WidgetKit](https://github.com/dpearson2699/swift-ios-skills/blob/main/skills/widgetkit/SKILL.md). Useful broader implementation checklist; repository rules still govern examples and code style.
- [Apple: Widgets HIG](https://developer.apple.com/design/human-interface-guidelines/widgets): content purpose, family-specific density, personalization, rendering and navigation.
- [Apple: Making a configurable widget](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget) and [AppIntentConfiguration](https://developer.apple.com/documentation/widgetkit/appintentconfiguration): native user-editable widget configuration.
- [Apple: Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension): placeholders and system privacy treatment.

Spec review corrected a quantity/count mismatch with app Trends by defining a separate, explicitly labeled History destination for incomplete quantities, preserving the current Trends behavior. Cached legacy interactive-button compatibility is also an explicit upgrade requirement. No app code or widget behavior has been changed by this proposal.

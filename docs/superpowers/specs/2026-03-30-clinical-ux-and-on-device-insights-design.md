# Calm Clinical UX And On-Device Insights Design

## Goal

Deliver a coordinated product pass that improves medication safety guardrails, richer post-dose capture, refill intelligence, widgets and watch usefulness, backup and export trust, and the overall calm clinical UX, while adding an opt-in on-device Trends question experience that never sends user data off the device.

## Product Direction

The app should feel calmer, clearer, and more trustworthy for people managing their own medications. The redesign should favor clean hierarchy, strong readability, larger touch targets, and explicit safety context over decorative visual flourishes. The new Trends question experience should feel like a private, local analysis tool, not a broad-purpose assistant.

## Core Constraints

- Keep the repository agent-agnostic and open-source safe.
- Do not change storage locations or shared package schemas for this work.
- Hide the Trends question feature completely on devices where the on-device language model is unavailable.
- Make the Trends question feature opt-in in settings.
- Never use the word `AI` in user-facing copy for the Trends question feature.
- Keep generated answers descriptive and interpretive only; no medication recommendations.
- Show a persistent caution note under answers and provide a quick link to medical disclaimers.

## Architecture

### 1. Medication Safety And Refill Guidance

Add a local, typed medication safety profile keyed by medication ID. This profile stores optional per-medication rules such as minimum hours between doses, a longer caution window, a daily maximum amount, a duplicate-log window, a low-stock threshold, and refill lead days. The profile lives in `UserDefaults` so the existing medication model and shared package stay stable.

A pure guidance engine computes:

- next eligible dose time
- duplicate-log warnings
- daily-limit proximity
- refill preparation state
- low-stock state
- projected run-out date

This logic is shared by iPhone views, widgets, watch data, and intents.

### 2. Structured Post-Dose Capture

Add structured reflection fields to dose logging:

- reason
- symptom severity before
- symptom severity after
- effectiveness
- side effects
- freeform note

These details are encoded into the existing event note field using a versioned metadata wrapper so exports, backups, and imports remain backward-compatible. The app decodes that metadata for display and editing while preserving older plain-text notes.

### 3. Trends Redesign

The Trends screen keeps the current medication selection and charting controls, but gains:

- stronger metric hierarchy
- clinically worded alert banners
- a pattern summary card
- clearer refill and run-out messaging
- integrated question card for the selected medication

The question card uses the selected medication context and recent logged data to answer freeform questions locally on device. Example prompts are visible before a user asks anything. If the feature is disabled or unavailable, the card is not shown.

### 4. On-Device Questions

Add a service that wraps Apple Foundation Models behind a small app-facing API. The service:

- checks runtime availability
- builds a compact local dataset summary for the selected medication
- creates strict instructions that limit output to the provided data
- asks for concise answers plus notable patterns and limitations
- returns a structured answer object to the Trends UI

The UI copy must repeatedly reinforce:

- data never leaves the device
- processing happens on device
- answers may be incorrect

### 5. Ambient Surfaces

Widgets, intents, and the watch app should stop relying on the hardcoded four-hour fallback. They should use the shared guidance engine so “available now,” refill risk, and low-stock states line up across surfaces. A Live Activity should surface the next medication status and update after dose logging or meaningful data changes.

### 6. Trust, Recovery, And Sharing

Data Management should become a clearer trust hub:

- stronger automatic backup status framing
- recovery scan entry point using the existing recovery manager
- clinician-friendly summary export

The report export should favor readable text/markdown that is easy to share with a clinician and safe to generate from current local data.

## Testing Strategy

Prioritize high automated coverage for the new logic layers:

- safety profile storage
- dose guidance engine
- metadata codec for structured dose reflections
- Trends question availability and prompt-building helpers
- Trends pattern summaries
- report generation
- settings export/import of the new preferences
- widget and watch data shaping helpers

UI work should stay thin on top of tested logic. Existing tests should be extended where behavior changes.

## Risks And Safeguards

- `UserDefaultsKeys.swift` is a dangerous settings file. New keys must be typed, added to reset/export behavior intentionally, and covered by settings tests.
- Structured note metadata must preserve old notes, survive export/import unchanged, and gracefully decode partial or malformed payloads.
- Foundation Models integration must be optional, availability-gated, and safe to compile on the current deployment target without changing app behavior on unsupported devices.
- Widgets, watch, and intents must all use the same guidance rules to avoid contradictory “take now” states.

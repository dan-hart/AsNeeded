# 1.2.0 release QA fixes — October 29, 2026

Candidate: **1.2.0 (319)** on `task/v1.2.0`, based on pushed notification work at `867d023`. Work began only after that checkout was clean and pushed. Implementation used the original checkout; no additional implementation worktree was used.

## Corrected behavior

- Row holds log the chosen active medication even before any history exists or when another medication was logged last. Floating quick-log targeting remains separate; archived rows cannot write doses.
- Settings uses stack navigation, preventing a blank iPad detail area. Privacy and backup scrolling uses the actual viewport rather than the enclosing container width.
- Redacting medication names also omits recent medication searches from the exported settings copy. Saved preferences remain unchanged.
- Refill projection safely handles huge, nonfinite and unsupported date calculations. Stock entry rejects invalid, negative and nonfinite values while retaining optional, zero and fractional quantities.
- Recovery totals describe distinct historical source copies, exclude the current store, and make potential record overlap explicit. Storage paths, schema, settings keys and transaction ownership are unchanged.
- Scheduled notification names recover after privacy off/on changes and refresh after a medication rename. A controlled A → B → A race has regression coverage. Schedule identity, triggers, urgency and replacement-failure recovery are preserved.
- Cold medication intents and entity queries await persistence and read a consistent snapshot. Daily usage avoids unsafe numeric conversion.
- Support prompts require established usage: at least three launches and three past doses across two calendar days. Settings support remains available.
- Medication form copy is shorter. Production RevenueCat logging uses warning level. App source compiler warnings and stale minimum-OS documentation are corrected.
- App and widget required-reason manifests cover their actual APIs. Policy and store copy explain RxNorm typing requests, RevenueCat purchase data, paired Watch transfers, optional subscriptions, exports and cloud-backed backup folders.

The existing authenticated background notification Log action and private confirmation behavior are preserved.

## Verification

| Check | Result |
| --- | --- |
| Pushed baseline | 940 tests passed |
| Final complete test plan | **967 tests passed, 0 failed, 0 skipped**; 1,056 runs including dynamic cases; no runtime warnings |
| Test formatter | 0 errors, 0 compiler warnings, 0 linker errors |
| Regression development | Reproduced row/archive, export, stock/refill, recovery, privacy-name, cold-intent and rename defects before their fixes |
| Independent review | Data correctness, storage boundaries, interactions, privacy/copy, notifications and race fix reviewed; no remaining actionable findings |
| Release simulator build | Passed with normal Xcode signing and simulated App Group entitlements |
| Device Release archive/export | Passed; distribution signature verification passed |
| Shipping bundle metadata | App, widget and Watch all 1.2.0 (319); existing iOS/watchOS 26 minimum preserved |
| Artifact privacy inspection | App/widget manifests present; RevenueCat manifest includes unlinked purchase history |
| Signing profiles | Exact app/widget/Watch identifiers; distribution profiles expire October 28, 2027; get-task-allow false |
| Canonical store metadata | Validation passed with no errors or warnings |

Final suite: `Test-AsNeeded-2026.10.29_11-25-56--0500.xcresult`. Logs and signed artifacts remain outside Git. The archive emitted Apple's metadata-extraction notice for a target without App Intents; no app source warnings remained.

Run the suite with `TEST_DESTINATION` set to an available iOS simulator and `TEST_WORKERS=1 ./scripts/test-parallel.sh`.

## Manual Release smoke and UI testing

Synthetic fixtures only, iOS 26.5: iPhone SE (375-point width), iPhone 17, and iPad mini. No automated UI/snapshot test target was added.

- First-ever row hold, another medication's row hold, tap-to-open without saving, movement cancellation and Undo passed. History confirmed the intended record counts and targets.
- Signed simulator updates and cold launches retained synthetic records. A backdated 0.5-tablet dose, its edited note, date and 19.5-tablet stock persisted after relaunch. Undo restored the preceding stock state.
- Negative stock disabled Save with an explanation; correcting it to 20 enabled saving.
- iPad Settings opened with content. Data & Privacy fit portrait at the largest accessibility text; Automatic Backup fit portrait and landscape at that size in dark mode. Long medication names and the compact medication form were inspected. iPhone 17 large-text Settings remained within the viewport.
- A generated JSON export with names redacted and settings included retained settings, omitted recent searches, contained redaction markers and contained neither synthetic medication name.
- Early-use support banners were absent; eligibility boundaries have focused tests and Settings retains its support route.

An unsigned simulator experiment could not access the App Group. Final UI checks used the normally signed Release build; simulator resets or those signing experiments are not evidence of a live-version upgrade pass.

## Store preparation

- Corrected the editable draft from 1.1.3 to **1.2.0**, retaining manual release.
- Applied accurate description, promotional text, release notes and keyword cleanup; no locale deletions.
- Completed the missing social-media age-rating answers without changing the medical/health classification.
- Published the reviewed privacy policy at the existing `develop/PRIVACY.md` URL; served repository content matched the local SHA-256.
- Uploaded the signed 319 IPA with explicit upgrade, persistence, logging, backup/import, notification, Watch/widget, accessibility and purchase test instructions. Processing/attachment verification is pending below.

No public review submission or release was performed. No tester audience was changed.

## Remaining release gates

- Apple web sign-in is required to verify App Privacy publication (including RevenueCat Purchases disclosure), active agreements and first-subscription attachment. The cached session is expired; the browser handoff remains at sign-in.
- A physical upgrade from the live app must preserve real records and settings. Repeat authenticated notification Log and locked-device delivery, permission/privacy changes, paired Watch/widget behavior, cold Siri execution, VoiceOver and StoreKit purchase/restore flows on devices.
- Critical Alerts entitlement approval remains pending; ordinary/time-sensitive reminders are separate.
- Optional subscription promotional images remain recommendations, not submission blockers unless those promotions are used.

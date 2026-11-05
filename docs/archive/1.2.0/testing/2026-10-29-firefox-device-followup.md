# Firefox and physical-device release QA follow-up

Latest checkpoint: [final SE QA and submission checklist](2026-10-29-final-se-qa-and-submission-checklist.md) records the additional fractional-edit/cleanup checks, refreshed Active agreements and exact remaining hands-on steps.

This continues [the release QA fixes](2026-10-29-release-qa-fixes.md). The maintainer selected the physical iPhone SE and confirmed its records are test fixtures. Build 321 supersedes the 319/320 candidates because physical testing found another editor defect.

## Privacy publication

Firefox provided an authenticated App Store Connect session. The published label incorrectly declared Data Not Collected. It now declares Purchase History and Search History, both used for Analytics and App Functionality, unlinked to identity and not used for tracking. Publication was verified in the App Privacy preview. The app manifest now carries the same collection declarations alongside the existing required-reason API entries; the third-party SDK manifest remains intact.

[RevenueCat's guidance](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy) requires purchase history with both purposes. Source review found anonymous SDK configuration, with no custom identity, customer attributes, advertising identifier or analytics-SDK integration calls.

Search History disclosure is based on [NLM's published logging policy](https://www.nlm.nih.gov/web_policies.html#privacy_security) and historical NLM API-log analysis. This is a defensible disclosure rather than a claim of current API-specific retention confirmation: NLM's current public policy does not specify a separate retention period for RxNorm API queries. Native API requests do not execute NLM website analytics scripts. Saved medication history is not transmitted by search. The public policy now explains this distinction and support-purchase analytics.

## Account and commerce checks

- Accepted the updated Apple Developer Program License Agreement only after explicit maintainer approval. Apple returned to the account page with the updated-agreement warning removed and acceptance recorded October 29, 2026.
- A separate new Paid Applications Agreement is available. The maintainer chose to review and accept it personally; it was left unchecked/open and was not accepted by this work.
- All three existing support subscriptions are APPROVED. This is not a first-subscription submission requiring attachment of new products.
- The physical Support screen loaded all six products with localized prices, renewal/cancellation language, Restore Purchases, and policy/EULA links. No purchase or restore transaction was attempted.
- Business displays missing banking-information warnings that may delay payments. No banking information was entered or changed. Apple also requests a regulated-medical-device declaration by early 2027; classification requires an owner decision, not an inferred code classification.

## Backup and physical upgrades

Device: iPhone SE, iOS 26.7.2, starting at development build 317. The development-signed Release archive was used for app inspection; the distribution-signed IPA was independently verified for App Store preparation. No signing resources were created or revoked.

Before installation, app and group file-service copies were independently retrieved and hashed twice. Because those copies did not expose the expected active records, they were not treated as sufficient coverage. An in-app unredacted export including settings was then retrieved twice, with matching bytes and SHA-256. It contained 2 medications, 988 unique events and settings. Backups, raw fixtures, device identifiers, logs and screenshots remain private outside Git.

Upgrades 317 → 319 → 320 used no uninstall, reset or import. Full exported medication objects, all 988 event objects and the entire exported settings object exactly matched the original backup after each upgrade and test-entry cleanup. Automatic Backup remained Active. Default-dose logging added one event and reduced stock by the correct amount; deleting only that new synthetic entry restored the original stock and records.

## History editor defect and correction

Physical History displayed a saved milligram dose, but its first Edit Entry presentation selected Unit. The sheet was cancelled without saving. An independent simulator reproduction opened a saved half-tablet entry as 1 Unit. A separate quarter-tablet reproduction displayed 0.2 instead of 0.25.

The existing editor is now a private child view that initializes its local date, amount and unit directly from the exact sheet event. Formatting uses the existing amount formatter. Save/Delete keep the existing view-model mutation owner, error behavior and stock adjustment. Cancel/discard writes nothing. Unchanged Save dismisses without rewriting the event or regenerating its nested dose identifier.

Simulator verification passed first opening a half-tablet entry, switching to a quarter-tablet entry on another date, editing and discarding, reopening, and unchanged Save. The final no-op comparison found every medication, event, nested dose ID, order and exported setting exactly unchanged. Independent code review found no blocker. Thirty focused History/formatting tests passed. The final complete plan after the no-op safeguard passed **967 tests, 0 failed, 0 skipped**, with 1,056 dynamic runs and no runtime warnings (`Test-AsNeeded-2026.10.29_12-34-03--0500.xcresult`). Final candidate and physical regression results follow.

## Final 321 evidence

- Shipping source: `09d3a47`, pushed to `task/v1.2.0` after staged safety and secret checks passed.
- Final signed Release archive and export passed; distribution signature verification passed. The app, widget and Watch all report 1.2.0 (321), and the collected-data manifest matches the published label. Purchase configuration resolved without exposing the key.
- IPA SHA-256: `2dbdf80d3dbbaee652a554ab78036911d2fbf64be9d6479693c387f38aa82189`.
- Physical SE 320 → 321 passed. First opening, cancel/reopen and switching between original 1 mg and 3 mg entries retained the correct amount, milligram unit and historical date.
- After unchanged Save and a cold launch, every medication and event, nested dose ID, record order and exported setting exactly matched the original 317 backup. The entire export excluding exportDate was equal. Stock and Automatic Backup Active remained intact; no test entry remains.
- The final iPad editor was visually inspected with a long medication name in expanded portrait and landscape. Controls remained usable and content fit the sheet; no data was changed.
- Apple processed build 321 (`cc18432e-a533-42f6-ab23-007d98c6ecfc`) as VALID / APP_STORE_ELIGIBLE. Readback confirmed that exact build is attached to the 1.2.0 draft, still PREPARE_FOR_SUBMISSION with MANUAL release.
- Final validation against the exact exported IPA, including required iPad screenshots and public metadata URLs, returned **0 errors and 0 blockers**. The three warnings concern optional subscription promotional images. The API's privacy-publication information item is covered by the independent Firefox publication check above.
- Both automatic Xcode 26.4.1 clean-clone builds passed for shipping source `09d3a47`: the push build with the configured purchase key and the pull-request build without a key. Gitleaks, TruffleHog and custom secret-pattern checks also passed.
- Build-specific What to Test notes cover the editor corrections, upgrade/data preservation, dose/Undo, notification delivery/privacy, backups/import, system surfaces, accessibility and commerce. Internal state is IN_BETA_TESTING; the existing all-builds internal group has access. External state is READY_FOR_BETA_SUBMISSION, with no external beta submission or new tester audience created.

## Remaining verification boundaries

- A live 1.1.2 → 1.2.0 physical upgrade has not been tested: the SE started at 317.
- Physical Undo is unverified. Its 4-second toast can expire while the experimental physical accessibility channel traverses controls. Simulator and service coverage passed; a dispatched late physical activation was not reported as either a pass or an app defect.
- Locked/authenticated notification actions and delivery, Siri execution, system widgets, a paired physical Watch, spoken VoiceOver and purchase/restore transactions remain manual checks. The physical channel cannot operate system apps, hardware gestures, typing, swipes or holds.
- Critical Alerts entitlement approval remains pending; ordinary/time-sensitive reminders are separate.
- No public review submission, release, new tester audience, purchase or banking change was performed.

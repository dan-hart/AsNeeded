# Final SE QA and submission checklist — October 29, 2026

Build: **1.2.0 (321)**. Shipping source remains `09d3a47`; this follow-up changes documentation only. This continues the [release QA fixes](2026-10-29-release-qa-fixes.md) and [Firefox/device follow-up](2026-10-29-firefox-device-followup.md).

**Assessment:** No new product defect was established in the additional SE checks. Public-API submission checks have no blockers, but the hands-on release checks below remain unsigned. API validation and development-signed device inspection do not establish complete public-release readiness.

## Additional physical SE results

The confirmed fixture iPhone SE runs iOS 26.7.2 and development-signed Release build 321. No reinstall, downgrade, reset, import, original-record edit, purchase, permission change or signing-resource change was performed.

| Scenario | Result |
| --- | --- |
| Fresh pre-test backup | Two independently retrieved copies of a fresh full JSON export matched byte for byte. Every field except exportDate matched the original build-317 backup: 2 medications, 988 events and exported settings. |
| Normal logging | A single temporary 1 mg entry appeared in History; stock changed from 252 to 251 mg. |
| Fractional History edit | Changed only that temporary entry to 1.5 mg using the existing stepper. Save persisted 1.5 mg; stock became 250.5 mg. Reopening retained 1.5 MILLIGRAM. |
| History deletion | Deleted only that exact temporary event through Delete Entry. It disappeared from History. |
| Relaunch and final preservation | Cold-launched, generated a full export with settings, and retrieved two matching copies. All medication/event objects, nested dose identifiers, array order and exported settings exactly matched both the pre-test export and original 317 backup. Stock returned to 252 mg; 2 medications/988 events and Automatic Backup Active remained. No QA event remains. |
| Small-screen Trends | Visually inspected the physical SE screenshot in dark mode. The 30-day chart rendered, labeled its complete-day interval through October 28, and exposed View History and range/filter controls. This is a rendered-screen check, not spoken assistive-operation coverage. |
| Available crash inventory | The device file service returned zero matching AsNeeded crash-report files. This is not proof that no crash or performance problem can occur. |
| Physical Undo | **Unverified.** Even the supported fast accessibility read took 6.783 seconds after logging; the ensuing selector lookup finished at 11.911 seconds and found no Undo log control. The toast had expired. No Undo activation was dispatched, so this is a tooling limit rather than an established app defect. Simulator/service coverage remains the prior passing evidence. |

The app was cold-launched again and left on Settings. Private backups, raw UI dumps, device identifiers and screenshots remain outside Git with owner-only directory access.

## Refreshed store/account checks

- Exact build 321 remains the prepared candidate. IPA-based validation with URL and required-iPad-screenshot checks returned **0 errors, 0 blockers**. The only three warnings concern optional subscription promotional images.
- Review doctor returned **NOT_SUBMITTED**, review details configured, and **0 blockers**. The version remains PREPARE_FOR_SUBMISSION with MANUAL release.
- All three tip products validate with zero errors/warnings/blockers. All three support subscriptions validate with zero errors/blockers and the same optional-image warnings.
- Firefox now shows both **Paid Apps Agreement and Free Apps Agreement Active**, with no updated-agreement notice. The maintainer completed the separate commercial agreement; this QA work did not accept it.
- App Privacy remains published with unlinked Purchase History and Search History, both for Analytics and App Functionality.
- App Information requests the owner's regulated-medical-device declaration **by early 2027**. No classification was inferred or submitted. The observed page does not identify this as a current version-submission blocker.
- Business still warns that missing banking user information and account-holder address/type may delay payments. No financial information was entered or changed.

No public submission, external beta submission or tester-audience change was performed.

## Hands-on checks before release sign-off

Run these on the exact **TestFlight 1.2.0 (321)** candidate where possible. Record the device, build, expected/actual result and any discrepancy. Stop and fix any incorrect dose, unit, stock, lost/duplicate record, crash or inaccessible core action before submitting.

1. **Public-version upgrade and backup/restore.** On a spare test device, install the current App Store 1.1.2, create synthetic medications/history including a fractional/backdated dose, note, stock and changed preferences, then export with settings. Install TestFlight 321 over it without deleting the app. Compare those records/settings after two cold launches. Separately restore the JSON on a disposable fixture installation and verify records/settings again. Do not downgrade or erase the data-bearing SE to manufacture this test. The SE's verified 317-to-321 development upgrades do not replace this check.
2. **Touch interaction and Undo on the SE.** Tap Log to open the form; cancel and confirm no new event. Hold a medication's Log control and immediately tap Undo log. Confirm exactly one event is removed and stock is restored. Try scrolling across a Log control and confirm it does not log accidentally. Automation cannot complete the physical hold/scroll or four-second Undo interaction.
3. **Notification delivery, permissions and actions.** Use fixture reminders due in the next few minutes. Test foreground/background, terminated and locked states; ordinary and enabled Time Sensitive delivery; permission denial then re-enabling; names off/on and medication renaming. Confirm delivery content matches the privacy setting. Explicit notification **Log** requires authentication and records exactly one default dose only when saved guidance permits; verify History/stock and retry deduplication. A blocked attempt must report Dose not logged and Review Dose must open the correct form. Body taps only open the form; Skip must not write a dose or remove the recurring schedule. Clean up fixture reminders and records afterward.
4. **System surfaces and paired Watch.** With the app initially terminated, run medication-list/refill/daily-usage Siri shortcuts. Tap both Home and Lock Screen widgets and confirm the displayed medication's form opens without an unsolicited save. Log on the paired Watch and verify exactly one matching phone event/stock update, including disconnect/reconnect behavior. These features are advertised in the current description; their device behavior remains a sign-off gap.
5. **Spoken accessibility.** Turn on VoiceOver and complete medication selection, dose amount/unit, Save/Cancel, History edit/delete and Settings navigation. Confirm reading/focus order, meaningful labels, selected units and reachable actions. Check largest text and the chosen font with long names. Existing AX outlines and simulator large-text screenshots do not replace this hands-on check.
6. **StoreKit transactions in TestFlight/sandbox.** Complete one tip and one support subscription, cancel another purchase sheet, restore the active subscription and verify cancellation/expiry behavior. Confirm success/cancel/error feedback, no stuck loading or duplicate transactions, and that all medication features remain free. TestFlight downloads automatically use Apple's sandbox; use the [current Apple instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/) for additional sandbox controls. Do not use a live App Store purchase as the test. Product loading and metadata approval are already verified; transactions are not.

## Owner administration and final submission

- Resolve the banking warnings for reliable payouts; the agreements themselves are now Active.
- Make the regulated-medical-device classification and complete App Information's declaration by Apple's stated early-2027 deadline. This is an owner/legal classification, not an automated code inference.
- Optional promotional images are needed only if using the relevant subscription promotion features; their absence is currently a warning, not a blocker.
- Critical Alerts approval remains pending. This candidate implements ordinary/Time Sensitive reminders, not Critical Alerts; no new critical entitlement or promise is required for build 321.
- After the outstanding hands-on results are recorded and acceptable, open [the app in App Store Connect](https://appstoreconnect.apple.com/apps/6714469235/distribution/ios/version/inflight), confirm **1.2.0 / build 321**, review the listing/review notes, and keep **Manual release**. Use **Add for Review**, review the submission, then **Submit for Review**. Apple documents these separate steps in [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/). Approval will still require a later manual release action.

The unit suite and both clean-clone source builds already passed; there is no new code change or required rebuild in this QA follow-up.

# Security and Privacy

Load for logging, export/import, networking, permissions, dependencies, signing, release artifacts, and security review. The root prohibition on committing private data always applies.

- Use synthetic medication fixtures. Keep real names/history, feedback emails, tester contact details, screenshots, device identifiers, and raw logs out of commits and public issue/PR text. Review generated artifacts as well as source diffs.
- Log technical state and privacy-safe error categories, not medication names, private payloads, credentials, or complete sensitive URLs. Preserve existing notification-name privacy settings in new notification types and replacements.
- Store secrets in appropriate platform secure storage or the existing credential provider. Typed UserDefaults keys are for ordinary preferences, not authentication secrets. Do not move stored settings or data without storage-safety analysis.
- Request only the permissions needed for the feature and handle denial without inventing success. Installing a tool or enabling new device capabilities requires task authorization; skill availability alone grants none.
- Keep signing keys, profile files, archives, IPAs, debug symbols, environment dumps, and distribution logs outside Git. Avoid credential-bearing command arguments and shell tracing. Do not print credentials, private keys, or upload capabilities while diagnosing release tooling.
- Inspect dependency/source changes and retain provenance/license notices when importing skills or libraries. Do not execute bundled installers, downloaders, or automatic hooks merely because they are included.
- Keep scanners and signature/transport validation enabled. Investigate false positives; use narrow, documented exceptions for verified non-secret content rather than blanket skips or relaxed security settings. Reproducibility hashes and Swift identifiers are not proof of a secret.
- macOS Keychain or Apple authentication may require the user to complete a protected dialog locally. Do not retrieve passwords, weaken key access controls, or bypass protected UI to finish a release.
- Use [storage safety](storage-safety.md) for persistence/import changes and [release verification](release-verification.md) for beta distribution. A local build, successful upload, processing completion, and tester availability are separate claims.

## Verify a release candidate

Run `./scripts/test-parallel.sh PrivacyBoundaryTests` with synthetic data. The tests check that diagnostic error labels omit error text and identifiers, RxNorm lookup requests carry the active query without saved lookup text or a request body, and a redacted share export omits names, notes, and previous searches while retaining the records. The RxNorm test captures requests at the SDK transport boundary. Validate new outbound paths against the [privacy policy](../PRIVACY.md) and inspect their actual request contents where the integration provides a test seam.

Run the [release handoff artifact audit](release-verification.md#local-release-handoff) on the archive and exported IPA. The audit compares the bundled app, widget and SDK privacy manifests to reviewed declarations. It checks signed capabilities, background modes, permission and transport declarations in bundle and localized plists, health/tracking framework links, and known test, credential and data-file payload patterns. Capability permissions in a provisioning profile can be broader than those in the signed executable. Review a proposed change to the signed expectations against the feature and its privacy disclosures before updating the audit. These checks cover the inspected declarations, request paths and file patterns. User-consented feedback, platform services, commerce SDK traffic, and physical-device behavior require their own verification when changed.

### Data boundaries

The [privacy policy](../PRIVACY.md) describes these paths in user-facing language.

| Boundary | Data and verification |
| --- | --- |
| NIH RxNorm | Sends the active lookup. [Privacy boundary tests](../AsNeededTests/PrivacyBoundaryTests.swift) capture HTTPS request contents at the SDK transport without contacting the service. |
| RevenueCat | Handles anonymous purchase and subscription data. [Configuration tests](../AsNeededTests/RevenueCatConfigurationTests.swift) and the artifact manifest check cover local configuration and declarations. The release tests disable commerce SDK traffic. |
| Notifications | Medication names depend on the privacy setting. [Notification planner tests](../AsNeededTests/MedicationAvailabilityNotificationPlannerTests.swift) cover generated content. Physical delivery and previews depend on device settings. |
| Widget | Reads local shared storage. [Widget integration](../docs/WIDGETS_INTEGRATION.md) and [recording tests](../AsNeededTests/DoseRecordingSurfaceTests.swift) describe and check this boundary. |
| Watch | Exchanges selected medication and dose information over WatchConnectivity. [Watch message tests](../AsNeededTests/WatchMessageValidationTests.swift) cover app handling. Device pairing and delivery require physical checks. |
| Backups and exports | Automatic backups write to a user-chosen folder. A cloud-backed folder can sync through its provider. [Backup tests](../AsNeededTests/AutomaticBackupStabilizationTests.swift) and [privacy boundary tests](../AsNeededTests/PrivacyBoundaryTests.swift) cover local behavior and export redaction. |

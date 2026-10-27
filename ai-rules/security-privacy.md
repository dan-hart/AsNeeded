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

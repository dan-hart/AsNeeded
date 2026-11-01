# Release Verification

Load for versions, signing, archives, TestFlight, or App Store submissions.

1. Resolve the intended app/team and authorized destination. TestFlight testing does not authorize a public App Store release, new testers, or unrelated account changes.
2. Verify the exact source/dependency revisions and app/widget/watch versions. Use a build number above both processed and in-flight uploads. Keep one coherent marketing/build version across shipping targets.
3. Run focused behavior tests and the relevant broader checks. Inspect result bundles when a formatter hides failures. Separate unchanged fixture/test-runner failures from feature failures using evidence; do not declare the entire suite green or remove assertions to pass a release.
4. Use available official build/signing tooling; optional CLI skills are convenience, not contributor requirements. Prefer existing valid signing identities. Match profiles to the actual certificate and bundle IDs; API filters may return prefix matches, so validate exact identifiers before creating resources.
5. Preserve existing signing assets. Create successor profiles without revoking unrelated resources. Handle any required protected Keychain/authentication step through the user. Keep secrets and artifacts outside the repo.
6. Inspect the exported artifact's bundle/version/profile metadata. Provide specific What to Test instructions for upgrades, repeated launches, backup/import, units/limits, permissions, notification privacy/delivery, and watch behavior as applicable.
7. Upload only to the authorized app/audience. Verify processing state and actual group/review status. Report internal availability and pending external beta review separately. Keep physical-device upgrade/delivery checks explicit before public release.

Use the installed release tooling's current help. Do not embed account credentials, tester contact lists, or machine-specific provisioning paths in repo instructions.

For local AsNeeded exports, prefer the optional `scripts/export-testflight.sh` when its project-specific local signing options are configured. It pins the intended identity/profiles and avoids unrelated temporary signing keychains. `ASNEEDED_EXPORT_OPTIONS` supports other hosts; keep those local files outside Git. See [the verified repair](../docs/testing/2026-10-27-signing-repair.md).

# Release Verification

Load for versions, signing, archives, TestFlight, or App Store submissions.

Use the `asc` CLI whenever it supports the required App Store Connect operation. Check its current help/capabilities before falling back to a browser; browser access is a last resort for unsupported operations. This preference does not authorize expiring builds, changing access, or publishing beyond the user's approved scope.

1. Resolve the intended app/team and authorized destination. TestFlight testing does not authorize a public App Store release, new testers, or unrelated account changes.
2. Verify the exact source/dependency revisions and app/widget/watch versions. Use a build number above both processed and in-flight uploads. Keep one coherent marketing/build version across shipping targets.
3. Run focused behavior tests and the relevant broader checks. Inspect result bundles when a formatter hides failures. Separate unchanged fixture/test-runner failures from feature failures using evidence; do not declare the entire suite green or remove assertions to pass a release.
4. Use available official build/signing tooling; optional CLI skills are convenience, not contributor requirements. Prefer existing valid signing identities. Match profiles to the actual certificate and bundle IDs; API filters may return prefix matches, so validate exact identifiers before creating resources.
5. Preserve existing signing assets. Create successor profiles without revoking unrelated resources. Handle any required protected Keychain/authentication step through the user. Keep secrets and artifacts outside the repo.
6. Inspect the exported artifact's bundle/version/profile metadata. Provide specific What to Test instructions for upgrades, repeated launches, backup/import, units/limits, permissions, notification privacy/delivery, and watch behavior as applicable.
7. Upload only to the authorized app/audience. Verify processing state and actual group/review status. Report internal availability and pending external beta review separately. Keep physical-device upgrade/delivery checks explicit before public release.

Use the installed release tooling's current help. Do not embed account credentials, tester contact lists, or machine-specific provisioning paths in repo instructions.

For local AsNeeded exports, prefer the optional `scripts/export-testflight.sh` when its project-specific local signing options are configured. It pins the intended identity/profiles and avoids unrelated temporary signing keychains. `ASNEEDED_EXPORT_OPTIONS` supports other hosts; keep those local files outside Git. See [the verified repair](../docs/archive/1.2.0/testing/2026-10-27-signing-repair.md).

## Local release handoff

Start from a fresh checkout of the reviewed commit. Set and commit the intended marketing version and build number for iPhone, widget, and Watch. Confirm the next unused build number in App Store Connect before preparing an artifact intended for upload. The handoff uses the checked-in Swift package lock for both tests and archive.

Use macOS, the project's Xcode and compatible iOS simulator, and Python 3.9 or later. Keep ignored files out of the Xcode source roots. Set only the RevenueCat public SDK key in the ignored `Config/Secrets.xcconfig` and verify it with `./scripts/verify-release-key.sh --local`. Install the valid development signing assets needed to archive, and the existing Apple Distribution identity and App Store profiles for all three exact bundle identifiers. Each profile must allow the capabilities of its signed target. Keep the signing options outside Git. Use the project's existing `ExportOptions.plist` or point `ASNEEDED_EXPORT_OPTIONS` at your own local file. Set the method to `app-store-connect`, use local export (`destination=export` or omit it), and set `manageAppVersionAndBuildNumber=false`. Pin the intended team, distribution certificate, and three profiles when using manual signing. See the [historical signing repair](../docs/archive/1.2.0/testing/2026-10-27-signing-repair.md) for the project-specific setup.

From the repository root, supply the intended version, build, team, and a new output directory outside the checkout. This runs the simulator suite serially with RevenueCat disabled, then archives with the configured public SDK key, exports locally and verifies both products. It uses the existing `asc` export helper when available and Xcode export otherwise. It selects an installed iOS simulator unless you provide a concrete iOS Simulator destination through `TEST_DESTINATION`.

```bash
python3 scripts/release-handoff.py prepare \
  --version "$RELEASE_VERSION" --build "$RELEASE_BUILD" --team-id "$APPLE_TEAM_ID" \
  --output /path/to/new-private-release-directory
```

Review `release-receipt.json` in the private output directory. It records the Git revision, Xcode build, `Package.resolved` digest, checked-out dependency revisions, test counts and result-bundle digest, per-target versions, archive tree digest, and IPA SHA-256. A tree digest covers sorted relative paths, entry modes, file contents, and symlink targets. Keep the `.xcresult` and local logs with the artifacts as private release evidence. A failed step stops the handoff without a receipt. Review the corresponding private log, resolve the first failure, and retry with a new output directory. For codesign trust errors, check the selected team, profile expiry, and access to the configured identity. Complete protected dialogs locally. Preserve existing signing assets.

For already-built artifacts, use the same inspection without running tests or archiving:

```bash
python3 scripts/release-handoff.py audit \
  --archive /path/to/AsNeeded.xcarchive --ipa /path/to/AsNeeded.ipa \
  --version "$RELEASE_VERSION" --build "$RELEASE_BUILD" --team-id "$APPLE_TEAM_ID" \
  --verify-signatures
```

Without `--verify-signatures`, `audit` checks the artifact metadata and reads signed entitlements and embedded profiles. A receipt requires Apple-backed signing for the expected team and targets, Apple Distribution signing for the IPA, and a trusted Apple provisioning profile matching each signing certificate. App Store Connect processing, tester group availability, and physical-device validation are separate release gates.

### Replacing a beta

If an artifact fails local checks, fix the source or signing configuration and rerun the handoff. If a build was already uploaded, check its current processing and group state, select a higher unused build number, and prepare the successor from the reviewed commit. Confirm the successor in the intended TestFlight group after authorized upload and assignment. Keep the existing build available until that confirmation unless the maintainer separately authorizes changing its availability. For an upgrade issue, rehearse the replacement in place with synthetic data and preserve a backup before asking testers to upgrade. Record the affected build, successor receipt, processing and group status, and any pending external beta review separately.

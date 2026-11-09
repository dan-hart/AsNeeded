# AsNeeded Build Scripts

Run build and simulator scripts from the repository root on macOS with Xcode 26+ and its required simulator runtimes installed. Build and test scripts detect CPU count. Memory use and elapsed time depend on the machine, workload, and caches.

## Setup and security

Install the repository's security hooks before committing:

```bash
brew install git-secrets
./scripts/install-hooks.sh
```

The installer configures `core.hooksPath`, checks the preflight helper, and runs the security scan. Review the installer before changing local Git configuration.

```bash
# Repository secret scan, including history when supported
./scripts/scan-repo.sh

# Current files only
./scripts/scan-repo.sh --quick

# Staged policy checks
./scripts/utilities/asp-preflight.sh --staged --strict
```

The scanner supports gitleaks, trufflehog, git-secrets, and a fallback scanner. Keep scanning enabled; review findings before committing.

## Read-only environment doctor

```bash
python3 scripts/doctor.py
python3 scripts/doctor.py --json
```

Requires Python 3 (standard library only). Checks the selected Xcode 26+, Swift 6.2+, Simulator SDK against project deployment targets, available compatible iPhone simulators, nonempty revision pins in `Package.resolved`, selected executable repository hooks, and scanner/preflight helper availability and permissions. Exit status is nonzero for blockers; missing optional purchase configuration is a warning. `--root PATH` inspects another checkout. Reports go only to stdout; redirect them to a temporary location if needed.

The doctor invokes only read-only Xcode/toolchain inventory and Git configuration queries. It does not install, repair, fetch/resolve packages, invoke hooks/scanners, access Keychain, or change Git/system configuration. Purchase configuration checks only whether `Config/Secrets.xcconfig` or the `REVENUECAT_API_KEY` environment variable is present, without reading configuration contents or reporting values. Presence does not prove valid credentials or working purchases. Reports omit raw command output, selected installation paths, and simulator identifiers. A healthy report does not establish successful builds/tests or a completed security scan.

## Development builds

```bash
./scripts/dev-build.sh
```

The development build uses incremental compilation, detected CPU cores, parallel targets, and a disabled index store. Its default destination is `generic/platform=iOS Simulator`, so it does not require a particular installed iPhone device/runtime. To select a destination explicitly:

```bash
BUILD_DESTINATION='platform=iOS Simulator,id=SIMULATOR-UUID' ./scripts/dev-build.sh
```

The optional `xcsift` formatter is detected automatically. If absent, the scripts show normal `xcodebuild` output. A build failure exits nonzero with either output path.

## Unit tests

```bash
./scripts/test-parallel.sh
./scripts/test-parallel.sh DataStoreTests
./scripts/test-parallel.sh NotificationManagerTests
```

The test runner selects an available installed iPhone simulator whose runtime meets the highest iOS deployment target in `AsNeeded.xcodeproj/project.pbxproj` (currently iOS 26.0) and uses 75% of detected CPU cores for test workers. If no compatible iPhone is available or inventory cannot be read, it stops with guidance before invoking `xcodebuild`. Python 3 is required for automatic selection. Select a destination explicitly and reduce worker count when needed:

```bash
xcrun simctl list devices available
TEST_DESTINATION='platform=iOS Simulator,id=SIMULATOR-UUID' TEST_WORKERS=2 ./scripts/test-parallel.sh
```

Tests require a concrete installed simulator; a generic build destination cannot run them. Build CI discovers a compatible available iPhone in the selected Xcode runtime and supplies its UUID, rather than assuming a particular simulator version is installed on hosted runners. CI builds and runs unit tests for `main`, `develop`, `task/v1.2.0`, and `task/v1.3.0`.

Set `TEST_RESULT_BUNDLE_PATH` to a fresh `.xcresult` path to retain a local bundle. `TEST_DERIVED_DATA_PATH` selects an isolated build directory and `TEST_PINNED_PACKAGES_PATH` selects an explicit package checkout directory with resolution constrained to `Package.resolved`. CI sets these paths in runner storage, compiles the app and test host with `build-for-testing`, checks the app's RevenueCat key handling, then runs the entire scheme with `TEST_WITHOUT_BUILDING=1`. Use that flag with existing Debug simulator products built for the same destination and derived data path. CI and release rehearsals run the full suite in one simulator with `TEST_PARALLEL_ENABLED=NO`. This avoids preferences write failures observed across parallel simulator clones. Local parallel runs remain available. Set `TEST_RAW_OUTPUT=1` to keep timing lines and other raw Xcode output.

## Standalone regressions

These run without the app simulator test host:

```bash
for test in scripts/tests/*test*.py; do python3 "$test"; done
python3 -m unittest discover -s scripts/localization -p 'test_*.py'
./scripts/tests/setup-codex-superpowers.test.sh
./scripts/tests/watch-medication-availability.test.sh
```

Python checks use the standard library. Setup-tool regressions use temporary directories. The fast tooling CI job runs these Python and setup checks on Ubuntu while the simulator job runs independently. The standalone macOS job uses Swift 6.2+ to compile and test the real Watch medication model in a temporary Swift package.

## Simulator CI evidence

Check the Build run summary for the outcome and the stage that stopped. `runner_setup_failure` covers Xcode and simulator selection. `package_resolution_failure`, `build_failure`, and `app_configuration_failure` identify failures before simulator tests. `test_case_failure` indicates that Xcode reported failed cases. The listed identifiers locate assertions or crashes in those cases. `test_execution_failure` means the test command failed without a reported failed case, so inspect the runner and test-host output. A successful test command with zero or unverified executed tests fails the report step as `test_evidence_failure`. If runner startup, checkout, or cancellation prevents the summary step from running, inspect the job status and steps directly.

The seven-day `simulator-test-report-<attempt>` artifact contains the same allowlisted stage outcomes, test counts, and up to 20 source-style failed test identifiers as the run summary. The workflow keeps the raw `.xcresult` in runner storage. Inspect local bundles using `xcrun xcresulttool get test-results summary --path PATH`. Share bundles only after checking that attachments, diagnostics, and logs are safe to disclose.

### Hosted baseline

GitHub job and step timestamps for the three most recent successful first attempts on `task/v1.3.0` before this workflow change, November 5–8, 2026. Durations exclude queue time. The old unit-test step included its own build. Compare the new build and test durations against the old build and unit-test steps together. The timing impact of the new workflow awaits a hosted run.

| Build run | Standalone job | Package resolution | App build | Unit-test step | Simulator job |
| --- | ---: | ---: | ---: | ---: | ---: |
| [42530004528](https://github.com/dan-hart/AsNeeded/actions/runs/42530004528) | 1:25 | 1:28 | 7:57 | 9:22 | 19:12 |
| [42115678894](https://github.com/dan-hart/AsNeeded/actions/runs/42115678894) | 1:15 | 1:12 | 6:51 | 7:23 | 15:48 |
| [42094057876](https://github.com/dan-hart/AsNeeded/actions/runs/42094057876) | 1:04 | 1:23 | 7:53 | 15:27 | 25:11 |

## Production and cleanup

```bash
./scripts/prod-build.sh
```

This creates a release build with whole-module optimization. Follow the [release handoff](../ai-rules/release-verification.md#local-release-handoff) to test, archive, export, and verify the signed artifact. App Store Connect upload and distribution are separate steps.

Cleanup removes cached work and can make the next build slower. Inspect the relevant script and use cleanup for a specific build/cache problem:

```bash
./scripts/clean-deriveddata.sh --asneeded
./scripts/clean-deriveddata.sh --old 7
```

`clean-deriveddata.sh --all` removes all Xcode DerivedData. `clean-all.sh` also removes local build, package, and Xcode caches and requests confirmation. These are broader recovery operations, not routine prerequisites.

## Troubleshooting and maintenance

- Run from the repository root if Xcode cannot find the project or scheme.
- For unavailable destinations, inspect `xcrun simctl list devices available` and set the appropriate destination override.
- For resource contention, reduce `TEST_WORKERS` instead of editing the script.
- When changing shell helpers, run `bash -n` and the focused regression tests. Verify both formatted and unformatted failure behavior when changing build wrappers.

### Encoded-secret classification

The pre-commit security hook requires Python 3 (standard library only) and scans the staged blob, including paths with spaces. `utilities/base64-secret-scan.py --path FILE` reads content from stdin (with optional `--revision SHA` for historical tracked paths), checks canonical Base64 and measured character entropy, and reports only file/line locations. Source-code identifiers, tracked file references, and labeled reproducibility hashes have narrow data classifications; provider-specific and generic credential checks remain active.

Run the deterministic classifier regressions with `python3 scripts/tests/base64-secret-scan.test.py`. Run `python3 scripts/tests/pre-commit-security.test.py` for real-hook regressions in temporary repositories, including staged secrets hidden by a clean working copy. Fixtures are synthetic and constructed without embedding live credentials.

The push hook is read-only: set build numbers before committing rather than relying on a push-time bump. It scans only unpublished commits, with historical path classification tied to each scanned revision. Run `python3 scripts/tests/pre-push-scan.test.py` for isolated push-hook regressions. After reviewing storage-sensitive changes, use `ASP_ACK_DATA_PATH=1 git commit ...` to supply the existing preflight acknowledgement explicitly; it does not disable secret scanning.

For a reviewed system-change classification, use `ASP_ACK_SYSTEM=1 git commit ...` to forward the existing `--ack-system` preflight acknowledgement. This is also needed when read-only CPU-query test fixtures match that classification. Review the actual diff first; the acknowledgement does not disable secret scanning or remove the default block on unacknowledged changes.

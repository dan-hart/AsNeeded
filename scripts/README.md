# AsNeeded Build Scripts

Run scripts from the repository root on macOS with Xcode 26+ and its required simulator runtimes installed. Build and test scripts detect CPU count; memory use and elapsed time depend on the machine, workload, and caches. No benchmark speedup is established here.

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

## Standalone regressions

These run without the app simulator test host:

```bash
for test in scripts/tests/*test*.py; do python3 "$test"; done
python3 -m unittest discover -s scripts/localization -p 'test_*.py'
./scripts/tests/setup-codex-superpowers.test.sh
./scripts/tests/watch-medication-availability.test.sh
```

Python checks use the standard library. The watch harness requires Swift 6.2+ on macOS and compiles the real watch medication model in a temporary Swift package. Setup-tool regressions use temporary directories; optional agent tooling is not a prerequisite for app builds or CI. CI runs these standalone regressions separately from the app unit tests.

## Production and cleanup

```bash
./scripts/prod-build.sh
```

This creates a release build with whole-module optimization. Follow the release documentation for signing, archiving, upload, and distribution; a local build alone does not verify those steps.

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

#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
	echo "Usage: $0 <candidate-commit-or-ref> <installed-iOS-runtime-id>" >&2
	exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(git -C "$script_dir" rev-parse --show-toplevel)
revision=$(git -C "$repo" rev-parse --verify --end-of-options "$1^{commit}")
out=$(mktemp -d "${TMPDIR:-/tmp}/asneeded-interruption.XXXXXXXX")
echo "Interruption rehearsal results: $out"
mkdir "$out/source"
git -C "$repo" archive "$revision" | tar -x -C "$out/source"
cp "$script_dir/TransactionInterruptionRehearsal.swift" "$out/source/AsNeededTests/"
simulator=$(xcrun simctl create "AsNeeded Transaction Interruption Rehearsal" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$2")
trap 'xcrun simctl shutdown "$simulator" >/dev/null 2>&1 || true' EXIT
printf '%s\n' "$simulator" > "$out/simulator-id"
printf 'candidate=%s\nruntime=%s\n' "$revision" "$2" > "$out/source.txt"
xcodebuild -version >> "$out/source.txt"
xcrun simctl boot "$simulator"
xcrun simctl bootstatus "$simulator" -b > "$out/boot.log" 2>&1

cd "$out/source"
args=(-project AsNeeded.xcodeproj -scheme AsNeeded -destination "platform=iOS Simulator,id=$simulator"
	-derivedDataPath "$out/derived" -onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO REVENUECAT_API_KEY=)
if ! xcodebuild build-for-testing "${args[@]}" > "$out/build.log" 2>&1; then
	echo "Test host build failed. See $out/build.log." >&2
	exit 1
fi

run_test() {
	local test="$1" phase="$2"
	xcodebuild test-without-building "${args[@]}" \
		"-only-testing:AsNeededTests/TransactionInterruptionRehearsal/$test()" \
		-resultBundlePath "$out/$phase.xcresult" > "$out/$phase.log" 2>&1
}

interrupt() {
	local test="$1" scenario="$2" container
	if run_test "$test" "$scenario"; then
		echo "Expected the hosted test to be killed during $scenario." >&2
		return 1
	fi
	container=$(xcrun simctl get_app_container "$simulator" com.codedbydan.AsNeeded data)
	if ! [[ -s "$container/Documents/AsNeededTransactionRehearsal/$scenario/interrupted" ]]; then
		echo "The test did not reach its kill checkpoint. See $out/$scenario.log." >&2
		return 1
	fi
	xcrun xcresulttool get test-results summary --path "$out/$scenario.xcresult" > "$out/$scenario.json"
	python3 - "$out/$scenario.json" "$test" <<'PY'
import json
import sys

with open(sys.argv[1]) as report:
    result = json.load(report)
failures = result["testFailures"]
if result["failedTests"] != 1 or len(failures) != 1:
    raise SystemExit("Expected exactly one failed test at the interruption checkpoint.")
if failures[0]["testIdentifierString"] != f"TransactionInterruptionRehearsal/{sys.argv[2]}()":
    raise SystemExit("A different test failed during the interruption rehearsal.")
if failures[0]["failureText"].lower() != "test crashed with signal kill.":
    raise SystemExit("Xcode did not report the intentional SIGKILL.")
PY
	echo "Interrupted: $scenario"
}

interrupt interruptDose dose
interrupt interruptUndo undo
interrupt interruptImport importing
for phase in first-reopen second-reopen; do
	if ! run_test recoverAfterInterruption "$phase"; then
		echo "Reopening the interrupted stores failed. See $out/$phase.log." >&2
		exit 1
	fi
	xcrun xcresulttool get test-results summary --path "$out/$phase.xcresult" > "$out/$phase.json"
	python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["passedTests"] == 1 and r["failedTests"] == r["skippedTests"] == 0 else 1)' "$out/$phase.json"
	echo "Passed: $phase"
	xcrun simctl terminate "$simulator" com.codedbydan.AsNeeded >/dev/null 2>&1 || true
done

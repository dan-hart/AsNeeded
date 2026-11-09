#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
	echo "Usage: $0 <candidate-commit-or-ref> <installed-iOS-runtime-id>" >&2
	exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(git -C "$script_dir" rev-parse --show-toplevel)
baseline=$(git -C "$repo" rev-parse --verify '1.2.0^{commit}')
candidate=$(git -C "$repo" rev-parse --verify --end-of-options "$1^{commit}")
if [[ "$baseline" != '4b2c3b6488568a350330e6eceb4e322817bd98c4' || "$baseline" == "$candidate" ]]; then
	echo "Expected the pinned 1.2.0 release and a distinct candidate." >&2
	exit 2
fi

out=$(mktemp -d "${TMPDIR:-/tmp}/asneeded-upgrade.XXXXXXXX")
# Use the reviewed synthetic fixture from history, even if the checkout copy was edited.
fixture_source='20bd877efd2256265fdd83d7aa30529617918ab6'
fixture_path='AsNeededTests/Fixtures/Upgrades/upgrade-export-v1-sparse-settings.json'
git -C "$repo" show "$fixture_source:$fixture_path" > "$out/seed.json"
echo "Upgrade rehearsal results: $out"
simulator=$(xcrun simctl create "AsNeeded 1.2 Upgrade Rehearsal" com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$2")
printf '%s\n' "$simulator" > "$out/simulator-id"
trap 'xcrun simctl shutdown "$simulator" >/dev/null 2>&1 || true' EXIT
printf 'baseline=%s\ncandidate=%s\nruntime=%s\n' "$baseline" "$candidate" "$2" > "$out/source.txt"
xcodebuild -version >> "$out/source.txt"
xcrun simctl boot "$simulator"
xcrun simctl bootstatus "$simulator" -b

prepare() {
	local stage="$1" source="$2"
	mkdir "$out/$stage"
	git -C "$repo" archive "$source" | tar -x -C "$out/$stage"
	cp "$script_dir/ReleaseUpgradeRehearsal.swift" "$out/$stage/AsNeededTests/"
	cp "$out/seed.json" \
		"$out/$stage/AsNeededTests/upgrade-rehearsal-seed.json"
}

run_test() (
	local stage="$1" phase="$2"
	cd "$out/$stage"
	if ! xcodebuild test -project AsNeeded.xcodeproj -scheme AsNeeded \
		-destination "platform=iOS Simulator,id=$simulator" -derivedDataPath "$out/$stage-derived" \
		-onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO \
		-only-testing:AsNeededTests/ReleaseUpgradeRehearsal -resultBundlePath "$out/$phase.xcresult" \
		-quiet > "$out/$phase.log" 2>&1; then
		echo "Upgrade rehearsal phase '$phase' failed. See $out/$phase.log." >&2
		return 1
	fi
	# Require evidence that the specific test ran and passed.
	xcrun xcresulttool get test-results summary --path "$out/$phase.xcresult" > "$out/$phase.json"
	python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["passedTests"] == 1 and r["failedTests"] == 0 else 1)' \
		"$out/$phase.json"
	echo "Passed: $phase"
)

prepare baseline "$baseline"
prepare candidate "$candidate"
run_test baseline seed-1.2
xcrun simctl terminate "$simulator" com.codedbydan.AsNeeded >/dev/null 2>&1 || true
run_test candidate first-launch-1.3
xcrun simctl terminate "$simulator" com.codedbydan.AsNeeded >/dev/null 2>&1 || true
run_test candidate second-launch-and-restore-1.3

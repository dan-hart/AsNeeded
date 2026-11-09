#!/usr/bin/env bash
# test-parallel.sh - Ultra-fast parallel test execution
# Maximizes CPU usage for running tests across all cores

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 AsNeeded Parallel Test Suite${NC}"
echo -e "${BLUE}═══════════════════════════════${NC}"

# Detect CPU cores and use 75% for tests (leave some for system)
CPU_CORES=$(sysctl -n hw.ncpu)
TEST_WORKERS=${TEST_WORKERS:-$((CPU_CORES * 3 / 4))}
if [ "$TEST_WORKERS" -lt 1 ]; then
	echo "TEST_WORKERS must be positive" >&2
	exit 1
fi
# Discover a concrete installed destination unless the caller selected one.
if [ -z "${TEST_DESTINATION:-}" ]; then
	TEST_DESTINATION=$(xcrun simctl list devices available --json | python3 -c '
import json
import re
import sys
from pathlib import Path

def version(value):
    parts = tuple(int(part) for part in value.replace("-", ".").split("."))
    return parts + (0,) * (3 - len(parts))

try:
    # Use the highest iOS deployment target so app and test targets can run.
    project = Path("AsNeeded.xcodeproj/project.pbxproj").read_text()
    minimum = max(version(value) for value in re.findall(r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9.]+);", project))
    devices = json.load(sys.stdin)["devices"]
    candidates = [device for runtime, entries in devices.items()
                  if ".iOS-" in runtime and version(runtime.rsplit(".iOS-", 1)[1]) >= minimum
                  for device in entries
                  if device.get("isAvailable") and device["name"].startswith("iPhone")]
except (OSError, ValueError, KeyError, TypeError, AttributeError):
    sys.exit("Could not read installed simulator inventory. Check xcrun simctl list devices available or set TEST_DESTINATION.")
if not candidates:
    sys.exit("No compatible available iPhone simulator. Install an iOS runtime/device matching the project deployment target in Xcode or set TEST_DESTINATION.")
print("platform=iOS Simulator,id=" + candidates[0]["udid"])
')
fi

echo -e "${GREEN}💪 Using $TEST_WORKERS parallel test workers (out of $CPU_CORES cores)${NC}"

TEST_PARALLEL_ENABLED=${TEST_PARALLEL_ENABLED:-YES}
case "$TEST_PARALLEL_ENABLED" in
	YES|NO) ;;
	*) echo "TEST_PARALLEL_ENABLED must be YES or NO" >&2; exit 2 ;;
esac

TEST_ACTION='test'
if [ "${TEST_WITHOUT_BUILDING:-0}" = 1 ]; then
	TEST_ACTION=test-without-building
fi
TEST_ARGS=("$TEST_ACTION"
	-project AsNeeded.xcodeproj
	-scheme AsNeeded
	-destination "$TEST_DESTINATION"
	-parallel-testing-enabled "$TEST_PARALLEL_ENABLED"
	-maximum-parallel-testing-workers "$TEST_WORKERS"
	-jobs "$CPU_CORES")
if [ "$TEST_ACTION" = test-without-building ]; then
	TEST_ARGS+=(-configuration Debug)
fi
if [ -n "${TEST_DERIVED_DATA_PATH:-}" ]; then
	TEST_ARGS+=(-derivedDataPath "$TEST_DERIVED_DATA_PATH")
fi
if [ "$TEST_ACTION" = test-without-building ] || [ -n "${TEST_PINNED_PACKAGES_PATH:-}" ]; then
	TEST_ARGS+=(-onlyUsePackageVersionsFromResolvedFile)
fi
if [ -n "${TEST_PINNED_PACKAGES_PATH:-}" ]; then
	TEST_ARGS+=(-clonedSourcePackagesDirPath "$TEST_PINNED_PACKAGES_PATH")
fi
if [ -n "${TEST_RESULT_BUNDLE_PATH:-}" ]; then
	TEST_ARGS+=(-resultBundlePath "$TEST_RESULT_BUNDLE_PATH")
fi
if [ "${TEST_DISABLE_REVENUECAT:-0}" = 1 ]; then
	TEST_ARGS+=(REVENUECAT_API_KEY=)
fi

# Check for specific test class argument
if [ -n "${1:-}" ]; then
	echo -e "${YELLOW}🎯 Running only: $1${NC}"
	TEST_ARGS+=("-only-testing:AsNeededTests/$1")
else
	echo -e "${BLUE}🎯 Running all tests${NC}"
fi

# Run tests with maximum parallelization
echo -e "${BLUE}⚡️ Executing tests...${NC}"

if [ "${TEST_RAW_OUTPUT:-0}" = 1 ]; then
	xcodebuild "${TEST_ARGS[@]}"
elif command -v xcsift &> /dev/null; then
	xcodebuild "${TEST_ARGS[@]}" -quiet 2>&1 | xcsift
else
	echo -e "${YELLOW}⚠️  xcsift not found. Using standard xcodebuild output.${NC}"
	xcodebuild "${TEST_ARGS[@]}"
fi

echo -e "${GREEN}⏱️  Test suite complete!${NC}"

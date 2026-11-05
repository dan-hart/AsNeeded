#!/usr/bin/env bash
# test-parallel.sh - Ultra-fast parallel test execution
# Maximizes CPU usage for running tests across all cores

set -euo pipefail

# Colors for output
RED='\033[0;31m'
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

# Check if xcsift is installed
if ! command -v xcsift &> /dev/null; then
    echo -e "${YELLOW}⚠️  xcsift not found. Install with: brew tap ldomaradzki/xcsift && brew install xcsift${NC}"
    echo -e "${YELLOW}   Falling back to standard output...${NC}"
    USE_XCSIFT=false
else
    USE_XCSIFT=true
fi

# Check for specific test class argument
if [ -n "${1:-}" ]; then
    echo -e "${YELLOW}🎯 Running only: $1${NC}"
    TEST_FILTER="-only-testing:AsNeededTests/$1"
else
    echo -e "${BLUE}🎯 Running all tests${NC}"
    TEST_FILTER=""
fi

# Run tests with maximum parallelization
echo -e "${BLUE}⚡️ Executing tests...${NC}"

if [ "$USE_XCSIFT" = true ]; then
    xcodebuild test \
        -project AsNeeded.xcodeproj \
        -scheme AsNeeded \
        -destination "$TEST_DESTINATION" \
        -parallel-testing-enabled YES \
        -maximum-parallel-testing-workers $TEST_WORKERS \
        -jobs $CPU_CORES \
        $TEST_FILTER \
        -quiet 2>&1 | xcsift

    TEST_STATUS=$?

    if [ $TEST_STATUS -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
    else
        echo -e "${RED}❌ Tests failed${NC}"
        exit 1
    fi
else
    xcodebuild test \
        -project AsNeeded.xcodeproj \
        -scheme AsNeeded \
        -destination "$TEST_DESTINATION" \
        -parallel-testing-enabled YES \
        -maximum-parallel-testing-workers $TEST_WORKERS \
        -jobs $CPU_CORES \
        $TEST_FILTER
fi

echo -e "${GREEN}⏱️  Test suite complete!${NC}"

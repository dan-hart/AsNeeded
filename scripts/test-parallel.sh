#!/bin/bash
# test-parallel.sh - Ultra-fast parallel test execution
# Maximizes CPU usage for running tests across all cores

set -e

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
TEST_WORKERS=$((CPU_CORES * 3 / 4))
if [ $TEST_WORKERS -lt 4 ]; then
    TEST_WORKERS=4
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
if [ -n "$1" ]; then
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
        -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
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
        -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' \
        -parallel-testing-enabled YES \
        -maximum-parallel-testing-workers $TEST_WORKERS \
        -jobs $CPU_CORES \
        $TEST_FILTER
fi

echo -e "${GREEN}⏱️  Test suite complete!${NC}"

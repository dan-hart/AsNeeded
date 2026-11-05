#!/usr/bin/env bash
# dev-build.sh - Incremental development builds with parallel compilation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 AsNeeded Development Build${NC}"
echo -e "${BLUE}════════════════════════════${NC}"

# Detect CPU cores and use ALL of them
CPU_CORES=$(sysctl -n hw.ncpu)
PARALLEL_JOBS=$CPU_CORES
BUILD_DESTINATION=${BUILD_DESTINATION:-generic/platform=iOS Simulator}
echo -e "${GREEN}💪 Using all $CPU_CORES CPU cores for maximum speed${NC}"

# Optional: Clean old DerivedData (uncomment for first-time speed boost)
# echo -e "${YELLOW}🧹 Cleaning old DerivedData...${NC}"
# find ~/Library/Developer/Xcode/DerivedData/AsNeeded-* -mtime +1 -exec rm -rf {} \; 2>/dev/null || true

# Check if xcsift is installed
if ! command -v xcsift &> /dev/null; then
    echo -e "${YELLOW}⚠️  xcsift not found. Install with: brew tap ldomaradzki/xcsift && brew install xcsift${NC}"
    echo -e "${YELLOW}   Falling back to standard output...${NC}"
    USE_XCSIFT=false
else
    USE_XCSIFT=true
fi

# Build with maximum parallelization
echo -e "${BLUE}⚡️ Building with aggressive optimizations...${NC}"

if [ "$USE_XCSIFT" = true ]; then
    xcodebuild \
        -project AsNeeded.xcodeproj \
        -scheme AsNeeded \
        -destination "$BUILD_DESTINATION" \
        -configuration Debug \
        -jobs $PARALLEL_JOBS \
        -parallelizeTargets \
        -maximum-concurrent-test-device-destinations $PARALLEL_JOBS \
        SWIFT_COMPILATION_MODE=incremental \
        COMPILER_INDEX_STORE_ENABLE=NO \
        ENABLE_TESTABILITY=YES \
        build \
        -quiet 2>&1 | xcsift

    echo -e "${GREEN}✅ Development build complete!${NC}"
else
    xcodebuild \
        -project AsNeeded.xcodeproj \
        -scheme AsNeeded \
        -destination "$BUILD_DESTINATION" \
        -configuration Debug \
        -jobs $PARALLEL_JOBS \
        -parallelizeTargets \
        -maximum-concurrent-test-device-destinations $PARALLEL_JOBS \
        SWIFT_COMPILATION_MODE=incremental \
        COMPILER_INDEX_STORE_ENABLE=NO \
        ENABLE_TESTABILITY=YES \
        build
fi

echo -e "${GREEN}⏱️  Ready for development!${NC}"

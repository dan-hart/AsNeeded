#!/bin/bash
# prod-build.sh - Optimized production/release builds
# Uses whole-module optimization and aggressive compiler settings for App Store

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏭 AsNeeded Production Build${NC}"
echo -e "${BLUE}════════════════════════════${NC}"

# Detect CPU cores and use ALL of them
CPU_CORES=$(sysctl -n hw.ncpu)
echo -e "${GREEN}💪 Using all $CPU_CORES CPU cores${NC}"

# Check if xcsift is installed
if ! command -v xcsift &> /dev/null; then
    echo -e "${YELLOW}⚠️  xcsift not found. Install with: brew tap ldomaradzki/xcsift && brew install xcsift${NC}"
    echo -e "${YELLOW}   Falling back to standard output...${NC}"
    USE_XCSIFT=false
else
    USE_XCSIFT=true
fi

# Clean build folder first
echo -e "${YELLOW}🧹 Cleaning build folder...${NC}"
rm -rf build/

# Build for release with maximum optimization
echo -e "${BLUE}⚡️ Building Release configuration...${NC}"

if [ "$USE_XCSIFT" = true ]; then
    xcodebuild \
        -project AsNeeded.xcodeproj \
        -scheme AsNeeded \
        -configuration Release \
        -jobs $CPU_CORES \
        -parallelizeTargets \
        SWIFT_COMPILATION_MODE=wholemodule \
        SWIFT_OPTIMIZATION_LEVEL="-O" \
        COMPILER_INDEX_STORE_ENABLE=YES \
        build \
        -quiet 2>&1 | xcsift

    BUILD_STATUS=$?

    if [ $BUILD_STATUS -eq 0 ]; then
        echo -e "${GREEN}✅ Production build complete!${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
else
    xcodebuild \
        -project AsNeeded.xcodeproj \
        -scheme AsNeeded \
        -configuration Release \
        -jobs $CPU_CORES \
        -parallelizeTargets \
        SWIFT_COMPILATION_MODE=wholemodule \
        SWIFT_OPTIMIZATION_LEVEL="-O" \
        COMPILER_INDEX_STORE_ENABLE=YES \
        build
fi

# Run tests before archiving (optional - uncomment if desired)
# echo -e "${BLUE}🧪 Running tests...${NC}"
# ./scripts/test-parallel.sh

echo -e "${GREEN}📦 Ready for archiving and App Store submission!${NC}"

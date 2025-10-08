#!/bin/bash
# clean-deriveddata.sh - Intelligent DerivedData cleanup
# Removes old build artifacts to speed up builds and indexing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 DerivedData Cleanup${NC}"
echo -e "${BLUE}══════════════════════${NC}"

# Check size before cleanup
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DERIVED_DATA_PATH" ]; then
    BEFORE_SIZE=$(du -sh "$DERIVED_DATA_PATH" | awk '{print $1}')
    echo -e "${YELLOW}📊 Current DerivedData size: $BEFORE_SIZE${NC}"
else
    echo -e "${GREEN}✅ DerivedData directory doesn't exist - nothing to clean${NC}"
    exit 0
fi

# Cleanup mode selection
if [ "$1" = "--all" ]; then
    echo -e "${RED}🔥 Nuclear option: Removing ALL DerivedData${NC}"
    rm -rf "$DERIVED_DATA_PATH"
    echo -e "${GREEN}✅ Complete cleanup done${NC}"
elif [ "$1" = "--old" ]; then
    DAYS=${2:-7}
    echo -e "${YELLOW}🗑️  Removing DerivedData older than $DAYS days${NC}"
    find "$DERIVED_DATA_PATH" -type d -maxdepth 1 -mtime +$DAYS -exec rm -rf {} \; 2>/dev/null || true
    echo -e "${GREEN}✅ Old data cleaned${NC}"
elif [ "$1" = "--asneeded" ]; then
    echo -e "${YELLOW}🎯 Removing AsNeeded DerivedData only${NC}"
    rm -rf "$DERIVED_DATA_PATH"/AsNeeded-* 2>/dev/null || true
    echo -e "${GREEN}✅ AsNeeded build cache cleared${NC}"
else
    echo -e "${BLUE}Usage:${NC}"
    echo -e "  ${GREEN}./clean-deriveddata.sh --asneeded${NC}  # Clean only AsNeeded (recommended)"
    echo -e "  ${GREEN}./clean-deriveddata.sh --old [days]${NC} # Clean data older than N days (default: 7)"
    echo -e "  ${GREEN}./clean-deriveddata.sh --all${NC}       # Nuclear: remove everything"
    echo ""
    echo -e "${YELLOW}💡 Tip: Run --asneeded weekly for best performance${NC}"
    exit 0
fi

# Check size after cleanup
if [ -d "$DERIVED_DATA_PATH" ]; then
    AFTER_SIZE=$(du -sh "$DERIVED_DATA_PATH" | awk '{print $1}')
    echo -e "${GREEN}📊 New DerivedData size: $AFTER_SIZE${NC}"
else
    echo -e "${GREEN}📊 DerivedData completely removed${NC}"
fi

echo -e "${GREEN}✨ Cleanup complete! Next build will be faster.${NC}"

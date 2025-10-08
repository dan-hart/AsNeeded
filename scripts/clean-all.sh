#!/bin/bash
# clean-all.sh - Nuclear cleanup option for complete fresh start
# Use when build system is acting weird or before major version changes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}☢️  NUCLEAR CLEANUP${NC}"
echo -e "${RED}══════════════════${NC}"
echo -e "${YELLOW}This will remove:${NC}"
echo -e "  • All DerivedData (~2.6GB for AsNeeded)"
echo -e "  • Local build/ folder"
echo -e "  • Xcode project caches"
echo -e "  • SPM package caches"
echo ""
echo -e "${RED}⚠️  This is irreversible and will slow down the next build!${NC}"
echo -e "${YELLOW}💡 Only use this when absolutely necessary${NC}"
echo ""

# Confirmation
read -p "Are you sure? (type 'yes' to confirm): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${GREEN}Cancelled - no changes made${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🧹 Starting nuclear cleanup...${NC}"

# 1. Clean DerivedData
if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
    SIZE=$(du -sh "$HOME/Library/Developer/Xcode/DerivedData" | awk '{print $1}')
    echo -e "${YELLOW}🗑️  Removing DerivedData ($SIZE)...${NC}"
    rm -rf "$HOME/Library/Developer/Xcode/DerivedData"
    echo -e "${GREEN}✅ DerivedData removed${NC}"
fi

# 2. Clean local build folder
if [ -d "build" ]; then
    echo -e "${YELLOW}🗑️  Removing local build/ folder...${NC}"
    rm -rf build/
    echo -e "${GREEN}✅ Build folder removed${NC}"
fi

# 3. Clean SPM caches
SPM_CACHE="$HOME/Library/Caches/org.swift.swiftpm"
if [ -d "$SPM_CACHE" ]; then
    SIZE=$(du -sh "$SPM_CACHE" | awk '{print $1}')
    echo -e "${YELLOW}🗑️  Removing SPM caches ($SIZE)...${NC}"
    rm -rf "$SPM_CACHE"
    echo -e "${GREEN}✅ SPM caches removed${NC}"
fi

# 4. Clean Xcode caches
XCODE_CACHE="$HOME/Library/Caches/com.apple.dt.Xcode"
if [ -d "$XCODE_CACHE" ]; then
    SIZE=$(du -sh "$XCODE_CACHE" | awk '{print $1}')
    echo -e "${YELLOW}🗑️  Removing Xcode caches ($SIZE)...${NC}"
    rm -rf "$XCODE_CACHE"
    echo -e "${GREEN}✅ Xcode caches removed${NC}"
fi

# 5. Clean project-specific caches
echo -e "${YELLOW}🗑️  Removing .swiftpm caches...${NC}"
rm -rf .swiftpm/xcode 2>/dev/null || true
echo -e "${GREEN}✅ Project caches removed${NC}"

# 6. Resolve SPM packages fresh
echo -e "${YELLOW}📦 Resolving SPM packages...${NC}"
xcodebuild -resolvePackageDependencies -project AsNeeded.xcodeproj -scheme AsNeeded

echo ""
echo -e "${GREEN}✨ Nuclear cleanup complete!${NC}"
echo -e "${BLUE}💡 Next steps:${NC}"
echo -e "  1. Open Xcode and let it re-index the project (~2-3 minutes)"
echo -e "  2. Run ${GREEN}./scripts/dev-build.sh${NC} to verify everything works"
echo -e "  3. Subsequent builds will be much faster"

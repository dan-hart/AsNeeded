#!/bin/bash
# Install security hooks for AsNeeded
#
# This script configures git to use the .githooks directory
# and verifies the hooks are executable.

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Installing security hooks for AsNeeded...${NC}"

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

cd "$REPO_ROOT"

# Check if .githooks directory exists
if [ ! -d ".githooks" ]; then
    echo -e "${RED}Error: .githooks directory not found${NC}"
    echo "Please ensure you have the latest version of the repository."
    exit 1
fi

# Configure git to use .githooks directory
echo "Configuring git hooks path..."
git config core.hooksPath .githooks

# Make hooks executable
echo "Setting executable permissions on hooks..."
chmod +x .githooks/pre-commit 2>/dev/null || true
chmod +x .githooks/pre-push 2>/dev/null || true

# Verify configuration
HOOKS_PATH=$(git config --get core.hooksPath)
if [ "$HOOKS_PATH" = ".githooks" ]; then
    echo -e "${GREEN}Git hooks path configured: $HOOKS_PATH${NC}"
else
    echo -e "${RED}Warning: Hooks path may not be configured correctly${NC}"
fi

# Check if hooks exist and are executable
echo ""
echo "Verifying hooks:"
for hook in pre-commit pre-push; do
    if [ -x ".githooks/$hook" ]; then
        echo -e "  ${GREEN}[OK]${NC} $hook"
    elif [ -f ".githooks/$hook" ]; then
        echo -e "  ${YELLOW}[WARN]${NC} $hook exists but is not executable"
        chmod +x ".githooks/$hook"
        echo -e "  ${GREEN}[FIXED]${NC} Made $hook executable"
    else
        echo -e "  ${RED}[MISSING]${NC} $hook"
    fi
done

# Optionally run a quick scan
echo ""
echo -e "${YELLOW}Running initial security scan...${NC}"
if command -v git-secrets &> /dev/null; then
    echo "Using git-secrets for scan..."
    git secrets --scan 2>/dev/null || true
elif [ -x "./scripts/scan-repo.sh" ]; then
    echo "Using scan-repo.sh for scan..."
    ./scripts/scan-repo.sh --quick 2>/dev/null || true
else
    echo "Skipping initial scan (no scanner available)"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Security hooks installed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your commits will now be scanned for:"
echo "  - API keys and tokens (17+ providers)"
echo "  - Private keys and certificates"
echo "  - Passwords and connection strings"
echo "  - Hardcoded user paths"
echo ""
echo "Server-side scanning is also enabled via GitHub Actions."
echo ""
echo "See SECURITY.md for the full security policy."

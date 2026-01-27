#!/bin/bash
# Scan repository for secrets
#
# This script scans the entire git history for potential secrets.
# It uses gitleaks if available, otherwise falls back to grep.

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Options
QUICK_SCAN=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --quick|-q) QUICK_SCAN=true ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --quick, -q   Scan only current working tree (faster)"
            echo "  --help, -h    Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  AsNeeded Repository Security Scan${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

cd "$REPO_ROOT"

# Determine which scanner to use
SCANNER=""
if command -v gitleaks &> /dev/null; then
    SCANNER="gitleaks"
elif command -v trufflehog &> /dev/null; then
    SCANNER="trufflehog"
elif command -v git-secrets &> /dev/null; then
    SCANNER="git-secrets"
else
    SCANNER="grep"
fi

echo -e "Using scanner: ${GREEN}$SCANNER${NC}"
echo ""

FOUND_SECRETS=0

case $SCANNER in
    gitleaks)
        echo "Running gitleaks..."
        if [ "$QUICK_SCAN" = true ]; then
            gitleaks detect --source . --no-git --verbose 2>&1 || FOUND_SECRETS=$?
        else
            gitleaks detect --source . --verbose 2>&1 || FOUND_SECRETS=$?
        fi
        ;;

    trufflehog)
        echo "Running trufflehog..."
        if [ "$QUICK_SCAN" = true ]; then
            trufflehog filesystem . --only-verified 2>&1 || FOUND_SECRETS=$?
        else
            trufflehog git file://. --only-verified 2>&1 || FOUND_SECRETS=$?
        fi
        ;;

    git-secrets)
        echo "Running git-secrets..."
        if [ "$QUICK_SCAN" = true ]; then
            git secrets --scan 2>&1 || FOUND_SECRETS=$?
        else
            git secrets --scan-history 2>&1 || FOUND_SECRETS=$?
        fi
        ;;

    grep)
        echo -e "${YELLOW}No dedicated scanner found. Using grep fallback.${NC}"
        echo "For better results, install gitleaks: brew install gitleaks"
        echo ""

        # Critical patterns
        PATTERNS=(
            'ghp_[a-zA-Z0-9]{36}'
            'github_pat_[a-zA-Z0-9_]{20,}'
            'sk-[a-zA-Z0-9]{20,}'
            'sk-ant-[a-zA-Z0-9-]{20,}'
            'AKIA[0-9A-Z]{16}'
            'xox[bpas]-[0-9]+'
            'sk_live_[a-zA-Z0-9]{24,}'
            'AIza[0-9A-Za-z_-]{35}'
            'ATATT[a-zA-Z0-9]{20,}'
            'appl_[a-zA-Z0-9]{24,}'
            '-----BEGIN[A-Z ]*PRIVATE KEY-----'
        )

        echo "Scanning for patterns..."
        for pattern in "${PATTERNS[@]}"; do
            MATCHES=""
            if [ "$QUICK_SCAN" = true ]; then
                MATCHES=$(grep -r -n -E "$pattern" \
                    --include="*.swift" \
                    --include="*.m" \
                    --include="*.h" \
                    --include="*.json" \
                    --include="*.plist" \
                    --include="*.yml" \
                    --include="*.yaml" \
                    . 2>/dev/null \
                    | grep -v ".githooks/" \
                    | grep -v ".github/workflows/" \
                    | grep -v ".build/" \
                    | grep -v "DerivedData/" \
                    || true)
            else
                # Scan git history
                MATCHES=$(git log -p --all -S "$pattern" -- '*.swift' '*.json' '*.plist' 2>/dev/null | head -50 || true)
            fi

            if [ -n "$MATCHES" ]; then
                FOUND_SECRETS=1
                echo -e "${RED}Found potential secret matching: $pattern${NC}"
                echo "$MATCHES" | head -10
                echo ""
            fi
        done
        ;;
esac

echo ""
echo -e "${CYAN}========================================${NC}"
if [ $FOUND_SECRETS -eq 0 ]; then
    echo -e "${GREEN}  Scan complete: No secrets detected${NC}"
else
    echo -e "${RED}  Scan complete: Potential secrets found!${NC}"
    echo ""
    echo "Please review the findings above and:"
    echo "  1. Remove any real secrets from the codebase"
    echo "  2. Rotate any exposed credentials"
    echo "  3. Use BFG Repo-Cleaner to remove from git history if needed"
fi
echo -e "${CYAN}========================================${NC}"

exit $FOUND_SECRETS

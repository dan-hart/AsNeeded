#!/bin/bash
# verify-release-key.sh - Confirm the RevenueCat public SDK key reached a build, or a local secrets file
#
# The key is never committed. It flows from Config/Secrets.xcconfig into the app's Info.plist at build
# time, so a build that silently lacks it ships without tipping. This script makes that loud.
#
# Usage:
#   ./scripts/verify-release-key.sh --local                        # before archiving: does Config/Secrets.xcconfig carry a key?
#   ./scripts/verify-release-key.sh path/to/AsNeeded.app
#   ./scripts/verify-release-key.sh path/to/AsNeeded.xcarchive
#   ./scripts/verify-release-key.sh path/to/AsNeeded.ipa
#   ./scripts/verify-release-key.sh --expect-empty path/to/AsNeeded.app   # keyless builds (forks, CI without the secret)
#
# The key's value is never printed, only its length.
set -euo pipefail

PLIST_KEY="RevenueCatAPIKey"
SECRETS_FILE="Config/Secrets.xcconfig"
EXPECT_EMPTY=false
TARGET=""

usage() {
    sed -n '2,14p' "$0" | sed -E 's/^# ?//'
}

fail() {
    echo "❌ $1" >&2
    exit 1
}

# A value counts as usable when it is non-empty, not an unexpanded $(BUILD_SETTING) placeholder, and not the
# REPLACE_ placeholder from Config/Secrets.example.xcconfig.
is_usable() {
    local value="$1"
    [[ -n "$value" && "$value" != \$\(* && "$value" != REPLACE_* ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local) TARGET="--local"; shift ;;
        --expect-empty) EXPECT_EMPTY=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) TARGET="$1"; shift ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    usage
    exit 64
fi

if [[ "$TARGET" == "--local" ]]; then
    [[ -f "$SECRETS_FILE" ]] || fail "$SECRETS_FILE not found. Copy Config/Secrets.example.xcconfig to it and add your RevenueCat public SDK key."
    VALUE=$(sed -nE 's/^[[:space:]]*REVENUECAT_API_KEY[[:space:]]*=[[:space:]]*(.*)$/\1/p' "$SECRETS_FILE" | tail -1 | sed -E 's|[[:space:]]*(//.*)?$||')
    if [[ "$VALUE" == REPLACE_* ]]; then
        fail "$SECRETS_FILE still has the REPLACE_ placeholder. Paste your RevenueCat public SDK key; archives from this checkout would ship without tipping."
    fi
    is_usable "$VALUE" || fail "$SECRETS_FILE does not set REVENUECAT_API_KEY. Archives from this checkout would ship without tipping."
    echo "✅ $SECRETS_FILE sets REVENUECAT_API_KEY (${#VALUE} characters)."
    exit 0
fi

APP=""
case "$TARGET" in
    *.xcarchive)
        APP=$(find "$TARGET/Products/Applications" -maxdepth 1 -name "*.app" 2>/dev/null | head -1)
        ;;
    *.ipa)
        WORK_DIR=$(mktemp -d)
        trap 'rm -rf "$WORK_DIR"' EXIT
        unzip -q "$TARGET" -d "$WORK_DIR"
        APP=$(find "$WORK_DIR/Payload" -maxdepth 1 -name "*.app" 2>/dev/null | head -1)
        ;;
    *.app)
        APP="$TARGET"
        ;;
    *)
        fail "Unsupported target: $TARGET (expected a .app, .xcarchive, .ipa, or --local)"
        ;;
esac

[[ -n "$APP" && -d "$APP" ]] || fail "No .app bundle found in $TARGET"
PLIST="$APP/Info.plist"
[[ -f "$PLIST" ]] || fail "No Info.plist in $APP"

VALUE=$(plutil -extract "$PLIST_KEY" raw -o - "$PLIST" 2>/dev/null || true)

if [[ "$VALUE" == \$\(* ]]; then
    fail "$PLIST_KEY is the unexpanded placeholder. Config/AsNeeded.xcconfig is not applied to this target."
fi

if [[ "$EXPECT_EMPTY" == true ]]; then
    if [[ -z "$VALUE" ]]; then
        echo "✅ $PLIST_KEY is empty, as expected for a keyless build."
        exit 0
    fi
    fail "$PLIST_KEY is set (${#VALUE} characters) but this build was expected to be keyless."
fi

is_usable "$VALUE" || fail "$PLIST_KEY is empty or still the REPLACE_ placeholder. This build ships without tipping. Fill in $SECRETS_FILE and rebuild."
echo "✅ $PLIST_KEY is set (${#VALUE} characters) in $(basename "$APP")."

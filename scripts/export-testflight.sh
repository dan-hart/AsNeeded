#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage: scripts/export-testflight.sh ARCHIVE_PATH IPA_PATH

Export an existing archive with this Mac's AsNeeded-specific signing options.
Set ASNEEDED_EXPORT_OPTIONS to use a different local ExportOptions.plist.
No upload, provisioning update, keychain mutation, or password handling occurs.
Requires the optional asc CLI and locally configured signing assets.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	usage
	exit 0
fi
if [[ $# -ne 2 ]]; then
	usage >&2
	exit 2
fi

archive_path=$1
ipa_path=$2
export_options=${ASNEEDED_EXPORT_OPTIONS:-"$HOME/Library/Developer/AsNeeded/Signing/ExportOptions.plist"}
if [[ ! -d "$archive_path" || ! -f "$export_options" ]]; then
	echo "An existing archive and local AsNeeded signing options are required." >&2
	echo "Set ASNEEDED_EXPORT_OPTIONS to your configured ExportOptions.plist." >&2
	exit 1
fi
if [[ -e "$ipa_path" ]]; then
	echo "The output already exists; choose a new IPA path." >&2
	exit 1
fi
if ! command -v asc >/dev/null 2>&1; then
	echo "The optional asc CLI is required for this helper. Use Xcode export with your signing options instead." >&2
	exit 1
fi

# Snapshot the checked options so a concurrent edit cannot turn an export into an upload.
options_dir=$(mktemp -d)
trap 'rm -rf "$options_dir"' EXIT
local_options="$options_dir/ExportOptions.plist"
cp "$export_options" "$local_options"
if ! /usr/bin/plutil -lint "$local_options" >/dev/null 2>&1; then
	echo "ExportOptions.plist is invalid." >&2
	exit 1
fi
destination=$(/usr/bin/plutil -extract destination raw -o - "$local_options" 2>/dev/null || true)
if [[ -n "$destination" && "$destination" != "export" ]]; then
	echo "ExportOptions.plist must use local export." >&2
	exit 1
fi

asc xcode export \
	--archive-path "$archive_path" \
	--export-options "$local_options" \
	--ipa-path "$ipa_path" \
	--timeout 10m \
	--output json

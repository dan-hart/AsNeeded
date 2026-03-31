#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/setup-codex-superpowers.sh"

fail() {
	echo "FAIL: $1" >&2
	exit 1
}

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

test_home="$temp_dir/home"
test_codex_home="$temp_dir/codex-home"
mkdir -p "$test_home" "$test_codex_home/superpowers/skills"

if HOME="$test_home" CODEX_HOME="$test_codex_home" "$SCRIPT_PATH" --help >/dev/null 2>&1; then
	:
else
	fail "--help should succeed"
fi

HOME="$test_home" CODEX_HOME="$test_codex_home" "$SCRIPT_PATH" >/dev/null 2>&1 || fail "default dry-run should succeed"

if [ -e "$test_home/.agents/skills/superpowers" ]; then
	fail "dry-run should not create the superpowers link"
fi

HOME="$test_home" CODEX_HOME="$test_codex_home" "$SCRIPT_PATH" --apply >/dev/null 2>&1 || fail "--apply should succeed"

if [ ! -L "$test_home/.agents/skills/superpowers" ]; then
	fail "--apply should create a symlink"
fi

if [ "$(readlink "$test_home/.agents/skills/superpowers")" != "$test_codex_home/superpowers/skills" ]; then
	fail "symlink should point to the Codex superpowers skills directory"
fi

rm -f "$test_home/.agents/skills/superpowers"
mkdir -p "$test_home/.agents/skills/superpowers"

if HOME="$test_home" CODEX_HOME="$test_codex_home" "$SCRIPT_PATH" --apply >/dev/null 2>&1; then
	fail "--apply should fail when a conflicting path already exists"
fi

echo "PASS: setup-codex-superpowers"

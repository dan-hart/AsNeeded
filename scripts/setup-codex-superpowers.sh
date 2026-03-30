#!/usr/bin/env bash
set -euo pipefail

mode="dry-run"

usage() {
	cat <<'EOF'
Optional Codex superpowers setup

Usage:
  ./scripts/setup-codex-superpowers.sh [--dry-run]
  ./scripts/setup-codex-superpowers.sh --apply
  ./scripts/setup-codex-superpowers.sh --help

Behavior:
  - Defaults to dry-run
  - Uses CODEX_HOME if set, otherwise ~/.codex
  - Creates ~/.agents/skills/superpowers only when it is missing
  - Refuses to overwrite conflicting existing paths
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run)
			mode="dry-run"
			shift
			;;
		--apply)
			mode="apply"
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
	esac
done

codex_home="${CODEX_HOME:-$HOME/.codex}"
source_path="$codex_home/superpowers/skills"
skills_dir="$HOME/.agents/skills"
link_path="$skills_dir/superpowers"

if [[ ! -d "$source_path" ]]; then
	echo "Error: source path does not exist: $source_path" >&2
	exit 1
fi

if [[ -L "$link_path" ]]; then
	current_target="$(readlink "$link_path")"
	if [[ "$current_target" == "$source_path" ]]; then
		echo "Superpowers symlink already configured: $link_path -> $source_path"
		exit 0
	fi

	echo "Error: conflicting symlink already exists at $link_path" >&2
	echo "Current target: $current_target" >&2
	exit 1
fi

if [[ -e "$link_path" ]]; then
	echo "Error: conflicting path already exists at $link_path" >&2
	exit 1
fi

if [[ "$mode" == "dry-run" ]]; then
	echo "Dry run: would create $link_path -> $source_path"
	exit 0
fi

mkdir -p "$skills_dir"
ln -s "$source_path" "$link_path"

echo "Created superpowers symlink: $link_path -> $source_path"

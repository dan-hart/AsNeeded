# Script Rules

**Applies To**: Shell scripts, hooks, local setup tools, and small automation
**When to Load**: When touching `scripts/`, `.githooks/`, or automation helpers
**Priority**: Must

## Intent

Keep automation safe, testable, and respectful of contributor environments.

## Must

- Use `#!/usr/bin/env bash` with `set -euo pipefail` for Bash scripts unless a different shell is required.
- Default risky or environment-mutating scripts to dry-run when practical.
- Keep optional local tooling optional; never wire it into hooks or CI unless the repo explicitly requires it.
- Support safe testing through environment overrides when the script touches machine-local paths.
- Run `bash -n` on changed shell scripts.

## Should

- Print clear next steps and failure reasons.
- Fail safely on conflicting existing files or directories.
- Keep behavior predictable and explicit rather than clever.

## Avoid

- Automatic mutation of a contributor's home directory without an explicit apply flag.
- Hidden dependencies on tools that are not already documented by the repo.
- Force flags for local setup scripts unless there is a strong recovery story.

## Checklist

- [ ] Script defaults are safe
- [ ] `bash -n` passes
- [ ] Optional tooling stays optional

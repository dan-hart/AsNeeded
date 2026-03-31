# AI Guidance

This repository is intentionally **agent-agnostic**.

## What Is Portable

The portable AI contract for this repo lives in:

- `AGENTS.md`
- `ai-rules/`

Those files are public, reviewable, and safe for any contributor or coding agent to follow.

## What Is Optional

Some maintainers may choose to layer local tooling on top of the portable repo rules. That setup is optional and must remain outside required contributor workflows.

Examples:

- local Codex setup
- local skill systems such as superpowers
- personal shell aliases or wrappers

## Boundaries

- Do not make hooks, CI, builds, or tests depend on local AI tooling.
- Do not commit `~/.codex`, `~/.agents`, symlinks, or machine-specific config.
- Prefer docs and manual helper scripts over automatic setup.

## Optional Codex Setup

If you use Codex locally, see `docs/ai/codex.md`.

# Agent-Agnostic AI Integration Design

**Date:** 2026-03-30
**Status:** Approved

## Summary

Adopt a hybrid AI guidance model for AsNeeded:

- Keep the repository itself agent-agnostic and safe for open-source contributors.
- Make `AGENTS.md` the portable entry point for repository guidance.
- Move task-specific AI behavior into a small `ai-rules/` tree.
- Provide optional, clearly separated Codex + superpowers setup docs and a manual helper script for maintainers who want that workflow locally.

## Goals

- Improve guidance quality for any coding agent without requiring a specific tool.
- Reduce duplication by introducing a lean, canonical `AGENTS.md`.
- Keep machine-local setup optional and out of hooks, CI, and required contributor flows.
- Preserve the repository's existing safety posture around storage, secrets, verification, and build health.

## Non-Goals

- Do not vendor superpowers into this repository.
- Do not require contributors to install Codex, Claude, Gemini, or any local skill system.
- Do not make hooks, build scripts, or CI depend on local AI setup.
- Do not commit local `~/.codex`, `~/.agents`, symlinks, or machine-specific state.

## Design

### 1. Canonical portable guidance

Create a concise root `AGENTS.md` that:

- explains the repository purpose and safety boundaries
- defines the rule-loading entry point
- points agents to `ai-rules/general.md` and `ai-rules/rule-loading.md`
- keeps modern AsNeeded conventions visible without copying every detail from `CLAUDE.md`

`CLAUDE.md` remains available for compatibility, but the new public contract is `AGENTS.md` plus `ai-rules/`.

### 2. Progressive rule loading

Add a focused `ai-rules/` directory with small files for:

- general rules
- rule loading / trigger map
- testing
- SwiftUI / UI work
- storage and persistence safety
- shell scripts and automation
- anti-hallucination / evidence-first verification

This follows the same lightweight rule pattern used successfully in `~/2nd-brain`, but the content will be adapted to AsNeeded's existing conventions.

### 3. Optional Codex adapter

Add `docs/ai/README.md` and `docs/ai/codex.md` to describe:

- that the repo is agent-agnostic
- what local Codex users can enable on their own machine
- how superpowers relates to the repo-local rules
- the boundary between public repo rules and private machine setup

Add a manual helper script, `scripts/setup-codex-superpowers.sh`, with a dry-run default. It should only create the standard local superpowers discovery symlink if the target is safe and missing.

### 4. Safe optional automation boundaries

The optional setup script must:

- default to dry-run
- never run automatically from hooks, bootstrap flows, or CI
- fail safely if a conflicting path already exists
- work with `CODEX_HOME` overrides for testability

## Risks And Mitigations

- **Risk:** Repo guidance drifts between `AGENTS.md` and `CLAUDE.md`.
  - **Mitigation:** Make `AGENTS.md` the concise public entry point and avoid editing `CLAUDE.md` in this change.

- **Risk:** Optional Codex setup becomes a hidden requirement.
  - **Mitigation:** Document clearly that it is optional and keep all repo automation independent of it.

- **Risk:** New script could mutate a contributor's local setup unexpectedly.
  - **Mitigation:** Default to dry-run, require `--apply`, and block on conflicting existing paths.

## Validation

- Verify the new docs and rule files exist at the expected paths.
- Run a shell smoke test for the optional setup script.
- Run script syntax checks.
- Run `coderabbit --plain` after the implementation work.

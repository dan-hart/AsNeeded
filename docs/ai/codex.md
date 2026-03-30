# Codex Setup

Codex support in this repo is optional and layered on top of the portable guidance in `AGENTS.md` and `ai-rules/`.

## What The Repo Provides

- agent-agnostic repo guidance
- optional local setup documentation
- an optional helper script for the standard superpowers discovery symlink

## What Stays Local

- your Codex installation
- your `~/.codex` directory
- your `~/.agents` directory
- any local skill libraries or symlinks

## Optional Superpowers Setup

Preview what the helper script would do:

```bash
./scripts/setup-codex-superpowers.sh
```

Apply the change:

```bash
./scripts/setup-codex-superpowers.sh --apply
```

The script:

- defaults to dry-run
- uses `CODEX_HOME` if set, otherwise `~/.codex`
- creates `~/.agents/skills/superpowers` only when safe
- refuses to overwrite a conflicting existing path

## Manual Equivalent

```bash
mkdir -p ~/.agents/skills
[ -e ~/.agents/skills/superpowers ] || ln -s ~/.codex/superpowers/skills ~/.agents/skills/superpowers
```

Restart Codex after changing local skill discovery so new skills are detected.

## Contributor Boundary

This setup is for local maintainer convenience only. The repository must remain usable for contributors who never install Codex or superpowers.

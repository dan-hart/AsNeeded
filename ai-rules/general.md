# General Rules

**Applies To**: All tasks
**When to Load**: Always
**Priority**: Must

## Intent

Keep agent output grounded, concise, and aligned with AsNeeded's existing code, safety rules, and contributor workflows.

## Must

- Follow `AGENTS.md` and `ai-rules/rule-loading.md`.
- Prefer existing repo patterns over inventing new structure.
- Use the optimized repo scripts for build and test verification when relevant.
- Keep changes minimal, reversible, and easy to review.
- Ground repo-specific claims in local files or command output.

## Should

- Prefer `rg` for search and avoid scanning build artifacts, `DerivedData`, `.swiftpm`, and localization folders unless needed.
- Mention assumptions when local evidence is incomplete.
- Reuse existing components, helpers, and docs before adding new ones.

## Avoid

- Provider-specific instructions in core repo guidance.
- Large duplicated instruction files when a focused rule file will do.
- Claiming success without verification.

## Checklist

- [ ] Loaded the right additional rules for this task
- [ ] Used existing repo patterns where possible
- [ ] Verified the change at the smallest relevant scope

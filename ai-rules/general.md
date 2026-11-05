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
- Check the current checkout, branch, diff, and applicable subtree instructions before editing. Preserve unrelated local work; inspect other worktrees when the task depends on work already done elsewhere.
- Follow the user's authorized scope through verification. Report implemented, tested, installed, uploaded, and distributed states separately when those distinctions matter.

## Should

- Prefer `rg` for search and avoid scanning build artifacts, `DerivedData`, `.swiftpm`, and localization folders unless needed.
- Mention assumptions when local evidence is incomplete.
- Reuse existing components, helpers, and docs before adding new ones.
- After changes, review the final diff and status. Commit or publish within the user's requested scope and verify the resulting revision or external state; do not run personal multi-repository sync commands as an implicit setup step.

## Avoid

- Provider-specific instructions in core repo guidance.
- Large duplicated instruction files when a focused rule file will do.
- Claiming success without verification.

## Checklist

- [ ] Loaded the right additional rules for this task
- [ ] Used existing repo patterns where possible
- [ ] Verified the change at the smallest relevant scope

# Anti-Hallucination Rules

**Applies To**: Repo guidance, research-heavy tasks, AI workflow docs, and ambiguous technical claims
**When to Load**: When unsupported claims are a material risk
**Priority**: Must

## Intent

Favor evidence over confidence so repo guidance stays trustworthy.

## Must

- Ground repo-specific claims in local files, scripts, or command output.
- Mark conclusions as inference when they combine multiple facts.
- State uncertainty plainly when evidence is missing.
- Run the smallest relevant verification before saying a change works.
- Cite external sources when a claim depends on facts outside the repo.

## Source Order

1. Local code and command output
2. Repo docs and scripts
3. Existing templates and workflows
4. External sources

## Verification Examples

- Docs and rules: path checks, `rg`, or link validation
- Scripts: `bash -n`, `--help`, or safe smoke tests
- App code: targeted tests, then broader build or test scripts when warranted

## Avoid

- Presenting guesses as established repo policy.
- Claiming a fix is complete before verification.
- Turning tool-specific assumptions into public repo guidance.

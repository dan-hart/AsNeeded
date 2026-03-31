# Testing Rules

**Applies To**: Test additions, test fixes, behavior changes, and regression work
**When to Load**: When tests are added, changed, or failing
**Priority**: Must

## Intent

Keep tests fast, deterministic, and focused on app behavior that matters.

## Must

- Use Swift Testing with `import Testing`, `@Test`, and `#expect`.
- Prefer unit tests for domain and service behavior.
- Avoid UI and snapshot testing in this repo.
- For code changes, run the smallest relevant verification first, then broader scripts as needed.
- Use `./scripts/test-parallel.sh` for broader verification when test work is complete.

## Should

- Test the public behavior, not private implementation details.
- Keep fixtures and helpers simple and readable.
- Add regression coverage when fixing a bug.

## Avoid

- Flaky timing-based assertions.
- Network-dependent unit tests.
- Over-testing SwiftUI view internals instead of the underlying logic.

## Checklist

- [ ] New or changed behavior is covered
- [ ] Tests are deterministic
- [ ] `./scripts/test-parallel.sh` was run when the scope warrants it

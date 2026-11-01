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
- Use isolated storage/defaults and injected notification clients. Do not let unit tests request real permissions or rewrite a shared container during concurrent tests. Serialize unavoidable shared-resource tests and restore state in `defer`.
- Use an injected reference date for rolling windows and test exact boundaries, quantity units, invalid numbers, optional fields, and older schema decoding.
- Inspect test-result bundles when runner output is incomplete; a formatter reporting no failed assertions does not prove the test host succeeded.
- Add regression coverage when fixing a bug.

## Avoid

- Flaky timing-based assertions.
- Network-dependent unit tests.
- Over-testing SwiftUI view internals instead of the underlying logic.

## Checklist

- [ ] New or changed behavior is covered
- [ ] Tests are deterministic
- [ ] `./scripts/test-parallel.sh` was run when the scope warrants it

# Code Review

Load when reviewing changes or addressing review feedback.

- Inspect the actual diff, surrounding code, affected callers, and applicable rules. Identify the reviewed base/head; if the branch changes, recheck affected conclusions before posting or resolving feedback.
- Prioritize correctness, data preservation, security, behavioral regressions, accessibility, and meaningful test gaps. Order findings by severity and give concrete file/line evidence, the triggering scenario, and the consequence. Avoid style-only churn outside the task.
- Validate each incoming comment against the current implementation before changing code. If a suggestion is stale, incorrect, or conflicts with the requested behavior, explain the evidence instead of implementing it mechanically.
- Make the smallest appropriate fix and run relevant regression checks. Resolve a remote discussion only after its concern is addressed and verified; state skipped or unavailable checks explicitly.
- Keep draft review text separate from published comments. Existing authorization controls posting, resolving, merging, and release actions; a review request alone does not authorize those mutations.

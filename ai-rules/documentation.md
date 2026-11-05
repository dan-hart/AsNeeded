# Documentation

Load when adding or changing documentation, repository guidance, or architectural decisions.

- Update the existing authoritative document before adding another. Search the relevant docs and code first; keep `AGENTS.md` as a concise entrypoint and put task-specific detail in the appropriate `ai-rules/` file or `docs/` area.
- Use Markdown for prose, kebab-case names for new documents, and JSON for structured manifests. Retain formats required by Xcode, GitHub Actions, localization catalogs, or the Agent Skills format; do not rewrite working configuration for cosmetic consistency.
- Distinguish current behavior, proposed work, and historical release evidence. Date release-specific receipts and include the source revision, app/build version, target/runtime, and checks needed to interpret the result. Historical plans and screenshots do not establish current implementation or authorization.
- Make durable docs useful to another contributor: explain the relevant behavior, decision, tradeoff, or recovery procedure. Keep temporary investigation notes and raw command output outside Git unless the task calls for a maintained record. Use synthetic examples and placeholder paths/IDs; preserve required attribution and license notices for imported content.
- For architecture or cross-cutting changes, record the decision and compatibility/migration consequences in the existing architecture documentation or a focused decision record when warranted. Avoid creating a new decision log for routine edits.
- Keep commands reproducible and state prerequisites or platform limits. Do not present machine-local aliases, home-directory checkouts, optional agent tooling, or personal credentials as contributor requirements.
- Check changed local links, referenced paths, command flags, and relevant manifest hashes. Run documentation checks already provided by the repo when applicable; do not add a tool dependency just to validate prose. Update the rule-loading index when adding or changing task routing.
- For maintained documents covered by `drift.lock`, run `drift check` when available and review stale anchors before refreshing them. See [the pinned workflow](../docs/drift.md). A fresh anchor is not proof of a business rule; retain behavioral regression tests. Do not anchor archived plans as current specifications.
- Report what was checked and what remains unverified. Documentation-only changes need link/configuration checks, not an unrelated full app test run.

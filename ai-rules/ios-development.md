# iOS Development

Load for Swift models, state, concurrency, services, app intents, watch sync, and dependencies.

- Inspect actual targets, package revisions, and existing owners before choosing APIs or architecture. Verify version-specific symbols in local Apple documentation or official docs.
- Keep shared medication models in ANModelKit independent of UI and storage frameworks. Put calculations in deterministic services; inject time and external effects where tests need control. Add abstractions where a real boundary or test seam warrants them.
- Preserve state ownership and stable model identity. Retain the surrounding ObservableObject or Observation pattern; avoid broad observation migrations during an unrelated fix.
- Use main-actor isolation for UI-owned state and structured async work for I/O. MainActor does not make a workflow atomic across an await: serialize shared migrations/reconciliation, reread state after suspension, and prevent older results replacing newer ones.
- Await store loading and required migration before taking snapshots, including cold app intents and watch messages. Do not treat not-yet-loaded data as an empty history.
- Edit existing medication records without losing unrelated metadata. Persist successfully before dismissing an edit or clearing migration sources; report failure and retain recoverable input.
- Treat optional values as distinct states. Missing limits/history/units are not eligibility or medical clearance. Validate finite positive quantities and compatible units; do not infer conversions. Derived dates and visible timing must refresh as time passes.
- Cancel obsolete tasks, debounce only when appropriate, and measure hot paths before adding caches or optimizations. Keep expensive I/O out of view bodies.
- Pin and review dependencies for reproducible releases. A skill's API examples do not authorize framework migrations, target changes, or unrelated package upgrades.

For deeper SwiftUI review, optionally load [SwiftUI Expert](../skills/swiftui-expert-skill/SKILL.md). It supplements the local rules.

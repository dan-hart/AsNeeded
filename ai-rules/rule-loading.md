# Rule Loading Index

**Purpose**: Load only the guidance that matches the current task.

## Always Load

- `AGENTS.md`
- `ai-rules/general.md`

## Trigger Map

| Trigger | Load |
| --- | --- |
| Swift models, concurrency, state ownership, services, intents, watch sync, or dependency changes | `ai-rules/ios-development.md` |
| Screen flows, forms, native design critique, visual verification, or accessibility | `ai-rules/design-accessibility.md` |
| Logging, private data, export/import, networking, permissions, dependencies, signing, or security review | `ai-rules/security-privacy.md` |
| Versions, signing, archives, TestFlight, or App Store submissions | `ai-rules/release-verification.md` |
| Tests added, changed, or failing | `ai-rules/testing.md` |
| SwiftUI views, components, layout, typography, animation, accessibility, or watch UI | `ai-rules/swiftui.md` |
| Persistence, migrations, `UserDefaults`, `AppStorage`, HealthKit sync mode, `Info.plist`, or project settings that can affect stored data | `ai-rules/storage-safety.md` |
| Shell scripts, hooks, automation, CI helpers, or local setup tooling | `ai-rules/scripts.md` |
| AI workflow docs, repo guidance, research claims, or tasks where unsupported claims are a risk | `ai-rules/anti-hallucination.md` |

## Notes

- Prefer small rule files over growing `AGENTS.md`.
- Add a new rule file only after a repeated pattern or failure mode is clear.
- Keep the repo contract provider-neutral; optional tool-specific setup belongs in `docs/ai/`.

## Optional Skills

See [the curated skills index](../docs/ai/skills.md). Read local adapters before upstream examples; skill tools and discovery are optional.

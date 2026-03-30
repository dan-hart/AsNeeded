# Rule Loading Index

**Purpose**: Load only the guidance that matches the current task.

## Always Load

- `AGENTS.md`
- `ai-rules/general.md`

## Trigger Map

| Trigger | Load |
| --- | --- |
| Tests added, changed, or failing | `ai-rules/testing.md` |
| SwiftUI views, components, layout, typography, animation, accessibility, or watch UI | `ai-rules/swiftui.md` |
| Persistence, migrations, `UserDefaults`, `AppStorage`, HealthKit sync mode, `Info.plist`, or project settings that can affect stored data | `ai-rules/storage-safety.md` |
| Shell scripts, hooks, automation, CI helpers, or local setup tooling | `ai-rules/scripts.md` |
| AI workflow docs, repo guidance, research claims, or tasks where unsupported claims are a risk | `ai-rules/anti-hallucination.md` |

## Notes

- Prefer small rule files over growing `AGENTS.md`.
- Add a new rule file only after a repeated pattern or failure mode is clear.
- Keep the repo contract provider-neutral; optional tool-specific setup belongs in `docs/ai/`.

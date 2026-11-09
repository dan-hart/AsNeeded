# Development documentation

Start here for current guidance. Dated records in the archive describe earlier work and are not current specifications.

| Topic | Reference |
| --- | --- |
| Setup, contribution, and pull requests | [Contributor guide](../CONTRIBUTING.md) |
| Source ownership and target boundaries | [Architecture](architecture.md) |
| Swift packages and workflow action pins | [Dependency maintenance](dependencies.md) |
| Features and business rules | [Business rules](../BUSINESS_RULES.md) |
| Read-only development setup check | [Doctor](../scripts/README.md#read-only-environment-doctor) |
| Frozen synthetic upgrade examples | [Upgrade fixture library](../AsNeededTests/Fixtures/Upgrades/README.md) |
| Regression checks and test execution | [Scripts and testing](../scripts/README.md) |
| 1.2 behavior, upgrades, and performance | [Release regression baseline](maintenance/release-regression.md) |
| Build, signing, and artifact receipts | [Release handoff](../ai-rules/release-verification.md#local-release-handoff) |
| Storage, migration, and recovery invariants | [Storage guidelines](DATA_STORAGE_GUIDELINES.md) |
| Why storage preservation matters | [Data-loss lessons](DATA_LOSS_INCIDENT_2025.md) |
| Widgets and navigation | [Widget integration](WIDGETS_INTEGRATION.md) |
| Native materials and toolbar behavior | [Liquid Glass](LIQUID_GLASS.md) |
| Documentation/code freshness | [Drift workflow](drift.md) |
| Repository maintenance findings | [November 2026 audit](maintenance/repository-hygiene-audit-2026-11-05.md) |
| Optional agent tooling and skills | [AI guidance](ai/README.md) |
| Release assets and licenses | [Design index](../Design/README.md) |
| Earlier plans, backlog, and release evidence | [Historical archive](archive/README.md) |

The app lives under `AsNeeded/`, with feature code in `Features/` and storage in `Services/Persistence/`. The widget and Watch each have their own target folder. `AsNeededTests/` contains Swift regressions and fixtures. Developer scripts live in `scripts/`, and release artwork in `Design/`.

Keep current instructions in one authoritative place. Keep temporary prompts, plans, and draft specs in the ignored `docs/superpowers/` directory or outside the checkout. Keep raw local output outside Git. Preserve durable decisions, reproducible regression evidence, privacy-safe fixtures, and required asset/license provenance. See [documentation rules](../ai-rules/documentation.md).

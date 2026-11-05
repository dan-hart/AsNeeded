# Agent-Agnostic AI Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a portable `AGENTS.md`, small `ai-rules/` files, optional AI setup docs, and a dry-run-first Codex superpowers helper script without making any contributor workflow depend on local AI tooling.

**Architecture:** The repo's portable contract will live in `AGENTS.md` and `ai-rules/`. Provider-specific setup stays isolated in `docs/ai/` and a manual setup script. The script will be testable through `HOME` and `CODEX_HOME` overrides so its behavior can be verified without touching real local config.

**Tech Stack:** Markdown, Bash, repository docs, shell smoke tests

---

### Task 1: Add the failing smoke test for the optional setup script

**Files:**
- Create: `scripts/tests/setup-codex-superpowers.test.sh`
- Test: `scripts/tests/setup-codex-superpowers.test.sh`

- [ ] **Step 1: Write the failing test**

Create a shell smoke test that expects:

- `--help` succeeds
- default dry-run does not mutate the test home
- `--apply` creates the expected symlink
- conflicting existing paths fail safely

- [ ] **Step 2: Run the test to verify it fails**

Run: `./scripts/tests/setup-codex-superpowers.test.sh`
Expected: FAIL because `scripts/setup-codex-superpowers.sh` does not exist yet.

### Task 2: Implement the optional Codex superpowers setup script

**Files:**
- Create: `scripts/setup-codex-superpowers.sh`
- Test: `scripts/tests/setup-codex-superpowers.test.sh`

- [ ] **Step 1: Write the minimal implementation**

Implement a Bash script that:

- supports `--dry-run`, `--apply`, and `--help`
- uses `CODEX_HOME` if set, otherwise `~/.codex`
- creates `~/.agents/skills` only in `--apply` mode
- creates `~/.agents/skills/superpowers` only when missing
- exits safely when the source directory is missing or a conflicting path exists

- [ ] **Step 2: Run the smoke test**

Run: `./scripts/tests/setup-codex-superpowers.test.sh`
Expected: PASS

- [ ] **Step 3: Run syntax verification**

Run: `bash -n scripts/setup-codex-superpowers.sh scripts/tests/setup-codex-superpowers.test.sh`
Expected: PASS

### Task 3: Add portable repo guidance

**Files:**
- Modify: `AGENTS.md`
- Create: `ai-rules/general.md`
- Create: `ai-rules/rule-loading.md`
- Create: `ai-rules/testing.md`
- Create: `ai-rules/swiftui.md`
- Create: `ai-rules/storage-safety.md`
- Create: `ai-rules/scripts.md`
- Create: `ai-rules/anti-hallucination.md`

- [ ] **Step 1: Replace the duplicated draft `AGENTS.md` with a lean canonical entry point**

Keep it concise, agent-agnostic, and aligned with AsNeeded's existing conventions.

- [ ] **Step 2: Add focused rule files**

Keep each file small, concrete, and trigger-oriented.

- [ ] **Step 3: Verify rule layout**

Run: `find ai-rules -maxdepth 1 -type f | sort`
Expected: all expected rule files are present.

### Task 4: Add optional AI setup docs

**Files:**
- Create: `docs/ai/README.md`
- Create: `docs/ai/codex.md`

- [ ] **Step 1: Document the portable-vs-optional split**

Explain that repo rules are public and portable, while Codex/superpowers setup is local and optional.

- [ ] **Step 2: Document how maintainers can enable Codex locally**

Reference the setup script and the restart requirement after local setup changes.

- [ ] **Step 3: Verify paths and links**

Run: `rg -n "AGENTS.md|ai-rules|setup-codex-superpowers.sh" docs/ai AGENTS.md`
Expected: links and references resolve cleanly.

### Task 5: Final verification and review

**Files:**
- Verify: `AGENTS.md`
- Verify: `ai-rules/`
- Verify: `docs/ai/`
- Verify: `scripts/setup-codex-superpowers.sh`
- Verify: `scripts/tests/setup-codex-superpowers.test.sh`

- [ ] **Step 1: Run the targeted verification commands**

Run:

```bash
bash -n scripts/setup-codex-superpowers.sh scripts/tests/setup-codex-superpowers.test.sh
./scripts/tests/setup-codex-superpowers.test.sh
find ai-rules -maxdepth 1 -type f | sort
rg -n "agent-agnostic|optional|superpowers|rule-loading" AGENTS.md ai-rules docs/ai
```

Expected: PASS

- [ ] **Step 2: Run repository code review**

Run: any optional external review helper you use locally
Expected: if the tool completes, capture the output and address any actionable issues it surfaces.

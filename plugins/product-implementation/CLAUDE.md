# product-implementation CLAUDE.md

Plugin-specific guidance for Claude Code when working in this plugin.

## Plugin Purpose

Configures projects so Claude Code can autonomously implement development plans produced by product-planning. Instead of orchestrating implementation directly, this plugin sets up the project *environment* — knowledge, hooks, progress tracking, evaluation criteria, external reviewers — so the model works effectively within well-designed constraints.

## Workflow Chain Position

Product Definition (PRD, spec) → Product Planning (design, plan, tasks, test-plan) → **Product Implementation** (harness setup → autonomous coding sessions)

## Architecture

### Harness Configurator (v5.0 — current)

`skills/harness/SKILL.md` is the primary entry point. Three-stage workflow:

1. **Analyze & Interview** — Read plan artifacts, analyze project, detect domain, ask user preferences
2. **Configure Harness** — Generate 6 categories of environment components:
   - Knowledge Store (CLAUDE.md, ARCHITECTURE.md)
   - Enforcement Layer (hooks in settings.json, lint scripts)
   - Evaluation Criteria & Loop (gradable dimensions, evaluator prompt, external CLI review, interactive UAT)
   - Progress Tracking (feature-list.json, progress.md, session-startup.md)
   - Tooling Setup (MCP servers, skills, CLI agents — Codex/Gemini)
   - Workflow Guide (sprint contracts, iteration pattern)
3. **Verify & Hand Off** — Test hooks, present summary, suggest first sprint

After the harness is configured, Claude Code executes the plan naturally — one feature at a time, fresh context per session, progress tracked via JSON contract.

### Legacy: Bash Orchestrator (v4.0)

`scripts/implement-android.sh` is the previous orchestrator approach, retained for reference and direct script usage. Two-level architecture:

- **Bash** (inter-phase, deterministic): parse tasks.md, probe MCPs, build verification, commit per phase
- **Claude** (`claude -p`, fresh context per phase): TDD cycles, subagent dispatch, Figma handoff, iteration

### Agent Assignments

- **test-writer** (`agents/test-writer.md`): model=sonnet — unit test spec-to-test translation, Red phase TDD
- **integration-test-writer** (`agents/integration-test-writer.md`): model=sonnet — E2E/integration test specialist
- **developer** (`agents/developer.md`): model=sonnet — generic implementation (fallback vertical)
- **android-developer** (`agents/android-developer.md`): model=sonnet — Android/Kotlin/Compose specialist
- **frontend-developer** (`agents/frontend-developer.md`): model=sonnet — Frontend/web specialist
- **backend-developer** (`agents/backend-developer.md`): model=sonnet — Backend/API/database specialist
- **debugger** (`agents/debugger.md`): model=sonnet — systematic bug diagnosis (UNDERSTAND→REPRODUCE→ISOLATE→FIX)
- **output-verifier** (`agents/output-verifier.md`): model=sonnet — test body quality, spec alignment, DoD compliance
- **code-simplifier** (`agents/code-simplifier.md`): model=sonnet — code clarity and maintainability
- **uat-tester** (`agents/uat-tester.md`): model=sonnet — UAT mobile testing via SAV loop, Figma visual parity
- **doc-judge** (`agents/doc-judge.md`): model=sonnet — documentation accuracy verification (LLM-as-a-judge)
- **tech-writer** (`agents/tech-writer.md`): model=sonnet — feature documentation, API guides, architecture updates
- **test_augmenter (script)**: dual-model test gap analysis via `scripts/dispatch-test-augmenter.sh`

### Key Files

**Harness skill (current):**
- `skills/harness/SKILL.md` — Harness configurator entry point (~224 lines)
- `skills/harness/references/harness-components.md` — Templates for 6 harness categories + quality score + entropy management
- `skills/harness/references/evaluation-loop.md` — Evaluation loop: UAT testing, judging, feedback protocol
- `skills/harness/references/feature-list-schema.md` — JSON contract schema and conversion
- `skills/harness/references/hooks-catalog.md` — Hook catalog: essential, architecture guards, entropy management, custom
- `skills/harness/references/cli-agents.md` — External CLI agent (Codex/Gemini) dispatch: review + UAT

**Legacy orchestrator (retained):**
- `scripts/implement-android.sh` — Bash orchestrator
- `skills/implement/SKILL.md` — LLM orchestrator skill wrapper
- `skills/implement/references/developer-core-instructions.md` — Shared engineering process (still used by agents)
- `config/implementation-config.yaml` — User-facing settings (~45 lines)
- `config/profile-definitions.yaml` — Internal profile definitions, domain mapping, vertical agents
- `config/cli_clients/shared/` — CLI instruction content for AGENTS.md/GEMINI.md
- `scripts/dispatch-cli-agent.sh` — CLI agent dispatch with output extraction

### Required Input Artifacts

The script expects these files in the feature directory (produced by product-planning):
- `tasks.md` (required) — phased task list with acceptance criteria
- `plan.md` (required) — implementation plan
- `design.md`, `test-plan.md` (optional — used for richer agent context)
- `test-cases/` (optional) — test specifications by level (e2e, integration, unit, uat)

## Dev-Skills Integration

Vertical developer agents use domain-specific skills via progressive disclosure — skills are baked into agent `.md` files, not injected at runtime.

### Vertical Agent Auto-Detection

The script scans `tasks.md`, `plan.md`, and `design.md` for domain indicators:

| Domain | Indicators | Agent | Key Skills |
|--------|-----------|-------|------------|
| Android | `.kt`, `Kotlin`, `Compose`, `ViewModel`, `gradle` | `android-developer` | kotlin-expert, compose-expert, android-expert |
| Frontend | `.tsx`, `.jsx`, `.vue`, `React`, `Next.js`, `CSS` | `frontend-developer` | frontend-design, accessibility-auditor |
| Backend | `endpoint`, `route`, `REST`, `GraphQL`, `database` | `backend-developer` | api-patterns, database-schema-designer |
| *(fallback)* | — | `developer` | clean-code |

Override with `--vertical-agent TYPE`.

### Key Constraints

- **Progressive disclosure** — agents read skill SKILL.md files in 2 phases: first 50 lines for decision framework, then grep for specific sections on-demand
- **Shared core** — all developer-family agents read `references/developer-core-instructions.md`
- **Codebase conventions take precedence** — CLAUDE.md and constitution.md override skill guidance
- **Graceful degradation** — if dev-skills not installed, agents proceed without domain skills

## CLI Instruction File Management

The script manages AGENTS.md (Codex) and GEMINI.md (Gemini) at PROJECT_ROOT via marker-based idempotent lifecycle.

Source files (single source of truth) live in `config/cli_clients/shared/`:
- `cli-instruction-shared.md` — Universal content (output standards, severity classification)
- `codex-instruction-extra.md` — Codex-specific (parallelism, plan tool suppression)
- `gemini-instruction-extra.md` — Gemini-specific (context window usage)

Managed sections delimited by `<!-- pi-codex-begin/end -->` and `<!-- pi-gemini-begin/end -->` markers. User content outside markers is preserved. Lifecycle: file missing → create; marker missing → append; marker found → compare & update.

## UAT Mobile Testing

The script supports UAT mobile testing for UI phases when an emulator is available.

- **Phase relevance**: UAT runs only for phases with UI tasks (detected via domain indicators)
- **Evidence stored**: Screenshots saved to `{FEATURE_DIR}/.uat-evidence/{phase_name}/`
- **Write boundaries**: UAT agent writes ONLY screenshots; never touches source/test/spec files
- **Figma pre-export**: Reference PNGs exported via `scripts/uat/capture-figma-refs.sh`
- **Scripts are standalone**: `run-uat.sh` and `capture-figma-refs.sh` can be used independently

## Project Setup

One-time Claude session (gated by marker file) that configures the project for optimal Claude Code usage:
- Generates hooks: `protect-specs.sh`, `tdd-reminder.sh`, `safe-bash.sh`
- Augments CLAUDE.md with build commands, architecture, conventions
- Updates `.claude/settings.json` with hook registrations (backup first)
- Append-only: never overwrites existing content

Skip with `--no-setup`.

## Development Notes

- User-facing settings live in `config/implementation-config.yaml` (~45 lines). Profile definitions in `config/profile-definitions.yaml`.
- Cross-plugin naming: product-planning produces `contract.md` (singular), `test-cases/uat/` (not `visual/`), and test IDs like `E2E-*`, `INT-*`, `UT-*`, `UAT-*` — always verify against the source plugin before adding new artifact references
- CLI dispatch script (`scripts/dispatch-cli-agent.sh`) supports `--model` and `--effort` flags for per-role overrides. Configurable via `cli.codex_model` and `cli.codex_effort` in config.
- The script builds prompts inline; `references/agent-prompts.md` is from the legacy LLM orchestrator
- Only `references/developer-core-instructions.md` is actively used by agents at runtime

## Legacy LLM Orchestrator

The `skills/implement/references/` directory contains ~23 files from the previous LLM-driven orchestrator (v3.6.0): `orchestrator-loop.md`, `stage-{1-6}-*.md`, `agent-prompts.md`, `summary-schemas.md`, etc. These coordinator instruction files are **not used by the script** but retained for:

- Historical reference of the patterns the script implements
- The `ralph-implement` command, which still invokes the old orchestrator workflow

### Ralph Loop (Legacy)

`/product-implementation:ralph-implement` invokes the old LLM orchestrator inside a ralph loop for autonomous execution. It depends on the legacy reference files. To migrate ralph to the script-based approach, the ralph-implement command would need to invoke `implement-android.sh` instead of the implement skill.

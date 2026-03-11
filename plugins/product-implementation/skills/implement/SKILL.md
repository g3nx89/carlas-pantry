---
name: feature-implementation
description: |
  This skill should be used when the user asks to "implement the feature", "execute the tasks",
  "run the implementation plan", "continue implementation", "resume implementation",
  "execute the plan", or needs to execute tasks defined in tasks.md.
  Runs implement-android.sh for per-phase implementation with session-isolated Claude sessions.
version: 4.0.0
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
---

# Implement Feature Skill

> **Primary tool:** `$CLAUDE_PLUGIN_ROOT/scripts/implement-android.sh`

Support layer for the Bash orchestrator that implements features phase-by-phase using session-isolated `claude -p` calls. Each phase gets a fresh context window, eliminating cross-phase context accumulation.

## When Invoked

1. **Locate the feature directory** — find `tasks.md` in the current project. Ask the user if ambiguous.
2. **Determine the project root** — the git root containing the source code to implement against.
3. **Ask the user** for execution preferences:
   - Which phases to run? All, or a range via `--start-from` / `--stop-after`
   - Figma design handoff? Provide `--figma-url`, `--figma-key`, or `--figma-file`
   - Pipeline toggles? `--minimal`, `--no-review`, `--no-uat`, etc.
4. **Construct and run** the script via Bash tool:

```bash
"$CLAUDE_PLUGIN_ROOT/scripts/implement-android.sh" \
  --feature-dir <FEATURE_DIR> \
  --project-root <PROJECT_ROOT> \
  [options...]
```

5. **Monitor output** — the script prints progress per phase. Report results to user when done.

## Quick Start Examples

```bash
# Basic — all phases, auto-detect project type
./scripts/implement-android.sh \
  --feature-dir ~/project/docs/specs \
  --project-root ~/project

# Android project with Figma (paste URL from browser)
./scripts/implement-android.sh \
  --feature-dir ~/project/docs/specs \
  --project-root ~/project \
  --figma-url 'https://www.figma.com/design/abc123/MyApp'

# Single phase, fast
./scripts/implement-android.sh \
  --feature-dir ~/project/docs/specs \
  --project-root ~/project \
  --start-from B --stop-after B --minimal

# Dry run — show plan without executing
./scripts/implement-android.sh \
  --feature-dir ~/project/docs/specs \
  --project-root ~/project \
  --dry-run
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Bash (inter-phase, deterministic)                   │
│  ─ parse phases from tasks.md                        │
│  ─ probe MCPs (Codex, Gemini, Figma)                 │
│  ─ CLI instruction files (AGENTS.md, GEMINI.md)      │
│  ─ project setup (hooks, CLAUDE.md, settings.json)   │
│  ─ Figma screenshot export                           │
├─────────────────────────────────────────────────────┤
│  FOR EACH PHASE:                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ claude -p  (fresh context per phase)             │ │
│  │  Step 1: TDD — test-writer → vertical-agent     │ │
│  │           → output-verifier → build check        │ │
│  │  Step 2: Code simplification → build check       │ │
│  │  Step 3: UAT mobile testing (UI phases only)     │ │
│  │  Step 4: Quality gate                            │ │
│  │    4a. Test augmentation (Gemini→Codex)           │ │
│  │    4b. Native review (3 perspectives)             │ │
│  │    4c. CLI review (Codex/Gemini)                  │ │
│  │    4d. Fix Critical/High findings                 │ │
│  └─────────────────────────────────────────────────┘ │
│  Build verify → Auto-commit with task changelog      │
└─────────────────────────────────────────────────────┘
```

Each `claude -p` call gets `--plugin-dir` so all plugin agents are available as subagent types. Agent `.md` files contain baked-in skill references (dev-skills, meta-skills) loaded via progressive disclosure.

## Script Options

| Flag | Default | Description |
|------|---------|-------------|
| `--feature-dir DIR` | *(required)* | Feature spec directory (contains tasks.md, plan.md) |
| `--project-root DIR` | *(required)* | Project root directory |
| `--model MODEL` | `claude-sonnet-4-20250514` | Model for implementation sessions |
| `--vertical-agent TYPE` | *(auto-detected)* | Agent override: `android-developer`, `frontend-developer`, `backend-developer`, `developer` |
| `--timeout SECS` | `1200` | Timeout per phase session |
| `--permission-mode MODE` | `plan` | Claude permission mode |
| `--mcp-config PATH` | — | Additional MCP server config file |
| `--figma-key KEY` | — | Figma file key (direct) |
| `--figma-url URL` | — | Figma URL (key extracted automatically, zero cost) |
| `--figma-file NAME` | — | Figma file name (resolved via MCP, costs 1 haiku call) |
| `--figma-page NAME` | — | Figma page name for screenshot export |
| `--start-from PHASE` | — | Start from phase ID (e.g., `B`) |
| `--stop-after PHASE` | — | Stop after phase ID |
| `--no-commit` | — | Disable auto-commit per phase |
| `--no-simplify` | — | Disable code simplification |
| `--no-uat` | — | Disable UAT mobile testing |
| `--no-review` | — | Disable multi-model review |
| `--no-augment` | — | Disable test augmentation |
| `--no-setup` | — | Skip project setup (hooks, CLAUDE.md, CLI files) |
| `--minimal` | — | Disable all optional steps (only TDD + build + commit) |
| `--dry-run` | — | Show plan without executing |

## Vertical Agent Auto-Detection

The script scans `tasks.md`, `plan.md`, and `design.md` for domain indicators:

| Domain | Indicators | Agent |
|--------|-----------|-------|
| Android | `AndroidManifest`, `.kt`, `Kotlin`, `Composable`, `Compose`, `ViewModel`, `gradle` | `android-developer` |
| Frontend | `.tsx`, `.jsx`, `.vue`, `.svelte`, `React`, `Next.js`, `CSS`, `HTML` | `frontend-developer` |
| Backend | `endpoint`, `route`, `controller`, `REST`, `GraphQL`, `database`, `schema`, `migration` | `backend-developer` |
| *(fallback)* | — | `developer` |

Override with `--vertical-agent TYPE`.

## Pre-Phase Setup

Before the phase loop, the script runs one-time setup (skippable via `--no-setup`):

1. **MCP probing** — Detects Codex CLI, Gemini CLI, Figma MCP availability via `which` and Python JSON parsing
2. **CLI instruction files** — Creates/updates `AGENTS.md` and `GEMINI.md` at `PROJECT_ROOT` with marker-based idempotent sections (`<!-- pi-codex-begin/end -->`)
3. **Project setup** — One-time Claude session generating hooks (`protect-specs.sh`, `tdd-reminder.sh`, `safe-bash.sh`), augmenting CLAUDE.md, updating `.claude/settings.json`. Gated by marker file in log dir.
4. **Figma screenshot export** — Runs `capture-figma-refs.sh` when Figma key is provided

## Required Input Files

| File | Required | Source |
|------|----------|--------|
| `tasks.md` | **Yes** | `/product-planning:tasks` |
| `plan.md` | **Yes** | `/product-planning:plan` |
| `design.md` | No | `/product-planning:design` |
| `test-plan.md` | No | `/product-planning:test-plan` |
| `test-cases/` | No | `/product-planning:test-plan` |

## Agents

All agents are defined in `$CLAUDE_PLUGIN_ROOT/agents/` and available via `--plugin-dir`.

| Agent | Role | Pipeline Step |
|-------|------|---------------|
| `test-writer` | Unit test spec-to-test translation (Red phase TDD) | Step 1 |
| `integration-test-writer` | E2E/integration test specialist | Step 1 |
| `android-developer` | Android/Kotlin/Compose implementation (vertical) | Step 1 |
| `frontend-developer` | Frontend/web implementation (vertical) | Step 1 |
| `backend-developer` | Backend/API/database implementation (vertical) | Step 1 |
| `developer` | Generic implementation (fallback vertical) | Steps 1, 4 |
| `debugger` | Systematic bug diagnosis (UNDERSTAND→REPRODUCE→ISOLATE→FIX) | Step 3 |
| `output-verifier` | Test body quality, spec alignment, DoD compliance | Step 1 |
| `code-simplifier` | Code clarity and maintainability | Step 2 |
| `uat-tester` | UAT mobile testing via SAV loop, Figma visual parity | Step 3 |
| `tech-writer` | Feature documentation, API guides | *(manual)* |
| `doc-judge` | Documentation accuracy verification (LLM-as-a-judge) | *(manual)* |

Developer-family agents (developer, android-developer, frontend-developer, backend-developer, debugger) read `$CLAUDE_PLUGIN_ROOT/skills/implement/references/developer-core-instructions.md` for shared engineering process and quality standards.

## Configuration

| File | Purpose |
|------|---------|
| `config/implementation-config.yaml` | User-facing settings (~45 lines): profile, autonomy, project overrides |
| `config/profile-definitions.yaml` | Internal: profile definitions, domain mapping, vertical agent rules |
| `config/cli_clients/shared/` | Shared CLI instruction content (written into AGENTS.md/GEMINI.md) |
| `config/cli_clients/*.json` | Per-CLI-role configuration (model, effort, timeout) |

## Output Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Phase commits | git history | One commit per phase with task-based changelog |
| Review findings | `{FEATURE_DIR}/.review-findings-phase-*.md` | Consolidated findings per phase |
| UAT evidence | `{FEATURE_DIR}/.uat-evidence/` | Screenshots organized by phase |
| Session logs | `{FEATURE_DIR}/.implement-logs/` | All prompts, session outputs, review files |
| AGENTS.md | `{PROJECT_ROOT}/AGENTS.md` | CLI instruction file (Codex) |
| GEMINI.md | `{PROJECT_ROOT}/GEMINI.md` | CLI instruction file (Gemini) |
| Hooks | `{PROJECT_ROOT}/.claude/hooks/` | protect-specs.sh, tdd-reminder.sh, safe-bash.sh |

## Severity Levels

| Severity | Description |
|----------|-------------|
| **Critical** | Breaks functionality, security vulnerability, data loss risk |
| **High** | Likely to cause bugs, significant code quality issue |
| **Medium** | Code smell, maintainability concern, minor pattern violation |
| **Low** | Style preference, minor optimization opportunity |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Script exits with "tasks.md not found" | Ensure `--feature-dir` points to directory containing `tasks.md` |
| No phases parsed | Check `tasks.md` has `## Phase X: Name` headers |
| Wrong vertical agent detected | Override with `--vertical-agent android-developer` |
| Codex/Gemini not detected | Ensure `codex` / `gemini` are in PATH. Script probes via `which`. |
| Figma MCP not available | Start Figma desktop app + figma-console MCP. Or use `--figma-url` for URL-only key extraction |
| Phase timeout | Increase with `--timeout 1800` (default: 1200s = 20min) |
| Build failures loop | Script attempts auto-fix once per build check. If build still fails, phase continues. Check logs. |
| `--figma-file` resolves wrong key | Use `--figma-url` instead (zero-cost URL parsing, no MCP needed) |

## Related Scripts

| Script | Purpose |
|--------|---------|
| `scripts/implement-android.sh` | Main orchestrator (this skill's primary tool) |
| `scripts/uat/capture-figma-refs.sh` | Figma REST API screenshot exporter |
| `scripts/uat/run-uat.sh` | CLI engine dispatch for UAT scenarios |
| `scripts/dispatch-cli-agent.sh` | CLI agent dispatch with 4-tier output extraction |
| `scripts/dispatch-test-augmenter.sh` | Dual-model test gap analysis (Gemini→Codex) |

## Active References

| File | Used By | Content |
|------|---------|---------|
| `references/developer-core-instructions.md` | 5 developer-family agents | Shared engineering process, quality standards, verification rules |

## Legacy LLM Orchestrator

The `references/` directory contains ~23 additional files from the previous LLM-driven orchestrator (v3.6.0). These coordinator instruction files (`stage-*.md`, `orchestrator-loop.md`, `agent-prompts.md`, etc.) are **not used by the script** but are retained for:

- Historical reference of the patterns the script implements
- The `ralph-implement` command, which still invokes the old orchestrator workflow

If fully migrating away from the LLM orchestrator, these files and the `templates/` directory (except `ralph-implement-prompt.md`) can be archived or removed.

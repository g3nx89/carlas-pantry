---
name: feature-implementation
description: |
  This skill should be used when the user asks to "implement the feature", "execute the tasks",
  "run the implementation plan", "continue implementation", "resume implementation",
  "execute the plan", "document the feature",
  or needs to execute tasks defined in tasks.md. Orchestrates stage-by-stage implementation
  using developer agents with TDD, progress tracking, integrated quality review, and feature
  documentation.
version: 3.0.0
allowed-tools:
  # File operations
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  # Shell commands
  - Bash(git:*)
  - Bash(mkdir:*)
  - Bash(ls:*)
  # Agent orchestration
  - Task
  - AskUserQuestion
  # Mobile MCP tools (conditional — for UAT emulator probe in Stage 1)
  - mcp__mobile-mcp__mobile_list_available_devices
  - mcp__mobile-mcp__mobile_install_app
  - mcp__mobile-mcp__mobile_launch_app
  - mcp__mobile-mcp__mobile_terminate_app
  - mcp__mobile-mcp__mobile_uninstall_app
  # Research MCP tools (conditional — graceful fallback when unavailable)
  - mcp__Ref__ref_search_documentation
  - mcp__Ref__ref_read_url
  - mcp__context7__resolve-library-id
  - mcp__context7__query-docs
  - mcp__tavily__tavily_search
---

# Implement Feature Skill — Lean Orchestrator

> **Invoke:** `/product-implementation:implement` or ask "implement this feature"

Execute the implementation plan by processing all tasks defined in `tasks.md`, stage by stage. This orchestrator delegates stages to coordinator subagents, reading only standardized summary files between stages.

> CRITICAL: Read and internalize the Critical Rules below before any action.

## Critical Rules

1. **Context First** — Read ALL required spec files before launching any agent. Missing context = hallucinated code.
2. **Stage Order** — Complete each stage fully before starting the next. Never skip stages.
3. **TDD Enforcement** — Developer agents follow test-first approach. Tests before implementation, always.
4. **Progress Tracking** — Mark tasks `[X]` in tasks.md after completion. Uncommitted progress = lost progress.
5. **Error Halting** — Sequential task failure halts the phase. Parallel `[P]` tasks: continue others, report failures.
6. **State Persistence** — Checkpoint after each stage in `.implementation-state.local.md`.
7. **User Decisions are Final** — Quality review and documentation decisions are immutable once saved.
8. **No Spec Changes** — DO NOT create or modify specification files during implementation.
9. **Lock Protocol** — Acquire lock at start, release at completion. Check for stale locks (>60 min per `config/implementation-config.yaml`).
10. **Delegation Protocol** — Delegated stages execute via `Task(subagent_type="general-purpose")` coordinators. Stage 1 is inline. See dispatch table below.
11. **Summary-Only Context** — Between stages, read ONLY summary files from `{FEATURE_DIR}/.stage-summaries/`. Never read full reference files or raw artifacts in orchestrator context.
12. **No User Interaction from Coordinators** — Coordinators set `status: needs-user-input` in their summary. The orchestrator mediates ALL user prompts via `AskUserQuestion`.

## Workflow Overview

```
┌──────────────────────────────────────────────────────┐
│              IMPLEMENTATION WORKFLOW                   │
├──────────────────────────────────────────────────────┤
│                                                       │
│  ┌───────────┐                                        │
│  │  Stage 1  │  Setup & Context Loading  (inline)     │
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │  Stage 2  │  Phase-by-Phase Execution (coordinator)│
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │  Stage 3  │  Completion Validation    (coordinator)│
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │  Stage 4  │  Quality Review           (coordinator)│
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │  Stage 5  │  Feature Documentation    (coordinator)│
│  └─────┬─────┘                                        │
│        ↓        lock released ↑                       │
│  ┌───────────┐                                        │
│  │  Stage 6  │  Implementation Retrospective (coord.) │
│  └───────────┘                                        │
│                                                       │
└──────────────────────────────────────────────────────┘
```

## Latency Trade-off

Each coordinator dispatch adds ~5-15s overhead. This is the trade-off for significant orchestrator context reduction and fault isolation. Stage 1 is inline to avoid overhead for lightweight setup. When `code_simplification.enabled` is `true`, each phase adds an additional code-simplifier dispatch (~5-15s overhead + 30-120s execution). This is the trade-off for cleaner downstream code, reduced review noise in Stage 4, lower token cost for future maintenance, and improved LLM comprehension.

## Stage Dispatch Table

| Stage | Delegation | Reference File | Agents Used | Prior Summaries | User Interaction | Checkpoint |
|-------|-----------|----------------|-------------|-----------------|------------------|------------|
| 1 | Inline | `stage-1-setup.md` | — | — | Policy question (1.9a) | SETUP |
| 2 | Coordinator | `stage-2-execution.md` | `developer`, `code-simplifier`, `uat-tester (CLI/gemini)` | stage-1 | Auto-resolve per policy (build/test) | EXECUTION |
| 3 | Coordinator | `stage-3-validation.md` | `developer` | stage-1, stage-2 | Auto-resolve per policy (validation) | VALIDATION |
| 4 | Coordinator | `stage-4-quality-review.md` | `developer` x3+ (Tier A, with optional stances/convergence/CoVe), plugin (Tier B), CLI (Tier C) | stage-2, stage-3 | Auto-resolve per policy (findings) | QUALITY_REVIEW |
| 5 | Coordinator | `stage-5-documentation.md` | `developer`, `tech-writer` | stage-3, stage-4 | Auto-resolve per policy (tasks, docs) | DOCUMENTATION |
| 6 | Coordinator | `stage-6-retrospective.md` | `tech-writer` | stage-1 through stage-5 | None | RETROSPECTIVE |

All reference files are in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/`.

> **Note:** "Agents Used" refers to plugin agents defined in `agents/` (developer, code-simplifier, tech-writer). CLI roles (Codex, Gemini, OpenCode) are dispatched by coordinators via `scripts/dispatch-cli-agent.sh` and are not listed here — see `references/integrations-overview.md` for CLI dispatch details.

## Orchestrator Loop

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/orchestrator-loop.md`

The loop reads state → dispatches stages in order → reads summaries → handles user interaction → updates state. It includes crash recovery, summary validation, and v1-to-v2 state migration.

## Stage 1 (Inline)

Execute Stage 1 inline. Read `$CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-1-setup.md` for full instructions. After completion, write Stage 1 summary to `{FEATURE_DIR}/.stage-summaries/stage-1-summary.md`.

## Summary Convention

- **Path:** `{FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md`
- **Template:** `$CLAUDE_PLUGIN_ROOT/templates/stage-summary-template.md`
- **Size:** 20-60 lines (YAML frontmatter + markdown); Stage 1 may reach ~120-130 lines due to context loading duties; Stage 6 ~40 lines
- **Required YAML fields:** `stage`, `status`, `checkpoint`, `artifacts_written`, `summary`
- **Critical section:** "Context for Next Stage" — this is what the next coordinator reads to understand state

## State Management

State persisted in `{FEATURE_DIR}/.implementation-state.local.md` (version 2):
- YAML frontmatter tracks stage, decisions, stage_summaries, orchestrator metadata
- Markdown body contains human-readable log
- Immutable fields: `user_decisions`
- Migration: If `version: 1`, see `orchestrator-loop.md` for auto-migration to v2

**Template:** `$CLAUDE_PLUGIN_ROOT/templates/implementation-state-template.local.md`

### Stage-Level Resume

On resume, use `current_stage`, `stage_summaries`, and `user_decisions` to determine the correct entry point:
- If `current_stage` < 2 → start from Stage 1
- If `current_stage` = 2 → resume from first phase in `phases_remaining`
- If `current_stage` = 3 and `user_decisions.validation_outcome` exists:
  - If value is `"stopped"` → halt (user previously chose to stop)
  - Otherwise → skip to Stage 4
- If `current_stage` = 4 and `user_decisions.review_outcome` exists → skip to Stage 5
- If `current_stage` = 5 and `user_decisions.documentation_outcome` exists → skip to Stage 6
- If `current_stage` = 6:
  - If `stage_summaries["6"]` exists → already complete, report status
  - Else → run Stage 6

Stage completion is derived from `stage_summaries` (non-null = completed). The `current_stage` field tracks the next stage to execute.

## Agents

| Agent | Role | Used In |
|-------|------|---------|
| `product-implementation:developer` | Implementation, testing, validation, review | Stages 2, 3, 4, 5 |
| `product-implementation:code-simplifier` | Code simplification, clarity, maintainability | Stage 2 |
| `product-implementation:tech-writer` | Feature documentation, API guides, architecture updates, retrospective | Stages 5, 6 |

## Severity Levels (Canonical)

Canonical definitions — sourced from `config/implementation-config.yaml`:

| Severity | Description |
|----------|-------------|
| **Critical** | Breaks functionality, security vulnerability, data loss risk |
| **High** | Likely to cause bugs, significant code quality issue |
| **Medium** | Code smell, maintainability concern, minor pattern violation |
| **Low** | Style preference, minor optimization opportunity |

## Output Artifacts

### Primary Artifacts (always produced)

| Artifact | Content |
|----------|---------|
| `tasks.md` | Updated with `[X]` marks for all completed tasks |
| `.implementation-state.local.md` | Execution state, stage tracking, and implementation log |
| `.stage-summaries/` | Inter-stage coordinator summary files |
| Git commits | Auto-commits at phase completion (Stage 2, with simplified code when enabled), review fix (Stage 4), documentation (Stage 5), and retrospective (Stage 6). Controlled by `auto_commit` and `code_simplification` in config. |

### Conditional Artifacts (gated by config or findings)

| Artifact | Gate | Content |
|----------|------|---------|
| `review-findings.md` | Findings exist AND outcome is "fix now" or "fix later" | Quality review findings |
| `docs/` | Stage 5 runs | Feature documentation, API guides, architecture updates |
| Module `README.md` files | Stage 5 runs | Updated READMEs in folders affected by implementation |
| `.uat-evidence/` | UAT enabled + relevant phases | UAT screenshots organized by phase |
| `retrospective.md` | Stage 6 runs | Implementation retrospective narrative with KPI analysis |
| `.implementation-report-card.local.md` | Stage 6 runs (excluded from auto-commit) | Machine-readable KPI Report Card |

## Integration Architecture

All integrations are orchestrator-transparent. Full details: `references/integrations-overview.md`.

| Integration | Summary |
|-------------|---------|
| Dev-Skills | Domain-specific skill references, capped at 3 per dispatch |
| Research MCP | Documentation context from Ref/Context7/Tavily, budget-controlled |
| CLI Dispatch | Multi-model dispatch via Codex/Gemini/OpenCode, opt-in per option |
| Autonomy Policy | Auto-resolution: full_auto, balanced, critical_only. Selected at Stage 1 |

## Reference Map

> Read only the reference file needed for the current stage. Do not preload all stage files.

| File | When to Read | Content |
|------|-------------|---------|
| `references/orchestrator-loop.md` | Workflow start (always) | Dispatch loop, crash recovery, state migration, context packs |
| `references/integrations-overview.md` | When understanding integration architecture | Dev-Skills, Research MCP, CLI Dispatch, Autonomy Policy — full detail |
| `references/stage-1-setup.md` | Stage 1 (inline) | Branch parsing, file loading, lock, state init, domain detection |
| `references/stage-2-execution.md` | Stage 2 (coordinator) | Skill resolution, phase loop, task parsing, error handling |
| `references/stage-2-uat-mobile.md` | Stage 2 (coordinator, conditional) | UAT mobile testing gate check, APK build/install, CLI dispatch, result processing |
| `references/stage-3-validation.md` | Stage 3 (coordinator) | Task completeness, spec alignment, test coverage, test quality gate |
| `references/stage-4-quality-review.md` | Stage 4 (coordinator) | Three-tier review, stances, convergence, confidence scoring, CoVe, auto-decision |
| `references/stage-4-plugin-review.md` | Stage 4 (coordinator reads) | Tier B: Plugin-based review via code-review skill, finding normalization |
| `references/stage-4-cli-review.md` | Stage 4 (coordinator reads) | Tier C: CLI multi-model review, Phase 1/2 dispatch, pattern search, UX/accessibility review |
| `references/stage-5-documentation.md` | Stage 5 (coordinator) | Skill resolution for docs, tech-writer dispatch, lock release |
| `references/agent-prompts.md` | Stages 2-6 (coordinator reads) | 9 prompt templates with Common Variables, section markers, fallback annotations |
| `references/auto-commit-dispatch.md` | Stages 2, 4, 5, 6 (coordinator reads) | Shared auto-commit procedure, exclude patterns, batch strategy |
| `references/autonomy-policy-procedure.md` | Stages 2-5 (coordinator reads) | Shared autonomy policy check, per-severity iteration, fallback escalation |
| `references/skill-resolution.md` | Stages 2, 4, 5 (coordinator reads) | Shared skill resolution algorithm for domain-specific skill injection |
| `references/cli-dispatch-procedure.md` | Stages 2, 3, 4, 5 (coordinator reads) | Shared CLI dispatch, timeout, parsing, circuit breaker, fallback |
| `references/summary-schemas.md` | When adding/modifying summary fields | YAML schemas for all 6 stage summaries, producer/consumer mapping |
| `references/stage-6-retrospective.md` | Stage 6 (coordinator) | KPI Report Card, transcript extraction, retrospective composition |

## Error Handling

- **Missing tasks.md** — Halt with guidance: "Run `/product-planning:tasks` first"
- **Missing plan.md** — Halt with guidance: "Run `/product-planning:plan` first"
- **Empty tasks.md** — Halt with guidance: "tasks.md has no parseable phases"
- **Missing expected files** — Warning only (no halt). `design.md` and `test-plan.md` are expected but not required; their absence is logged so the user is aware of reduced context
- **Lock conflict** — Check timestamp; override if stale, otherwise halt with guidance
- **Interrupted execution** — Resume from checkpoint via state file
- **Coordinator crash** — See `orchestrator-loop.md` for crash recovery and summary reconstruction
- **Auto-commit failure** — Warning only (no halt). Commit subagent failures are logged and skipped; changes remain on disk and will be included in subsequent commits

## Quick Start

1. Ensure `{FEATURE_DIR}/tasks.md` and `plan.md` exist (run `/product-planning:plan` then `/product-planning:tasks`)
2. Optional: verify `design.md`, `test-plan.md`, `test-strategy.md`, and `test-cases/` are present for richer agent context
3. **Top 5 config toggles** (in `config/implementation-config.yaml`):
   - `autonomy_policy.default_level` — set to skip the startup question (`full_auto` / `balanced` / `critical_only`)
   - `code_simplification.enabled` — enable post-phase code simplification
   - `dev_skills.enabled` — enable domain-specific skill injection
   - `research_mcp.enabled` — enable MCP-backed documentation context
   - `cli_dispatch` — enable external CLI agent dispatch (per-option)
4. Run `/product-implementation:implement`
5. Choose autonomy policy when prompted (skipped if `default_level` is set)
6. Monitor stage-by-stage progress (interruptions depend on chosen policy)
7. Review documentation updates generated by tech-writer
8. Review `retrospective.md` and `.implementation-report-card.local.md` for implementation analysis

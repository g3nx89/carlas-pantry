---
name: feature-implementation
description: |
  This skill should be used when the user asks to "implement the feature", "execute the tasks",
  "run the implementation plan", "continue implementation", "resume implementation",
  "execute the plan", "document the feature",
  or needs to execute tasks defined in tasks.md. Orchestrates stage-by-stage implementation
  using developer agents with TDD, progress tracking, integrated quality review, and feature
  documentation.
version: 3.3.0
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
  # Figma MCP tools (conditional — design handoff, spec extraction, parity checks)
  - mcp__figma-console__figma_get_status
  - mcp__figma-console__figma_get_component_for_development
  - mcp__figma-console__figma_check_design_parity
  - mcp__figma-console__figma_get_component_image
  - mcp__figma-console__figma_capture_screenshot
  - mcp__figma-console__figma_search_components
  - mcp__figma-console__figma_get_selection
  - mcp__figma-console__figma_get_variables
  - mcp__figma-console__figma_get_styles
  - mcp__figma-console__figma_get_component_details
  - mcp__figma-console__figma_get_design_system_summary
  - mcp__figma-console__figma_get_component
  - mcp__figma-console__figma_audit_design_system
  - mcp__figma-console__figma_execute
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
12. **No User Interaction from Coordinators** — Coordinators set `status: needs-user-input` in their summary. The orchestrator mediates ALL user prompts via `SAFE_ASK_USER` (validates non-empty responses, retries on widget failures). In ralph mode, auto-resolve guard intercepts before SAFE_ASK_USER.

## Workflow Overview

```
┌──────────────────────────────────────────────────────┐
│              IMPLEMENTATION WORKFLOW                   │
├──────────────────────────────────────────────────────┤
│  ┌───────────┐                                        │
│  │  Stage 1  │  Setup & Context Loading  (inline)     │
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌─────────────────────────────────────────────────┐  │
│  │  FOR EACH PHASE:                                 │  │
│  │  ┌───────────┐                                   │  │
│  │  │  Stage 2  │  Test + Implement + Verify (coord)│  │
│  │  └─────┬─────┘                                   │  │
│  │        ↓                                          │  │
│  │  ┌───────────┐                                   │  │
│  │  │  Stage 3  │  Validate phase       (coord.)    │  │
│  │  └─────┬─────┘                                   │  │
│  │        ↓                                          │  │
│  │  ┌───────────┐                                   │  │
│  │  │  Stage 4  │  Quality review phase  (coord.)   │  │
│  │  └─────┬─────┘  (+ figma parity for UI phases)   │  │
│  │        ↓ fix loop if needed                       │  │
│  │  ┌───────────┐                                   │  │
│  │  │  Stage 5  │  Phase docs + doc judge (coord.)  │  │
│  │  └─────┬─────┘                                   │  │
│  │        ↓                                          │  │
│  │  Auto-commit phase                               │  │
│  └─────────────────────────────────────────────────┘  │
│        ↓                                              │
│  Optional: Final S3+S4 pass (cross-phase)             │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │  Stage 5  │  Final docs synthesis     (coord.)     │
│  └─────┬─────┘                                        │
│        ↓        lock released ↑                       │
│  ┌───────────┐                                        │
│  │  Stage 6  │  Implementation Retrospective (coord.) │
│  └───────────┘                                        │
└──────────────────────────────────────────────────────┘
```

> When `per_phase_review.enabled` is `false`, the workflow falls back to the original linear mode: S1→S2(all phases)→S3→S4→S5→S6.

## Latency Trade-off

Each coordinator dispatch adds ~5-15s overhead. This is the trade-off for significant orchestrator context reduction and fault isolation. Stage 1 is inline to avoid overhead for lightweight setup. When `code_simplification.enabled` is `true`, each phase adds an additional code-simplifier dispatch (~5-15s overhead + 30-120s execution). This is the trade-off for cleaner downstream code, reduced review noise in Stage 4, lower token cost for future maintenance, and improved LLM comprehension.

## Stage Dispatch Table

| Stage | Delegation | Reference File | Agents Used | Prior Summaries | User Interaction | Checkpoint |
|-------|-----------|----------------|-------------|-----------------|------------------|------------|
| 1 | Inline | `stage-1-setup.md` | — | — | Setup question (1.5b), Policy question (1.9a) | SETUP |
| 2 | Coordinator | `stage-2-execution.md` | `test-writer`, `developer`, `output-verifier`, `code-simplifier`, `uat-tester (CLI/gemini)` | stage-1 (or per-phase chain) | Auto-resolve per policy (build/test) | EXECUTION |
| 3 | Coordinator | `stage-3-validation.md` | `developer` | stage-1, stage-2 (or per-phase chain) | Auto-resolve per policy (validation) | VALIDATION |
| 4 | Coordinator | `stage-4-quality-review.md` | `developer` x3+ (Tier A, with optional stances/convergence/CoVe), plugin (Tier B), CLI (Tier C) | stage-2, stage-3 (or per-phase chain) | Auto-resolve per policy (findings) | QUALITY_REVIEW |
| 5 | Coordinator | `stage-5-documentation.md` | `developer`, `tech-writer`, `doc-judge` | stage-3, stage-4 (or per-phase chain) | Auto-resolve per policy (tasks, docs) | DOCUMENTATION |
| 6 | Coordinator | `stage-6-retrospective.md` | `tech-writer` | stage-1 through stage-5 (all per-phase + final summaries) | None | RETROSPECTIVE |

All reference files are in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/`.

> **Note:** "Agents Used" refers to plugin agents defined in `agents/` (developer, code-simplifier, tech-writer). CLI roles (Codex, Gemini, OpenCode) are dispatched by coordinators via `scripts/dispatch-cli-agent.sh` and are not listed here — see `references/integrations-overview.md` for CLI dispatch details.

## Orchestrator Loop

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/orchestrator-loop.md`

The loop reads state → dispatches stages (per-phase or linear) → reads summaries → handles user interaction → updates state. It includes crash recovery, summary validation, v1→v2→v3 state migration, and per-phase delivery cycles.

## Stage 1 (Inline)

Execute Stage 1 inline. Read `$CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-1-setup.md` for full instructions. After completion, write Stage 1 summary to `{FEATURE_DIR}/.stage-summaries/stage-1-summary.md`.

## Summary Convention

- **Per-phase path:** `{FEATURE_DIR}/.stage-summaries/phase-{N}-stage-{S}-summary.md` (when per_phase_review enabled)
- **Final pass path:** `{FEATURE_DIR}/.stage-summaries/final-stage-{S}-summary.md`
- **Linear/global path:** `{FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md` (Stages 1, 6 always use this)
- **Template:** `$CLAUDE_PLUGIN_ROOT/templates/stage-summary-template.md`
- **Size:** 20-60 lines (YAML frontmatter + markdown); Stage 1 may reach ~120-130 lines due to context loading duties; Stage 6 ~40 lines
- **Required YAML fields:** `stage`, `status`, `checkpoint`, `artifacts_written`, `summary`
- **Per-phase field:** `phase` (string, e.g., `"Phase 2: Core"`) — present when phase_scope is set
- **Critical section:** "Context for Next Stage" — this is what the next coordinator reads to understand state

## State Management

State persisted in `{FEATURE_DIR}/.implementation-state.local.md` (version 3):
- YAML frontmatter tracks stage, phase, decisions, stage_summaries, phase_stages, orchestrator metadata
- `phase_stages` maps each phase to its per-stage completion status (`s2`, `s3`, `s4`, `s5`)
- `current_phase` tracks the phase currently being processed (null when between phases)
- Markdown body contains human-readable log
- Immutable fields: `user_decisions`
- Migration: v1→v2→v3 chain. See `orchestrator-loop.md` for auto-migration

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

| Agent | Role | Model | Used In |
|-------|------|-------|---------|
| `product-implementation:test-writer` | Spec-to-test translation (Red phase) | sonnet | Stage 2 |
| `product-implementation:developer` | Implementation, testing, validation, review | sonnet | Stages 2, 3, 4, 5 |
| `product-implementation:output-verifier` | Output quality verification (test bodies, spec alignment, DoD) | sonnet | Stage 2 |
| `product-implementation:code-simplifier` | Code simplification, clarity, maintainability | sonnet | Stage 2 |
| `product-implementation:doc-judge` | Documentation accuracy verification (LLM-as-a-judge) | sonnet | Stage 5 |
| `product-implementation:tech-writer` | Feature documentation, API guides, architecture updates, retrospective | sonnet | Stages 5, 6 |

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
| Git commits | Auto-commits at phase completion (orchestrator-owned when per_phase_review enabled, or Stage 2 when linear), review fix (Stage 4), documentation (Stage 5), and retrospective (Stage 6). Controlled by `auto_commit`, `per_phase_review`, and `code_simplification` in config. |

### Conditional Artifacts (gated by config or findings)

| Artifact | Gate | Content |
|----------|------|---------|
| `review-findings.md` | Findings exist AND outcome is "fix now" or "fix later" | Quality review findings |
| `docs/` | Stage 5 runs | Feature documentation, API guides, architecture updates |
| Module `README.md` files | Stage 5 runs | Updated READMEs in folders affected by implementation |
| `.project-setup-analysis.local.md` | project_setup enabled | Project analysis results (excluded from auto-commit) |
| `.project-setup-proposal.local.md` | project_setup enabled + user selects categories | Summary of configuration changes applied |
| `.uat-evidence/` | UAT enabled + relevant phases | UAT screenshots organized by phase |
| `retrospective.md` | Stage 6 runs | Implementation retrospective narrative with KPI analysis |
| `.implementation-report-card.local.md` | Stage 6 runs (excluded from auto-commit) | Machine-readable KPI Report Card |
| `.implementation-ralph-status.local.md` | Ralph mode enabled (excluded from auto-commit) | Iteration status for external monitoring |

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
| `references/stage-1-setup.md` | Stage 1 (inline) | Branch parsing, file loading, project setup, lock, state init, domain detection |
| `references/stage-1-project-setup.md` | Stage 1 (inline, conditional) | Project analysis checklist, hook patterns, CLAUDE.md rubric, generator rules |
| `references/stage-2-execution.md` | Stage 2 (coordinator) | Skill resolution, phase loop, task parsing, error handling |
| `references/stage-2-uat-mobile.md` | Stage 2 (coordinator, conditional) | UAT mobile testing gate check, APK build/install, CLI dispatch, result processing |
| `references/stage-3-validation.md` | Stage 3 (coordinator) | Task completeness, spec alignment, test coverage, test quality gate |
| `references/stage-4-quality-review.md` | Stage 4 (coordinator) | Three-tier review, stances, convergence, confidence scoring, CoVe, auto-decision |
| `references/stage-4-plugin-review.md` | Stage 4 (coordinator reads) | Tier B: Plugin-based review via code-review skill, finding normalization |
| `references/stage-4-cli-review.md` | Stage 4 (coordinator reads) | Tier C: CLI multi-model review, Phase 1/2 dispatch, pattern search, UX/accessibility review |
| `references/stage-5-documentation.md` | Stage 5 (coordinator) | Skill resolution for docs, tech-writer dispatch, lock release |
| `references/agent-prompts.md` | Stages 2-6 (coordinator reads) | 14 prompt templates with Common Variables, section markers, fallback annotations |
| `references/auto-commit-dispatch.md` | Stages 2, 4, 5, 6 (coordinator reads) | Shared auto-commit procedure, exclude patterns, batch strategy |
| `references/autonomy-policy-procedure.md` | Stages 2-5 (coordinator reads) | Shared autonomy policy check, per-severity iteration, fallback escalation |
| `references/skill-resolution.md` | Stages 2, 4, 5 (coordinator reads) | Shared skill resolution algorithm for domain-specific skill injection |
| `references/cli-dispatch-procedure.md` | Stages 2, 3, 4, 5 (coordinator reads) | Shared CLI dispatch, timeout, parsing, circuit breaker, fallback |
| `references/summary-schemas.md` | When adding/modifying summary fields | YAML schemas for all 6 stage summaries, producer/consumer mapping |
| `references/ralph-loop-integration.md` | When debugging ralph mode | Ralph mode detection, AskUserQuestion guard, stall detection, completion signal |
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

## Ralph Mode (Autonomous Execution)

When invoked via `/product-implementation:ralph-implement`, the implement skill runs inside a ralph loop for walk-away autonomous execution. The ralph-loop plugin's Stop Hook feeds the same prompt back on each session exit, and the implement skill resumes from its last checkpoint.

**Behavioral contract in ralph mode:**
1. **No user interaction** — ALL `AskUserQuestion` calls are auto-resolved via autonomy policy
2. **Pre-seeded config** — `quality_preset`, `external_models`, `autonomy_policy.default_level` must be non-null
3. **Skip project setup** — Stage 1 Section 1.5b is skipped entirely (requires user selection)
4. **Graduated stall response** — 4-level progressive response: warn → write blockers → scope reduce (annotate + skip) → halt
5. **Rate limit exemption** — API throttling/timeouts exempt from stall counting; backoff + retry instead
6. **Output decline detection** — summary length drops >70% trigger stall count increment
7. **Test result stall** — identical Stage 3 test failures across iterations count toward same_error_threshold
8. **Plan mutability** — at Level 3, stuck tasks annotated in tasks.md and phase optionally skipped
9. **Status file** — writes `.implementation-ralph-status.local.md` after each transition for external monitoring
10. **Completion signal** — orchestrator outputs `<promise>IMPLEMENTATION COMPLETE</promise>` after Stage 6

**Detection:** Stage 1 Section 1.0b checks for `.claude/ralph-loop.local.md` in PROJECT_ROOT. If present, sets `ralph_mode: true` in state file and Stage 1 summary.

**Configuration:** `config/implementation-config.yaml` under `ralph_loop` (iteration budget, circuit breaker, pre-seed defaults).

## Quick Start

1. Ensure `{FEATURE_DIR}/tasks.md` and `plan.md` exist (run `/product-planning:plan` then `/product-planning:tasks`)
2. Optional: verify `design.md`, `test-plan.md`, `test-strategy.md`, and `test-cases/` are present for richer agent context
3. **Top config toggles** (in `config/implementation-config.yaml`):
   - `quality_preset` — set to `"standard"` / `"comprehensive"` / `"minimal"` to skip the startup question (controls 40+ feature flags)
   - `external_models` — set to `true` / `false` to skip the external models question
   - `autonomy_policy.default_level` — set to skip the autonomy question (`full_auto` / `balanced` / `critical_only`)
   - `project_setup.enabled` — enable project setup analysis and configuration generation (Stage 1)
   - `code_simplification.enabled` — enable post-phase code simplification
   - `dev_skills.enabled` — enable domain-specific skill injection
   - `research_mcp.enabled` — enable MCP-backed documentation context
4. Run `/product-implementation:implement`
5. Choose autonomy policy when prompted (skipped if `default_level` is set)
6. Monitor stage-by-stage progress (interruptions depend on chosen policy)
7. Review documentation updates generated by tech-writer
8. Review `retrospective.md` and `.implementation-report-card.local.md` for implementation analysis

---
name: feature-implementation
description: |
  This skill should be used when the user asks to "implement the feature", "execute the tasks",
  "run the implementation plan", "continue implementation", "resume implementation",
  "execute the plan", "document the feature",
  or needs to execute tasks defined in tasks.md. Orchestrates stage-by-stage implementation
  using developer agents with TDD, progress tracking, integrated quality review, and feature
  documentation.
version: 3.6.0
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
9. **Lock Protocol** — Acquire lock at start, release at completion. Check for stale locks (>60 min hardcoded timeout).
10. **Delegation Protocol** — Delegated stages execute via `Task(subagent_type="general-purpose")` coordinators. Stage 1 is inline. See dispatch table below.
11. **Summary-Only Context** — Between stages, read ONLY summary files from `{FEATURE_DIR}/.stage-summaries/`. Never read full reference files or raw artifacts in orchestrator context.
12. **No User Interaction from Coordinators** — Coordinators set `status: needs-user-input` in their summary. The orchestrator mediates ALL user prompts via `SAFE_ASK_USER` (validates non-empty responses, retries on widget failures). In ralph mode, auto-resolve guard intercepts before SAFE_ASK_USER.
13. **No Direct Agent Dispatch** — NEVER dispatch `developer`, `test-writer`, `output-verifier`, `code-simplifier`, `tech-writer`, or `doc-judge` agents directly from the orchestrator. ALL agent dispatches go through stage coordinators. The orchestrator dispatches only `general-purpose` coordinators via `Task()`.
14. **Sequential Phase Execution** — Phases MUST execute sequentially within per-phase loops. NEVER dispatch multiple phases in parallel or background. Each phase's S2→S3→S4→S5 cycle must complete before the next phase begins.
15. **Prompt Template Discipline** — Agent prompts MUST use templates from `agent-prompts.md` with all required variables populated. NEVER write ad-hoc agent instructions inline. Coordinators log which templates they used in `protocol_evidence`.
16. **Vertical Agent Selection** — Select vertical agent type based on `detected_domains`. Use `android-developer` for Android/Kotlin/Compose, `frontend-developer` for web, `backend-developer` for API/database, generic `developer` as fallback. Use `debugger` for debugging-typed tasks. Skills are baked into agent .md files — no runtime skill injection.

## Workflow Overview

```
┌──────────────────────────────────────────────────────┐
│              IMPLEMENTATION WORKFLOW                   │
├──────────────────────────────────────────────────────┤
│  ┌───────────┐                                        │
│  │ Stage 1a  │  Setup & Context Loading  (inline)     │
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │ Stage 1b  │  Probes & Configuration   (coord.)     │
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

Each coordinator dispatch adds ~5-15s overhead. This is the trade-off for significant orchestrator context reduction and fault isolation. Stage 1 is inline to avoid overhead for lightweight setup. When `features.code_simplification` is `true` (from profile), each phase adds an additional code-simplifier dispatch (~5-15s overhead + 30-120s execution). This is the trade-off for cleaner downstream code, reduced review noise in Stage 4, lower token cost for future maintenance, and improved LLM comprehension.

## Stage Dispatch Table

| Stage | Delegation | Reference File | Agents Used | Prior Summaries | User Interaction | Checkpoint |
|-------|-----------|----------------|-------------|-----------------|------------------|------------|
| 1a | Inline | `stage-1-setup.md` | — | — | Branch fallback (1.1) | SETUP_PARTIAL |
| 1b | Coordinator | `stage-1b-probes.md` | — | stage-1a partial | Setup question (1.5b), Policy question (1.9a) | SETUP |
| 2 | Coordinator | `stage-2-execution.md` | `test-writer`, `developer`, `output-verifier`, `code-simplifier`, `uat-tester` | stage-1 (or per-phase chain) | Auto-resolve per policy (build/test) | EXECUTION |
| 3 | Coordinator | `stage-3-validation.md` | `developer` | stage-1, stage-2 (or per-phase chain) | Auto-resolve per policy (validation) | VALIDATION |
| 4 | Coordinator | `stage-4-quality-review.md` | `developer` x3+ (Tier A, with optional stances/convergence/CoVe), plugin (Tier B), CLI (Tier C) | stage-2, stage-3 (or per-phase chain) | Auto-resolve per policy (findings) | QUALITY_REVIEW |
| 5 | Coordinator | `stage-5-documentation.md` | `developer`, `tech-writer`, `doc-judge` | stage-3, stage-4 (or per-phase chain) | Auto-resolve per policy (tasks, docs) | DOCUMENTATION |
| 6 | Coordinator | `stage-6-retrospective.md` | `tech-writer` | stage-1 through stage-5 (all per-phase + final summaries) | None | RETROSPECTIVE |

All reference files are in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/`.

> **Note:** "Agents Used" refers to plugin agents defined in `agents/` (developer, code-simplifier, tech-writer). CLI roles (Codex, Gemini) are dispatched by coordinators via `scripts/dispatch-cli-agent.sh` (supports --model/--effort flags) and are not listed here — see `references/integrations-overview.md` for CLI dispatch details.

## Orchestrator Loop

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/orchestrator-loop.md`

The loop reads state → dispatches stages (per-phase or linear) → reads summaries → handles user interaction → updates state. It includes crash recovery, summary validation, v1→v2→v3→v4 state migration, and per-phase delivery cycles.

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

State persisted in `{FEATURE_DIR}/.implementation-state.local.md` (version 4):
- YAML frontmatter tracks stage, phase, decisions, stage_summaries, phase_stages, orchestrator metadata
- `phase_stages` maps each phase to its per-stage completion status (`s2`, `s3`, `s4`, `s5`)
- `current_phase` tracks the phase currently being processed (null when between phases)
- `profile` — active execution profile (`quick`, `standard`, or `thorough`)
- `autonomy` — active autonomy level (`auto` or `interactive`)
- Markdown body contains human-readable log
- Immutable fields: `user_decisions`
- Migration: v1→v2→v3→v4 chain. See `orchestrator-loop.md` for auto-migration

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
| `product-implementation:test-writer` | Unit test spec-to-test translation (Red phase) | sonnet | Stage 2 |
| `product-implementation:integration-test-writer` | E2E/integration test specialist (wiring, flows, contracts) | sonnet | Stage 2 |
| `product-implementation:developer` | Generic implementation, testing, validation, review (fallback) | sonnet | Stages 2, 3, 4, 5 |
| `product-implementation:android-developer` | Android/Kotlin/Compose specialist (vertical) | sonnet | Stage 2 |
| `product-implementation:frontend-developer` | Frontend/web specialist (vertical) | sonnet | Stage 2 |
| `product-implementation:backend-developer` | Backend/API/database specialist (vertical) | sonnet | Stage 2 |
| `product-implementation:debugger` | Systematic bug diagnosis (UNDERSTAND→REPRODUCE→ISOLATE→FIX) | sonnet | Stage 2 |
| `product-implementation:output-verifier` | Output quality verification (test bodies, spec alignment, DoD) | sonnet | Stage 2 |
| `product-implementation:code-simplifier` | Code simplification, clarity, maintainability | sonnet | Stage 2 |
| `product-implementation:doc-judge` | Documentation accuracy verification (LLM-as-a-judge) | sonnet | Stage 5 |
| `product-implementation:uat-tester` | UAT mobile testing via SAV loop, Figma visual parity | sonnet | Stage 2 |
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
| Dev-Skills | Vertical agent selection + static skills (baked into agent .md files via progressive disclosure) |
| Research MCP | Documentation context from Ref/Context7/Tavily, budget-controlled |
| CLI Dispatch | Multi-model dispatch via Codex/Gemini, opt-in per option |
| Autonomy Policy | Auto-resolution: auto (fix all), interactive (defer medium). Selected at Stage 1 |

## Reference Map

> Read only the reference file needed for the current stage. Do not preload all stage files.

| File | When to Read | Content |
|------|-------------|---------|
| `references/orchestrator-loop.md` | Workflow start (always) | Dispatch loop, crash recovery, state migration, context packs |
| `references/integrations-overview.md` | When understanding integration architecture | Dev-Skills, Research MCP, CLI Dispatch, Autonomy Policy — full detail |
| `references/stage-1-setup.md` | Stage 1a (inline) | Branch parsing, file loading, tasks validation, lock, state init |
| `references/stage-1b-probes.md` | Stage 1b (coordinator) | All probes (MCP, mobile, Figma, CLI), domain detection, project setup, autonomy policy, quality config, pre-summary checklist, full summary |
| `references/stage-1-project-setup.md` | Stage 1b (conditional) | Project analysis checklist, hook patterns, CLAUDE.md rubric, generator rules |
| `references/stage-2-execution.md` | Stage 2 (coordinator) | Skill resolution, phase loop, task parsing, error handling |
| `references/stage-2-uat-mobile.md` | Stage 2 (coordinator, conditional) | Multi-engine UAT gate check, engine selection (subagent/CLI), APK build/install, result processing |
| `references/stage-3-uat-sweep.md` | Stage 3 (coordinator, final pass) | Full-sweep UAT validation across all user stories |
| `references/stage-3-validation.md` | Stage 3 (coordinator) | Task completeness, spec alignment, test coverage, test quality gate |
| `references/stage-4-quality-review.md` | Stage 4 (coordinator) | Three-tier review, stances, convergence, confidence scoring, CoVe, auto-decision |
| `references/stage-4-plugin-review.md` | Stage 4 (coordinator reads) | Tier B: Plugin-based review via code-review skill, finding normalization |
| `references/stage-4-cli-review.md` | Stage 4 (coordinator reads) | Tier C: CLI multi-model review, Phase 1/2 dispatch, pattern search, UX/accessibility review |
| `references/stage-5-documentation.md` | Stage 5 (coordinator) | Skill resolution for docs, tech-writer dispatch, lock release |
| `references/agent-prompts.md` | Stages 2-6 (coordinator reads) | 16 prompt templates (15 agent + 1 auto-commit) with Common Variables, section markers, fallback annotations |
| `references/auto-commit-dispatch.md` | Stages 2, 4, 5, 6 (coordinator reads) | Shared auto-commit procedure, exclude patterns, batch strategy |
| `references/autonomy-policy-procedure.md` | Stages 2-5 (coordinator reads) | Shared autonomy policy check, per-severity iteration, fallback escalation |
| `references/developer-core-instructions.md` | All developer agents (read at dispatch) | Shared core engineering process, quality standards, verification rules |
| `references/cli-dispatch-procedure.md` | Stages 2, 3, 4, 5 (coordinator reads) | Shared CLI dispatch, timeout, parsing, circuit breaker, fallback |
| `references/protocol-compliance-checklist.md` | Stages 2-5 (coordinator reads) | Shared protocol compliance checklist — universal + per-stage checks, protocol_evidence examples |
| `references/prompt-registry.yaml` | Stages 2-5 (coordinator reads) | Machine-readable registry of all 14 prompt templates — template names, agent types, required variables, stage/step usage |
| `references/summary-schemas.md` | When adding/modifying summary fields | YAML schemas for all 6 stage summaries, producer/consumer mapping, protocol_evidence schema |
| `references/ralph-loop-integration.md` | When debugging ralph mode | Ralph mode detection, AskUserQuestion guard, stall detection, completion signal |
| `references/stage-6-retrospective.md` | Stage 6 (coordinator) | KPI Report Card, transcript extraction, retrospective composition |
| `config/profile-definitions.yaml` | When understanding or modifying execution profiles | Profile definitions for `quick`, `standard`, and `thorough` — maps each profile to its feature flag values |
| `config/cli_clients/shared/cli-instruction-shared.md` | When modifying CLI behavioral standards | Universal content written into AGENTS.md/GEMINI.md managed sections (output standards, severity classification) |
| `config/cli_clients/shared/codex-instruction-extra.md` | When modifying Codex CLI instructions | Codex-specific content appended after shared section (parallelism, plan tool suppression) |
| `config/cli_clients/shared/gemini-instruction-extra.md` | When modifying Gemini CLI instructions | Gemini-specific content appended after shared section (context window usage) |

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
2. **Pre-seeded config** — `ralph.default_profile` must be set to a valid profile name (`quick`, `standard`, or `thorough`)
3. **Skip project setup** — Stage 1 Section 1.5b is skipped entirely (requires user selection)
4. **Graduated stall response** — 4-level progressive response: warn → write blockers → scope reduce (annotate + skip) → halt
5. **Rate limit exemption** — API throttling/timeouts exempt from stall counting; backoff + retry instead
6. **Output decline detection** — summary length drops >70% trigger stall count increment
7. **Test result stall** — identical Stage 3 test failures across iterations count toward same_error_threshold
8. **Plan mutability** — at Level 3, stuck tasks annotated in tasks.md and phase optionally skipped
9. **Status file** — writes `.implementation-ralph-status.local.md` after each transition for external monitoring
10. **Completion signal** — orchestrator outputs `<promise>IMPLEMENTATION COMPLETE</promise>` after Stage 6

**Detection:** Stage 1 Section 1.0b checks for `.claude/ralph-loop.local.md` in PROJECT_ROOT. If present, sets `ralph_mode: true` in state file and Stage 1 summary.

**Configuration:** `config/implementation-config.yaml` under `ralph` (`default_profile`). Iteration budget and circuit breaker constants hardcoded in `orchestrator-loop.md`.

## Quick Start

1. Ensure `{FEATURE_DIR}/tasks.md` and `plan.md` exist (run `/product-planning:plan` then `/product-planning:tasks`)
2. Optional: verify `design.md`, `test-plan.md`, `test-strategy.md`, and `test-cases/` are present for richer agent context
3. **Choose a profile** (in `config/profile-definitions.yaml` or set `profile` at runtime):
   - `quick` — fast prototyping; minimal gates, no external models, reduced review tiers
   - `standard` — recommended; balanced quality, core review tiers, autonomy-guided decisions *(default)*
   - `thorough` — maximum quality; all features enabled, multi-tier review, CoVe, convergence analysis
4. **Optional overrides** (in `config/implementation-config.yaml`):
   - `autonomy: auto` — auto-resolve all findings (default for quick profile)
   - `autonomy: interactive` — defer medium-severity findings for user review (default for standard/thorough)
5. Run `/product-implementation:implement`
6. Monitor stage-by-stage progress (interruptions depend on autonomy level from profile)
8. Review documentation updates generated by tech-writer
9. Review `retrospective.md` and `.implementation-report-card.local.md` for implementation analysis

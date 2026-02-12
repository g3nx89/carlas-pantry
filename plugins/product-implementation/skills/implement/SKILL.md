---
name: feature-implementation
description: |
  This skill should be used when the user asks to "implement the feature", "execute the tasks",
  "run the implementation plan", "build the feature", "start coding", "document the feature",
  or needs to execute tasks defined in tasks.md. Orchestrates stage-by-stage implementation
  using developer agents with TDD, progress tracking, integrated quality review, and feature
  documentation.
version: 2.2.0
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
│  └───────────┘                                        │
│                                                       │
└──────────────────────────────────────────────────────┘
```

## Latency Trade-off

Each coordinator dispatch adds ~5-15s overhead. This is the trade-off for significant orchestrator context reduction and fault isolation. Stage 1 is inline to avoid overhead for lightweight setup. When `code_simplification.enabled` is `true`, each phase adds an additional code-simplifier dispatch (~5-15s overhead + 30-120s execution). This is the trade-off for cleaner downstream code, reduced review noise in Stage 4, lower token cost for future maintenance, and improved LLM comprehension.

## Stage Dispatch Table

| Stage | Delegation | Reference File | Agents Used | Prior Summaries | User Interaction | Checkpoint |
|-------|-----------|----------------|-------------|-----------------|------------------|------------|
| 1 | Inline | `stage-1-setup.md` | — | — | — | SETUP |
| 2 | Coordinator | `stage-2-execution.md` | `developer`, `code-simplifier`, `uat-tester (clink/gemini)` | stage-1 | On error only | EXECUTION |
| 3 | Coordinator | `stage-3-validation.md` | `developer` | stage-1, stage-2 | If issues found | VALIDATION |
| 4 | Coordinator | `stage-4-quality-review.md` | `developer` x3 or code-review skill | stage-2, stage-3 | Fix/defer/proceed | QUALITY_REVIEW |
| 5 | Coordinator | `stage-5-documentation.md` | `developer`, `tech-writer` | stage-3, stage-4 | If incomplete tasks | DOCUMENTATION |

All reference files are in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/`.

## Orchestrator Loop

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/orchestrator-loop.md`

The loop reads state → dispatches stages in order → reads summaries → handles user interaction → updates state. It includes crash recovery, summary validation, and v1-to-v2 state migration.

## Stage 1 (Inline)

Execute Stage 1 inline. Read `$CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-1-setup.md` for full instructions. After completion, write Stage 1 summary to `{FEATURE_DIR}/.stage-summaries/stage-1-summary.md`.

## Summary Convention

- **Path:** `{FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md`
- **Template:** `$CLAUDE_PLUGIN_ROOT/templates/stage-summary-template.md`
- **Size:** 20-60 lines (YAML frontmatter + markdown); Stage 1 may reach ~80 lines due to context loading duties
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
- If `current_stage` = 5 and `user_decisions.documentation_outcome` exists → already complete, report status

Stage completion is derived from `stage_summaries` (non-null = completed). The `current_stage` field tracks the next stage to execute.

## Agents

| Agent | Role | Used In |
|-------|------|---------|
| `product-implementation:developer` | Implementation, testing, validation, review | Stages 2, 3, 4, 5 |
| `product-implementation:code-simplifier` | Code simplification, clarity, maintainability | Stage 2 |
| `product-implementation:tech-writer` | Feature documentation, API guides, architecture updates | Stage 5 |

## Severity Levels (Canonical)

Canonical definitions — sourced from `config/implementation-config.yaml`:

| Severity | Description |
|----------|-------------|
| **Critical** | Breaks functionality, security vulnerability, data loss risk |
| **High** | Likely to cause bugs, significant code quality issue |
| **Medium** | Code smell, maintainability concern, minor pattern violation |
| **Low** | Style preference, minor optimization opportunity |

## Output Artifacts

| Artifact | Content |
|----------|---------|
| `tasks.md` | Updated with `[X]` marks for all completed tasks |
| `.implementation-state.local.md` | Execution state, stage tracking, and implementation log |
| `.stage-summaries/` | Inter-stage coordinator summary files |
| `review-findings.md` | Quality review findings (created if findings exist and user chooses "fix now" or "fix later") |
| `docs/` | Feature documentation, API guides, architecture updates (Stage 5) |
| Module `README.md` files | Updated READMEs in folders affected by implementation (Stage 5) |
| `.uat-evidence/` | UAT screenshots organized by phase (Step 3.7, conditional on UAT being enabled and relevant phases) |
| Git commits | Auto-commits at phase completion (Stage 2, with simplified code when enabled), review fix (Stage 4), and documentation (Stage 5). Controlled by `auto_commit` and `code_simplification` in config. |

## Dev-Skills Integration

When the `dev-skills` plugin is installed alongside `product-implementation`, agents receive conditional, domain-specific skill references that enhance implementation quality. This integration is:

- **Zero-cost when disabled** — if `dev_skills.enabled: false` in config or plugin not installed, all skill injection is silently skipped
- **Orchestrator-transparent** — the orchestrator never reads or references dev-skills; all resolution happens inside coordinator subagents
- **Capped** — at most `max_skills_per_dispatch` skills (default: 3) are injected per agent dispatch to avoid context bloat

**Domain detection** runs in Stage 1 (Section 1.6) by scanning task file paths and plan.md for technology indicators. The `detected_domains` list flows through the Stage 1 summary to all downstream coordinators.

**Injection points:**
- Stage 2 coordinators inject skills into developer agent prompts (implementation patterns)
- Stage 4 coordinators add conditional review dimensions (e.g., accessibility) and inject skills into reviewer prompts
- Stage 5 coordinators inject diagram and documentation skills into tech-writer prompts

Configuration: `config/implementation-config.yaml` under `dev_skills`.

## Research MCP Integration

When MCP tools (Ref, Context7, Tavily) are available, agents receive documentation-backed context that improves implementation accuracy, build error diagnosis, and documentation quality. This integration is:

- **Zero-cost when disabled** — if `research_mcp.enabled: false` in config, all research steps are skipped; no MCP calls occur
- **Orchestrator-transparent** — the orchestrator never calls MCP tools; Stage 1 (inline) probes availability, coordinators build `{research_context}` blocks, agents make on-demand calls
- **Ref-primary** — Ref is the primary lookup tool, exploiting session deduplication (Dropout) for ~87% token savings across sequential stages; Context7 is secondary for library-specific queries; Tavily is last-resort for known-issues only
- **Budget-controlled** — per-stage caps on searches, reads, and total context tokens are defined in config

**MCP availability detection** runs in Stage 1 (Sections 1.6a-1.6c): lightweight probe calls determine which tools are reachable, with results stored in `mcp_availability` in the Stage 1 summary.

**Injection points:**
- Stage 2 coordinators build `{research_context}` from pre-read URLs and resolved libraries, inject into developer agent prompts. Agents also use MCP on-demand for build error diagnosis (ref_first → Context7 → Tavily escalation).
- Stage 4 coordinators re-read `research_urls_discovered` from Stage 2 summary for documentation-backed review context.
- Stage 5 coordinators re-read accumulated URLs for documentation enrichment and link generation.

**Session accumulation:** Stage 2 writes `research_urls_discovered` to its summary flags. Stages 4 and 5 re-read these URLs via Ref (cache serves faster on re-reads, maximum Dropout benefit by Stage 5).

Configuration: `config/implementation-config.yaml` under `research_mcp`.

## Clink Integration (PAL MCP)

When PAL clink (CLI-to-CLI bridge) is available and configured, coordinators can delegate specific tasks to external CLI agents (Codex, Gemini) for multi-model code generation, testing, validation, and review. This integration is:

- **Zero-cost when disabled** — all clink options default to `enabled: false` in config; when disabled, no clink dispatch occurs and no CLI healthchecks run
- **Orchestrator-transparent** — the orchestrator never invokes clink or reads clink config; all dispatch happens inside coordinator subagents and Stage 1 (inline)
- **Opt-in per option** — each integration point (test author, multi-model review, spec validator, etc.) is independently toggleable
- **Graceful degradation** — every clink dispatch has a fallback: native agent substitution or silent skip. CLI unavailability is detected in Stage 1 and propagated to all downstream stages

**CLI availability detection** runs in Stage 1 (Section 1.7a): healthcheck commands verify which CLIs are installed, with results stored in `cli_availability` in the Stage 1 summary.

**Injection points:**
- Stage 2: Test Author (Option H — Codex generates TDD tests from specs), Test Augmenter (Option I — Gemini discovers untested edge cases), UAT Mobile Tester (Option J — Gemini runs per-phase behavioral acceptance testing and Figma visual verification on Genymotion emulator via mobile-mcp)
- Stage 3: Spec Validator (Option C — Gemini cross-validates implementation against specs in parallel with native validator)
- Stage 4: Multi-Model Review (Option D — Gemini + Codex + Native reviewers with distinct focus areas), Security Reviewer (Option E — conditional OWASP audit via Codex), Fix Engineer (Option F — Codex fixes review findings)

**Shared procedure:** All clink dispatches use the parameterized procedure in `references/clink-dispatch-procedure.md` for dispatch, timeout, output parsing, and fallback handling.

Configuration: `config/implementation-config.yaml` under `clink_dispatch`. CLI role definitions: `config/cli_clients/`. Shared conventions: `config/cli_clients/shared/severity-output-conventions.md`.

## Reference Map

| File | When to Read | Content |
|------|-------------|---------|
| `references/orchestrator-loop.md` | Workflow start (always) | Dispatch loop, crash recovery, state migration, late notification handling |
| `references/stage-1-setup.md` | Stage 1 (inline) | Branch parsing, file loading, lock, state init, domain detection |
| `references/stage-2-execution.md` | Stage 2 (coordinator) | Skill resolution, phase loop, task parsing, error handling |
| `references/stage-3-validation.md` | Stage 3 (coordinator) | Task completeness, spec alignment, test coverage, test quality gate |
| `references/stage-4-quality-review.md` | Stage 4 (coordinator) | Skill resolution, review dimensions (base + conditional), finding consolidation, auto-decision matrix |
| `references/stage-5-documentation.md` | Stage 5 (coordinator) | Skill resolution for docs, tech-writer dispatch, lock release |
| `references/agent-prompts.md` | Stages 2-5 (coordinator reads) | All agent prompt templates with build verification, API verification, test quality, animation testing, pattern propagation, code simplification, auto-commit prompt |
| `references/auto-commit-dispatch.md` | Stages 2, 4, 5 (coordinator reads) | Shared parameterized auto-commit procedure, exclude pattern semantics, batch strategy |
| `references/skill-resolution.md` | Stages 2, 4, 5 (coordinator reads) | Shared skill resolution algorithm for domain-specific skill injection |
| `references/clink-dispatch-procedure.md` | Stages 2, 3, 4 (coordinator reads) | Shared parameterized clink dispatch, timeout, parsing, fallback procedure |

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
2. Optional: verify `design.md`, `test-plan.md`, and `test-cases/` are present for richer agent context
3. Run `/product-implementation:implement`
4. Monitor stage-by-stage progress
5. Review quality findings and choose fix / defer / proceed
6. Review documentation updates generated by tech-writer

---
name: Feature Implementation
description: |
  This skill should be used when the user asks to "implement the feature", "execute the tasks",
  "run the implementation plan", "build the feature", "start coding", "document the feature",
  or needs to execute tasks defined in tasks.md. Orchestrates phase-by-phase implementation
  using developer agents with TDD, progress tracking, integrated quality review, and feature
  documentation.
version: 1.0.0
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
---

# Implement Feature Skill — Lean Orchestrator

> **Invoke:** `/product-implementation:implement` or ask "implement this feature"

Execute the implementation plan by processing all tasks defined in `tasks.md`, phase by phase, using developer agents with TDD workflow, progress tracking, quality review, and feature documentation.

## Critical Rules

1. **Context First** — Read ALL required spec files before launching any agent. Missing context = hallucinated code.
2. **Phase Order** — Complete each phase fully before starting the next. Never skip phases.
3. **TDD Enforcement** — Developer agents follow test-first approach. Tests before implementation, always.
4. **Progress Tracking** — Mark tasks `[X]` in tasks.md after completion. Uncommitted progress = lost progress.
5. **Error Halting** — Sequential task failure halts the phase. Parallel `[P]` tasks: continue others, report failures.
6. **State Persistence** — Checkpoint after each phase in `.implementation-state.local.md`.
7. **User Decisions are Final** — Quality review and documentation decisions are immutable once saved.
8. **No Spec Changes** — DO NOT create or modify specification files during implementation.
9. **Lock Protocol** — Acquire lock at start, release at completion. Check for stale locks (>60 min).

## Workflow Overview

```
┌──────────────────────────────────────────────────────┐
│              IMPLEMENTATION WORKFLOW                   │
├──────────────────────────────────────────────────────┤
│                                                       │
│  ┌───────────┐                                        │
│  │  Stage 1  │  Setup & Context Loading               │
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │  Stage 2  │  Phase-by-Phase Execution              │
│  │           │  ┌─────────────────────────┐           │
│  │           │  │ For each phase:         │           │
│  │           │  │  1. Launch developer    │           │
│  │           │  │  2. Execute tasks       │           │
│  │           │  │  3. Mark [X] completed  │           │
│  │           │  │  4. Checkpoint state    │           │
│  │           │  └─────────────────────────┘           │
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │  Stage 3  │  Completion Validation                 │
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │  Stage 4  │  Quality Review                        │
│  │           │  → Present findings to user             │
│  │           │  → Fix now / fix later / proceed        │
│  └─────┬─────┘                                        │
│        ↓                                              │
│  ┌───────────┐                                        │
│  │  Stage 5  │  Feature Documentation                 │
│  │           │  → Verify completion                    │
│  │           │  → Launch tech-writer agent             │
│  │           │  → Release lock                         │
│  └───────────┘                                        │
│                                                       │
└──────────────────────────────────────────────────────┘
```

## Stage Dispatch Table

| Stage | Delegation | Reference File | Agents Used | User Interaction |
|-------|-----------|----------------|-------------|------------------|
| 1 | Inline | `setup-and-context.md` | — | — |
| 2 | Direct (one agent per phase) | `execution-and-validation.md` | `developer` | On error only |
| 3 | Direct | `execution-and-validation.md` (Stage 3 section) | `developer` | If issues found |
| 4 | Direct (3 agents parallel) | `quality-review.md` | `developer` x3 or code-review skill | Fix/defer/proceed |
| 5 | Direct | `documentation.md` | `developer`, `tech-writer` | If incomplete tasks |

All reference files are in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/`.

## Stage 1: Setup & Context Loading (Inline)

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/setup-and-context.md`

**Summary:** Parse current git branch to derive FEATURE_NAME and FEATURE_DIR. Load required files (tasks.md, plan.md) and optional files (data-model.md, contracts.md, research.md). Validate that tasks.md exists and has parseable phase structure. Acquire lock and initialize or resume `.implementation-state.local.md`.

## Stage 2: Phase-by-Phase Execution

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/execution-and-validation.md`

**Summary:** For each phase in tasks.md, launch a `developer` agent with the phase-specific prompt template from `agent-prompts.md`. Track completion, mark tasks `[X]`, checkpoint state. Handle errors per the execution rules in the reference file.

### Agent Dispatch

Each phase is executed by launching:
```
Task(subagent_type="product-implementation:developer")
```

Prompt templates: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md`

## Stage 3: Completion Validation

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/execution-and-validation.md` (Stage 3 section)

**Summary:** Launch a `developer` agent to verify task completeness, spec alignment, test coverage, and plan adherence. Produces a validation report. If issues found, present options to user.

## Stage 4: Quality Review

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/quality-review.md`

**Summary:** Launch 3 parallel `developer` agents (or use `/code-review:review-local-changes` if available), each focusing on a different quality dimension (simplicity/DRY, correctness/bugs, conventions/abstractions). Consolidate findings with severity ranking. Present to user. See `quality-review.md` Section 4.2 for detailed review dimensions and focus areas.

**Severity Levels** (canonical definitions in `config/implementation-config.yaml`): **Critical** (breaks functionality, security/data risk), **High** (likely bugs, significant quality issue), **Medium** (code smell, maintainability), **Low** (style, minor optimization).

## Stage 5: Feature Documentation

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/implement/references/documentation.md`

**Summary:** Verify implementation completeness (re-check tasks.md). If incomplete tasks exist, let user choose to fix or proceed. Launch `tech-writer` agent to create/update project documentation — API guides, architecture updates, module READMEs, and lessons learned. Present documentation summary. Release lock.

## Design Decisions

**Direct agent dispatch (not coordinator model):** Unlike `product-planning:plan` which uses `general-purpose` coordinators that read phase files and write structured summaries, this skill dispatches `developer` and `tech-writer` agents directly. This is intentional — implementation phases are mechanically simpler (one agent per phase executing tasks) and don't require multi-agent analysis or consensus scoring. The coordinator overhead would be over-engineering. State is tracked through tasks.md `[X]` markers instead of phase summaries.

**Cross-reference:** The `developer` agent has its own "Tasks.md Execution Workflow" section (in `agents/developer.md`) that the orchestrator's phase prompts trigger. The `tech-writer` agent has its own "Feature Implementation Documentation Workflow" section (in `agents/tech-writer.md`). If execution rules change, update both the reference files and the corresponding agent definitions.

## Agents

| Agent | Role | Used In |
|-------|------|---------|
| `product-implementation:developer` | Implementation, testing, validation, review | Stages 2, 3, 4, 5 |
| `product-implementation:tech-writer` | Feature documentation, API guides, architecture updates | Stage 5 |

## State Management

State persisted in `{FEATURE_DIR}/.implementation-state.local.md`.

**Template:** `$CLAUDE_PLUGIN_ROOT/templates/implementation-state-template.local.md`

Key fields: `version`, `feature_name`, `feature_dir`, `current_stage`, `phases_completed`, `phases_remaining`, `user_decisions`, `lock`, `last_checkpoint`. See template for full schema and valid values.

### Stage-Level Resume

On resume, use `current_stage` and `user_decisions` to determine the correct entry point:
- If `current_stage` < 2 → start from Stage 1
- If `current_stage` = 2 → resume from first phase in `phases_remaining`
- If `current_stage` = 3 and `user_decisions.validation_outcome` exists → skip to Stage 4
- If `current_stage` = 4 and `user_decisions.review_outcome` exists → skip to Stage 5
- If `current_stage` = 5 and `user_decisions.documentation_outcome` exists → already complete, report status

### Lock Protocol

Before starting execution, acquire lock in the state file (stale timeout configured in `config/implementation-config.yaml`):
- Set `lock.acquired: true`, `lock.acquired_at: "{ISO_TIMESTAMP}"`, `lock.session_id: "{unique_id}"`
- If lock already acquired: check `lock.acquired_at`. If older than the configured stale timeout, treat as stale and override.
- On completion (Stage 5 end) or error halt: release lock by setting `lock.acquired: false`

## Output Artifacts

| Artifact | Content |
|----------|---------|
| `tasks.md` | Updated with `[X]` marks for all completed tasks |
| `.implementation-state.local.md` | Execution state, phase tracking, and implementation log |
| `review-findings.md` | Quality review findings (created only if user chooses "fix later") |
| `docs/` | Feature documentation, API guides, architecture updates (Stage 5) |
| Module `README.md` files | Updated READMEs in folders affected by implementation (Stage 5) |

## Reference Map

| File | When to Read | Content |
|------|-------------|---------|
| `references/setup-and-context.md` | Stage 1 (always) | Branch parsing, file loading, lock, state init |
| `references/execution-and-validation.md` | Stage 2-3 (always) | Phase loop, task parsing, error handling, validation |
| `references/quality-review.md` | Stage 4 (always) | Review dimensions, finding consolidation, user interaction |
| `references/documentation.md` | Stage 5 (always) | Completion re-check, tech-writer dispatch, lock release |
| `references/agent-prompts.md` | Stage 2-5 (always) | All agent prompt templates |

## Error Handling

- **Missing tasks.md** — Halt with guidance: "Run `/product-planning:tasks` first"
- **Missing plan.md** — Halt with guidance: "Run `/product-planning:plan` first"
- **Empty tasks.md** — Halt with guidance: "tasks.md has no parseable phases. Verify the file was generated correctly."
- **Lock conflict** — Check timestamp; override if stale (>60 min per `config/implementation-config.yaml`), otherwise halt with guidance
- **Interrupted execution** — Resume from checkpoint via state file (see Stage-Level Resume)

Stage-specific errors (task failures, agent crashes, test failures) are documented in `execution-and-validation.md` Section 2.2.

## Guidelines

- DO NOT CREATE new specification files
- Maintain consistent documentation style across all documents
- Include practical examples where appropriate
- Cross-reference related documentation sections
- Ensure documentation reflects actual implementation, not just plans
- Document best practices and lessons learned during implementation

## Quick Start

1. Ensure `{FEATURE_DIR}/tasks.md` and `plan.md` exist (run `/product-planning:plan` then `/product-planning:tasks`)
2. Run `/product-implementation:implement`
3. Monitor phase-by-phase progress
4. Review quality findings and choose fix / defer / proceed
5. Review documentation updates generated by tech-writer

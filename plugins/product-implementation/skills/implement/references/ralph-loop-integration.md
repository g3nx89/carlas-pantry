# Ralph Loop Integration Reference

> This file documents the behavioral specification for ralph mode — autonomous
> execution of the implement skill via the ralph-loop plugin. Read this when
> debugging ralph mode issues or modifying the autonomous execution contract.

## Overview

Ralph mode wraps the implement skill invocation in a ralph loop. The skill's
checkpoint-based resume mechanism ensures progress is preserved across loop
iterations. Each iteration gets a fresh context window, reads the state file,
and continues from the last checkpoint.

**Entry point:** `/product-implementation:ralph-implement`
**Detection:** Stage 1 Section 1.0b checks for `.claude/ralph-loop.local.md`
**Config:** `config/implementation-config.yaml` under `ralph_loop`

## Architecture Decision: Outer Loop

The ralph loop wraps the implement skill (outer loop), rather than running
inside subagent coordinators (inner loop). This was chosen because:

1. The implement skill already has checkpoint-based resume
2. Ralph-loop's Stop Hook is session-level — incompatible with Task() subagents
3. Fresh context on each iteration is a feature, not a limitation

## Ralph Mode Behavioral Contract

When `orchestrator.ralph_mode` is `true` in the state file:

| Behavior | Normal Mode | Ralph Mode |
|----------|-------------|------------|
| AskUserQuestion | Interactive prompt | Auto-resolved via autonomy policy |
| Project setup (1.5b) | User selects categories | Skipped entirely |
| Quality preset (1.9b) | Ask if null | Use pre-seed default |
| Autonomy policy (1.9a) | Ask if null | Use pre-seed default |
| External models (1.9b) | Ask if null | Use pre-seed default |
| Crash recovery | Ask: retry/continue/abort | Retry once, then continue |
| Stage failure | Policy-dependent (may ask) | Retry once, then continue |
| Stall detection | N/A | Graduated response: warn → blockers → scope reduce → halt |
| Rate limit/timeout | N/A | Exempt from stall count, backoff + retry |
| Plan mutability | N/A | Annotate + skip blocked tasks at Level 3 |
| Status file | N/A | Write monitoring status after each transition |
| Completion | Report to user | Output `<promise>` tag |

## AskUserQuestion Guard

Located in `orchestrator-loop.md` VALIDATE_AND_HANDLE function. Three guard
insertion points:

1. **needs-user-input handler** — auto-resolves based on question type
2. **failed handler** — retry once then continue (never abort)
3. **crash recovery** — retry once then continue with degraded summary

Auto-resolved decisions are logged with `[AUTO-ralph]` prefix in the
implementation log.

## Stall Detection

Located in `orchestrator-loop.md` after step 5h (phase loop checkpoint update).

**Two detection mechanisms:**

1. **Fingerprint-based** (no-progress): Detects when state doesn't change between iterations.
   - Compute fingerprint: `HASH(current_stage, current_phase, phases_completed.length, phase_stages)`
   - Compare with `orchestrator.ralph_last_fingerprint`
   - If identical: increment `ralph_stall_count`
   - If `ralph_stall_count >= no_progress_threshold`: trigger stall action

2. **Error-pattern-based** (same-error): Detects when the same coordinator error repeats, even if fingerprint changes (e.g., `coordinator_failures` incrementing changes the hash).
   - On coordinator failure: normalize error message (strip timestamps, directory paths keeping basename, line numbers)
   - Compare with `orchestrator.ralph_last_error`
   - If identical: increment `ralph_same_error_count`
   - If `ralph_same_error_count >= same_error_threshold`: trigger stall action
   - Reset on successful phase completion (step 5f)
   - Inspired by ralph-claude-code's `detect_stuck_loop()` two-stage filtering

**Stall actions** (3 modes, configured via `circuit_breaker.stall_action`):

1. `graduated` (default): 4-level progressive response:
   | Level | Trigger | Action |
   |-------|---------|--------|
   | 1 (Warning) | stall_count >= 1 AND < level_2 trigger | Log warning, continue |
   | 2 (Blockers) | stall_count >= threshold + level_2_offset (default: 3) | Write blockers file, continue |
   | 3 (Scope Reduce) | stall_count >= threshold + level_3_offset (default: 5) | Annotate stuck task in tasks.md, skip phase (if plan_mutability enabled) |
   | 4 (Halt) | stall_count >= threshold + level_4_offset (default: 7) | Write blockers, release lock, halt |

2. `write_blockers` (legacy): Write `.implementation-blockers.local.md` with diagnosis, continue
3. `halt` (legacy): Write blockers file, release lock, halt execution

**Additional detection signals** (feed into stall_count):

3. **Output-decline** (T2-7): If coordinator summary length drops below `output_decline_threshold` (default: 0.3) of previous summary length, increment stall_count. Detects degenerate outputs where the coordinator produces less and less useful content.

4. **Test-result repetition** (T2-9): When Stage 3 returns the same set of failing test names across iterations, increment `same_error_count`. Uses sorted test name signatures for comparison. Resets when tests pass or a different set fails.

**Rate limit exemption** (T2-8): Before normal error-pattern tracking, check if the error message matches `rate_limit_patterns` or `timeout_patterns`. If so: increment `rate_limit_count` (monitoring only), wait `rate_limit_backoff_seconds`, retry once, and skip stall counting entirely. This prevents API throttling from being misinterpreted as implementation stalls.

**Plan mutability** (T2-4): At graduated Level 3, the orchestrator annotates the stuck task in tasks.md with an HTML comment (`<!-- [BLOCKED: ...] -->`) and optionally skips to the next phase. Blocked tasks are recorded in `state.ralph_blocked_tasks`. Controlled by `ralph_loop.plan_mutability.*` config.

**Iteration status file** (T2-5): After each stage/phase transition, writes `.implementation-ralph-status.local.md` with YAML frontmatter containing current_stage, current_phase, phases progress, stall metrics, test status, and blocked task count. Enables external monitoring. Excluded from auto-commit.

The blockers file is excluded from auto-commit (pattern in `auto_commit.exclude_patterns`).

## Completion Signal

After Stage 6 (retrospective) completes successfully, the orchestrator outputs:
```
<promise>IMPLEMENTATION COMPLETE</promise>
```

The ralph-loop Stop Hook reads the last assistant output, detects the `<promise>`
tag, and allows the session to exit normally.

## State File Fields

Added to `orchestrator:` section (additive, no version bump):

```yaml
orchestrator:
  ralph_mode: false              # true when running inside ralph loop
  ralph_stall_count: 0           # consecutive iterations with no progress
  ralph_stall_level: 0           # graduated stall response level (0-4)
  ralph_last_fingerprint: null   # hash of last iteration's state for stall detection
  ralph_same_error_count: 0      # consecutive iterations with same error pattern
  ralph_last_error: null         # normalized error string from last failed coordinator
  ralph_rate_limit_count: 0      # cumulative rate limit/timeout events (monitoring only)
  ralph_last_summary_lengths: {} # per-stage summary length baselines for output-decline detection
  ralph_last_test_signature: null  # sorted failing test names from Stage 3
  ralph_test_stall_count: 0      # consecutive iterations with same test failures (independent counter)
ralph_blocked_tasks: []          # tasks annotated as blocked by graduated stall Level 3
```

## Configuration

```yaml
ralph_loop:
  enabled: true
  iteration_budget:
    per_phase_multiplier: 8     # estimated iterations per phase
    stage1_budget: 2            # iterations for setup stage
    stage6_budget: 2            # iterations for retrospective
    safety_margin: 1.5          # multiplier applied to calculated budget
  circuit_breaker:
    no_progress_threshold: 3    # halt after N iterations with no state change
    same_error_threshold: 5     # halt after N iterations with same error
    stall_action: "graduated"   # "graduated" | "write_blockers" | "halt"
    graduated_levels:
      level_2_offset: 0         # Level 2 at threshold + 0
      level_3_offset: 2         # Level 3 at threshold + 2
      level_4_offset: 4         # Level 4 at threshold + 4
    output_decline_threshold: 0.3
    rate_limit_backoff_seconds: 60
    rate_limit_patterns: ["rate_limit", "429", "too many requests", "overloaded", "at capacity", "over capacity"]
    timeout_patterns: ["timeout", "timed out", "ETIMEDOUT"]
  plan_mutability:
    enabled: true
    annotation_format: "<!-- [BLOCKED: {reason}] -->"
    skip_blocked_phases: true
  status_file:
    enabled: true
    filename: ".implementation-ralph-status.local.md"
  completion_promise: "IMPLEMENTATION COMPLETE"
  learnings:
    enabled: true
    max_entries: 20
  pre_seed_defaults:
    quality_preset: "standard"
    autonomy_policy: "full_auto"
    external_models: false
```

## Cross-Iteration Learning

When a coordinator fails and then succeeds on retry, the orchestrator captures the
fail-succeed delta as a learning entry in `{FEATURE_DIR}/.implementation-learnings.local.md`.

**Mechanism:**
- `APPEND_LEARNING()` in `orchestrator-loop.md` writes entries on successful retries (both `failed` handler and crash recovery)
- Stage 1 reads the learnings file (if it exists) and includes the 10 most recent entries as "Operational Learnings" in the summary
- Entries are FIFO-capped at `ralph_loop.learnings.max_entries` (default: 20)
- Categories: `error` (current). Future: `build`, `test`, `config`, `dependency`, `pattern`
- The learnings file is excluded from auto-commit (`.implementation-learnings` in `auto_commit.exclude_patterns`)

**Config:**
- `ralph_loop.learnings.enabled` (default: `true`)
- `ralph_loop.learnings.max_entries` (default: 20)

## Files Involved

| File | Role |
|------|------|
| `commands/ralph-implement.md` | User-facing slash command entry point |
| `scripts/setup-ralph-implement.sh` | Precondition validation, budget calculation, prompt generation |
| `templates/ralph-implement-prompt.md` | Prompt template with variable substitution |
| `templates/ralph-blockers-template.local.md` | Blockers file format reference |
| `templates/ralph-learnings-template.local.md` | Learnings file format reference |
| `references/stage-1-setup.md` Section 1.0b | Ralph mode detection |
| `references/orchestrator-loop.md` | AskUserQuestion guard, stall detection |
| `config/implementation-config.yaml` `ralph_loop` | All configurable values |

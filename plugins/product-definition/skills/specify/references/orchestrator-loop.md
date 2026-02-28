# Orchestrator Dispatch Loop and Recovery

> Read this file at the start of orchestration. It governs how stages are dispatched,
> how the iteration loop works, and how the orchestrator recovers from failures.

---

## Dispatch Loop

```
READ state file -> determine current_stage and stage_status

IF state exists AND current_stage < 7 AND stage_status != "completed":
    RESUME from current_stage

OTHERWISE:
    START from Stage 1

FOR each stage in dispatch order [1, 2, 3, 4, 5, 6, 7]:
    IF stage already completed (check stage summaries):
        SKIP

    IF stage == 1:
        EXECUTE inline (read stage-1-setup.md, execute directly)
    ELSE:
        DISPATCH coordinator (see Coordinator Dispatch below)

    READ coordinator summary
    HANDLE summary status (see Summary Handling)

    IF stage == 3 OR stage == 4:
        HANDLE iteration loop (see Iteration Loop Logic)
```

---

## Coordinator Dispatch

For stages 2-7, dispatch a coordinator subagent using the per-stage dispatch profile.

### Stage Dispatch Profiles

| Stage | Shared Refs | Config YAML | Extra Refs |
|-------|-------------|-------------|------------|
| 2 (Spec Draft) | checkpoint-protocol, error-handling | Yes | cli-dispatch-patterns (if CLI available) |
| 3 (Checklist) | checkpoint-protocol, error-handling | Yes | — |
| 4 (Clarification) | checkpoint-protocol, error-handling | Yes | cli-dispatch-patterns (if CLI available) |
| 5 (Validation & Design) | checkpoint-protocol, error-handling | Yes | config-reference (CLI dispatch params) |
| 6 (Test Strategy) | checkpoint-protocol, error-handling | Yes | — |
| 7 (Completion) | checkpoint-protocol | No | — |

### Dispatch Template

```
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for the Feature Specify workflow.

## Your Stage
Read and execute: @$CLAUDE_PLUGIN_ROOT/skills/specify/references/{STAGE_FILE}

## Context
- Feature directory: specs/{FEATURE_DIR}
- Feature name: {FEATURE_NAME}
- CLI available: {CLI_AVAILABLE}
- Codex available: {CODEX_AVAILABLE}
- Gemini available: {GEMINI_AVAILABLE}
- OpenCode available: {OPENCODE_AVAILABLE}
- Sequential Thinking available: {ST_AVAILABLE}
- Figma MCP available: {FIGMA_MCP_AVAILABLE}
- Figma enabled: {FIGMA_ENABLED}
- Entry type: {ENTRY_TYPE}
- Iteration: {ITERATION_NUMBER}

## Shared References (load ONLY those listed for this stage)
{IF stage needs checkpoint-protocol:}
- Checkpoint protocol: @$CLAUDE_PLUGIN_ROOT/skills/specify/references/checkpoint-protocol.md
{IF stage needs error-handling:}
- Error handling: @$CLAUDE_PLUGIN_ROOT/skills/specify/references/error-handling.md
{IF stage needs config YAML:}
- Config: @$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml
{IF stage has extra refs:}
- {extra_ref}: @$CLAUDE_PLUGIN_ROOT/skills/specify/references/{extra_ref}

## Prior Stage Summaries
{CONTENTS OF specs/{FEATURE_DIR}/.stage-summaries/stage-*-summary.md}

## State File (frontmatter only)
{YAML FRONTMATTER OF specs/{FEATURE_DIR}/.specify-state.local.md}

## CRITICAL RULES
- You MUST NOT interact with users directly. If you need user input,
  write your summary with status: needs-user-input and describe what
  you need in flags.block_reason and flags.question_context.
- You MUST write a summary file at specs/{FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md
  with YAML frontmatter following the summary contract in SKILL.md.
- You MUST update the state file after completing your work.
- You MUST run self-verification checks listed at the end of your stage file
  BEFORE writing your summary.
""")
```

### ENTRY_TYPE Variable

Set `ENTRY_TYPE` based on orchestrator state:
- `"re_entry_after_user_input"` — when a previous `needs-user-input` was resolved
- `"first_entry"` — all other cases

### Variable Defaults

Every dispatch variable MUST have a defined fallback:

| Variable | Default | Rationale |
|----------|---------|-----------|
| `ENTRY_TYPE` | `"first_entry"` | Safe default for first invocation |
| `CLI_AVAILABLE` | `false` | Assume unavailable; prevents failed CLI dispatch calls |
| `CODEX_AVAILABLE` | `false` | Assume unavailable; detected in Stage 1 |
| `GEMINI_AVAILABLE` | `false` | Assume unavailable; detected in Stage 1 |
| `OPENCODE_AVAILABLE` | `false` | Assume unavailable; detected in Stage 1 |
| `ST_AVAILABLE` | `false` | Assume unavailable; coordinators use internal reasoning |
| `FIGMA_MCP_AVAILABLE` | `false` | Assume unavailable; Figma is always optional |
| `FIGMA_ENABLED` | `false` | User must explicitly enable |
| `ITERATION_NUMBER` | `1` | First iteration default |
| `RTM_ENABLED` | `false` | Assume disabled; set to true in Stage 1 if user confirms inventory |
| `FEATURE_DIR` | (none) | MUST be set by Stage 1 — abort if missing |
| `FEATURE_NAME` | (none) | MUST be set by Stage 1 — abort if missing |

**Precedence:** State file values override defaults. Apply defaults only when variable has no value in state AND was not set by a prior stage.

---

## Coordinator Return Format Rules

Coordinator summaries are the primary context passed between stages. Keep them compact.

### Size Constraints

| Field | Max Length | Content |
|-------|-----------|---------|
| `summary` (YAML) | 500 chars | Status + key metrics + outcome. No analysis or rationale. |
| Context for Next Stage (markdown body) | 1000 chars | Only what the next stage needs to start. No prior-stage recaps. |

### Anti-Pattern

```
# BAD — 4000 chars of analysis in summary
summary: "Drafted spec with 12 user stories covering meal planning, recipe management,
  shopping lists, and nutritional tracking. Self-critique revealed gaps in offline
  sync handling (scored 15/20). MPA Challenge found 3 issues: ..."

# GOOD — 200 chars of actionable status
summary: "Spec drafted: 12 user stories, self-critique 15/20. MPA-Challenge GREEN (3 findings, all addressed)."
```

### Rule

Detailed analysis belongs in **artifact files** (spec.md, test-plan.md, design-supplement.md), NOT in coordinator summaries. The orchestrator reads summaries for routing decisions, not for content review.

---

## Summary Schema Validation

After each coordinator returns, validate its summary:

```
READ summary file at specs/{FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md

VALIDATE required fields in YAML frontmatter:
  - stage: non-empty string
  - stage_number: integer 1-7
  - status: one of [completed, needs-user-input, failed]
  - checkpoint: non-empty string
  - artifacts_written: array
  - summary: non-empty string
  - flags: object

IF any required field is missing:
    IF status field is present and valid:
        PROCEED with available data (best-effort)
    ELSE:
        TREAT as crash (see Crash Recovery)
```

---

## Summary Handling

### `status: completed`
Advance to next stage in sequence.

### `status: needs-user-input`
Check `flags.pause_type`:

**If `pause_type: file_based`:**
- Read `flags.clarification_file` for the path to the question file
- Notify user with a single `AskUserQuestion` call:
  ```
  question: "Clarification questions have been written to {clarification_file}. Edit the file with your answers, then select 'Continue' to resume."
  header: "Questions"
  options:
    - label: "Continue (Recommended)"
      description: "I've edited the clarification file with my answers"
    - label: "Accept all recommendations"
      description: "Use BA recommendations for all questions without editing"
    - label: "Abort"
      description: "Stop workflow"
  ```
- On "Continue": Re-dispatch the same stage with `ENTRY_TYPE = "re_entry_after_user_input"`
- On "Accept all recommendations": Re-dispatch with `ENTRY_TYPE = "re_entry_after_user_input"` (blank answers default to recommendations per protocol)
- On "Abort": Terminate workflow

**If `pause_type: interactive`:**
- Read `flags.question_context` for question details
- Use `AskUserQuestion` to relay the question to the user
- Map user's response via `flags.next_action_map` if present
- Re-dispatch the same stage with `ENTRY_TYPE = "re_entry_after_user_input"` and user's answer in context
- OR follow `next_action_map` to determine next stage (e.g., `"loop_clarify"` -> re-dispatch Stage 3)

### `status: failed`
- Log the failure
- Attempt crash recovery (see `recovery-migration.md`)
- If unrecoverable, notify user and terminate

---

## Quality Gate Protocol

### After Stage 2 (Spec Drafted)

```
READ flags.self_critique_score from Stage 2 summary
READ flags.gate_1_score and flags.gate_2_score

QUALITY CHECKS:
1. Self-critique score >= 16/20 (config threshold)
2. Gate 1 and Gate 2 both GREEN (score 4/4)

IF issues found:
    LOG quality_warnings in state file
    NOTIFY user: "Quality note: {issue}. Spec drafted, proceeding."
    (Do NOT block)
```

### After Stage 4 (Clarification Complete) — ITERATION CHECK

```
READ Stage 3 summary -> flags.coverage_pct

IF coverage_pct >= 85% (config -> thresholds.checklist.green):
    PROCEED to RTM quality check (below), then Stage 5

ELSE:
    IF this is iteration > 1 AND coverage improvement < 5% since last iteration:
        NOTIFY user: "Coverage stalled at {PCT}%. Options:"
        Ask via AskUserQuestion: "Force proceed" or "Continue clarifying"
    ELSE:
        NOTIFY user: "Coverage at {PCT}% (need 85%). Re-running checklist validation."
        RE-DISPATCH Stage 3 (new iteration)
        THEN RE-DISPATCH Stage 4 if Stage 3 still has gaps

RTM QUALITY CHECK (after Stage 4 if proceeding to Stage 5):
IF RTM_ENABLED AND Stage 4 summary flags.rtm.remaining_unmapped > 0:
    NOTIFY user (non-blocking): "RTM: {N} requirements still UNMAPPED.
    Disposition was offered in Stage 4 but {N} remain unresolved.
    Proceeding — these will be flagged in the completion report."
    LOG rtm_warning in state file

NOTE: This check is intentionally NON-BLOCKING (notification only, does not halt).
The disposition gate in Stage 4 (Step 4.0a) already gave the user a chance to
resolve every UNMAPPED requirement. If any remain UNMAPPED here, it means the user
chose not to answer those disposition questions — this is their conscious choice.
Blocking again would create an infinite loop. The remaining UNMAPPED entries are
reported in the Stage 7 completion report for future resolution.
```

### After Stage 5 (Design Artifacts)

```
READ flags.design_brief_exists and flags.design_supplement_exists from Stage 5 summary

QUALITY CHECKS:
1. design-brief.md exists (MANDATORY)
2. design-supplement.md exists (MANDATORY)

IF either missing:
    CRITICAL ERROR — re-dispatch Stage 5
    (These are MANDATORY outputs — NEVER proceed without them)
```

---

## Iteration Loop Logic

The iteration loop is between Stages 3 and 4. The orchestrator controls it.

### Flow

```
DISPATCH Stage 3 (Checklist & Validation)
READ Stage 3 summary -> coverage_pct, next_action

IF next_action == "proceed" (coverage >= 85%):
    SKIP Stage 4, advance to Stage 5

IF next_action == "loop_clarify":
    DISPATCH Stage 4 (Clarification)
    READ Stage 4 summary

    RE-DISPATCH Stage 3 (re-validate after clarifications)
    READ Stage 3 summary -> new coverage_pct

    IF new coverage_pct >= 85%:
        ADVANCE to Stage 5
    ELSE:
        LOOP again (Stage 4 → Stage 3) until coverage met or user forces proceed
```

### Iteration Counter

Track in state file:
```yaml
iteration_count: {N}
iterations:
  - iteration: 1
    stage_3_coverage: 62%
    stage_4_questions: 8
  - iteration: 2
    stage_3_coverage: 78%
    stage_4_questions: 4
  - iteration: 3
    stage_3_coverage: 91%
    stage_4_questions: 0
```

### Stall Detection

If coverage improvement < 5% between iterations:
```
current_coverage - previous_coverage < 5%:
    Ask user: "Force proceed" or "Continue"
```

---

## User Pause Handling

### Interactive Pauses

All user pauses in this workflow are interactive (no exit_cli pauses like refinement).
The orchestrator stays running and mediates via AskUserQuestion.

Pause points:
- Stage 2: Gate RED/YELLOW, MPA-Challenge RED
- Stage 4: Clarification batches (via clarification protocol)
- Stage 5: CLI evaluation REJECTED after retries, insufficient CLI responses
- Stage 6: Test coverage gaps

### Resume from Needs-User-Input

```
ON RE-ENTRY after user answers:
    READ user's answer
    MAP via next_action_map if available
    RE-DISPATCH stage with ENTRY_TYPE = "re_entry_after_user_input"
    INCLUDE user's answer in coordinator context
```

---

## Crash Recovery & State Migration

**Loaded on-demand.** Full procedures are in a separate reference file.

**Load when:** A coordinator produces no summary file (crash) OR state file has `schema_version` < 5 (migration needed).

**Reference:** `@$CLAUDE_PLUGIN_ROOT/skills/specify/references/recovery-migration.md`

### Quick Summary

**Crash Recovery:** If summary file missing for stage N, check for artifacts. If found, reconstruct minimal summary. If not, ask user to retry or skip.

**State Migration:** Chained migrations: v2→v3 (phase→stage), v3→v4 (file-based clarification), v4→v5 (RTM tracking). Each migration is additive — new fields get null/empty defaults.

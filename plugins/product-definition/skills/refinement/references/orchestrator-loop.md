# Orchestrator Dispatch Loop and Recovery

> Read this file at the start of orchestration. It governs how stages are dispatched,
> how the iteration loop works, and how the orchestrator recovers from failures.

---

## Dispatch Loop

```
READ state file -> determine current_stage and waiting_for_user

IF waiting_for_user == true:
    ROUTE to the stage that set the pause (from state.pause_stage)
    The coordinator will detect user has returned and check for input

IF state.current_stage exists AND status != "completed":
    RESUME from state.current_stage

OTHERWISE:
    START from Stage 1

FOR each stage in dispatch order [1, 2, 3, 4, 5, 6]:
    IF stage already completed in this round (check stage summaries):
        SKIP

    IF stage == 1:
        EXECUTE inline (read stage-1-setup.md, execute directly)
    ELSE:
        DISPATCH coordinator (see Coordinator Dispatch below)

    READ coordinator summary
    HANDLE summary status (see Summary Handling)
```

---

## Coordinator Dispatch

For stages 2-6, dispatch a coordinator subagent using the **per-stage dispatch profile** from config (`token_budgets.stage_dispatch_profiles`). Each stage loads ONLY the shared references it needs.

### Stage Dispatch Profiles

| Stage | Shared Refs | Config YAML | Extra Refs |
|-------|-------------|-------------|------------|
| 2 (Research) | checkpoint-protocol, error-handling | No | — |
| 3 (Analysis) | checkpoint-protocol, error-handling | Yes | option-generation-reference |
| 4 (Response) | checkpoint-protocol, error-handling | Yes | — |
| 5 (Validation) | checkpoint-protocol, error-handling | Yes | — |
| 6 (Completion) | checkpoint-protocol | No | — |

### Dispatch Template

```
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for the Requirements Refinement workflow.

## Your Stage
Read and execute: @$CLAUDE_PLUGIN_ROOT/skills/refinement/references/{STAGE_FILE}

## Context
- Feature directory: requirements/
- Analysis mode: {ANALYSIS_MODE}
- PRD mode: {PRD_MODE}
- Current round: {ROUND_NUMBER}
- PAL available: {PAL_AVAILABLE}
- Sequential Thinking available: {ST_AVAILABLE}
- Entry type: {ENTRY_TYPE}  # "first_entry" or "re_entry_after_user_input"

{IF REFLECTION_CONTEXT is non-empty (Stage 3 re-dispatch after RED validation):}
## Reflection from Previous Round
{REFLECTION_CONTEXT}

## Shared References (load ONLY those listed for this stage)
{IF stage needs checkpoint-protocol:}
- Checkpoint protocol: @$CLAUDE_PLUGIN_ROOT/skills/refinement/references/checkpoint-protocol.md
{IF stage needs error-handling:}
- Error handling: @$CLAUDE_PLUGIN_ROOT/skills/refinement/references/error-handling.md
{IF stage needs config YAML:}
- Config: @$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml
{IF stage has extra refs:}
- {extra_ref}: @$CLAUDE_PLUGIN_ROOT/skills/refinement/references/{extra_ref}

## Prior Stage Summaries
{IF current_round <= compaction.rounds_before_compaction:}
  {CONTENTS OF requirements/.stage-summaries/stage-*-summary.md}
{ELSE:}
  {CONTENTS OF requirements/.stage-summaries/rounds-digest.md}
  {CONTENTS OF current round stage summaries only}

## State File (frontmatter only — omit workflow log for context efficiency)
{YAML FRONTMATTER OF requirements/.requirements-state.local.md}

## CRITICAL RULES
- You MUST NOT interact with users directly. If you need user input,
  write your summary with status: needs-user-input and describe what
  you need in flags.block_reason.
- You MUST write a summary file at requirements/.stage-summaries/stage-{N}-summary.md
  with YAML frontmatter following the summary contract in SKILL.md.
- You MUST update the state file after completing your work.
- You MUST run self-verification checks listed at the end of your stage file
  BEFORE writing your summary.
""")
```

### ENTRY_TYPE Variable

Set `ENTRY_TYPE` based on orchestrator state:
- `"re_entry_after_user_input"` — when `waiting_for_user` was true and user has returned
- `"first_entry"` — all other cases

This eliminates ambiguity for Stage 4 (present questions vs parse answers) and Stage 2 (research agenda vs synthesis).

### Variable Defaults

Every dispatch variable MUST have a defined fallback to prevent malformed coordinator prompts:

| Variable | Default | Rationale |
|----------|---------|-----------|
| `ENTRY_TYPE` | `"first_entry"` | Guards against orchestrator bugs; safe default |
| `PAL_AVAILABLE` | `false` | Assume unavailable if Stage 1 didn't detect; prevents PAL calls that would fail |
| `ST_AVAILABLE` | `false` | Assume unavailable; coordinators use internal reasoning as fallback |
| `REFLECTION_CONTEXT` | `""` (empty) | First round or non-RED re-entry; Stage 3 checks presence before using |
| `ROUND_NUMBER` | `1` | First invocation default |
| `ANALYSIS_MODE` | `"standard"` | Safest mode — no MCP dependency |
| `PRD_MODE` | `"NEW"` | Default to new PRD creation |

**Precedence rule:** State file values always override defaults. Apply defaults only when the variable has no value in state AND was not explicitly set by a prior stage.

**Rule:** If a variable is not set by the orchestrator at dispatch time, substitute the default from this table. Never pass `null` or empty strings for required variables.

---

## Summary Schema Validation

After each coordinator returns, validate its summary before acting:

```
READ summary file at requirements/.stage-summaries/stage-{N}-summary.md

VALIDATE required fields exist in YAML frontmatter:
  - stage: non-empty string
  - stage_number: integer 1-6
  - status: one of [completed, needs-user-input, failed]
  - checkpoint: non-empty string
  - artifacts_written: array
  - summary: non-empty string
  - flags: object

IF any required field is missing or malformed:
    LOG warning: "Stage {N} summary has missing/malformed fields: {list}"
    IF status field is present and valid:
        PROCEED with available data (best-effort)
    ELSE:
        TREAT as crash (see Crash Recovery below)
```

---

## Summary Handling

After each coordinator returns, read its validated summary and act:

### `status: completed`
Advance to next stage in sequence.

### `status: needs-user-input`
Check `flags.pause_type`:

**If `pause_type: exit_cli`:**
- Update state: `waiting_for_user: true`, `pause_stage: {N}`
- Display coordinator's `flags.block_reason` to user
- Display instructions for resuming
- **TERMINATE** the session (user works offline)

**If `pause_type: interactive`:**
- Read `flags.block_reason` for the question context
- Use `AskUserQuestion` to relay the question to the user
- Pass user's response back to coordinator by re-dispatching the same stage
  with the user's answer appended to context

### `status: failed`
- Log the failure
- Attempt crash recovery (see Crash Recovery below)
- If unrecoverable, notify user and terminate

---

## Quality Gate Protocol

After stages that produce user-facing artifacts, the orchestrator performs a lightweight quality check
on the coordinator's output. This supplements the coordinator's internal self-verification.

### After Stage 3 (Questions Generated)

```
READ requirements/working/QUESTIONS-{NNN}.md

QUALITY CHECKS:
1. Section coverage: every required PRD section (from config -> prd.sections where required=true)
   has at least 1 question targeting it
2. Option distinctness: spot-check 3 random questions — options should represent
   genuinely different approaches, not minor variations of the same idea
3. Priority balance: at least 1 CRITICAL question exists; not all questions are MEDIUM

IF issues found:
    LOG quality_warnings in state file
    ADD flags.quality_warnings to Stage 3 summary (append, don't overwrite)
    NOTIFY user: "Quality note: {issue}. Questions are still usable."
    (Do NOT block — proceed to Stage 4)
```

### After Stage 5 (PRD Generated)

```
IF flags.validation_decision in ["READY", "CONDITIONAL"]:
    READ requirements/PRD.md

    QUALITY CHECKS:
    1. Section completeness: all required sections are present and non-empty
       EXCEPTION: "Executive Summary" is a synthesis section generated last —
       exclude it from this check (its absence is not a quality issue)
    2. Technical filter: quick grep for top 5 forbidden keywords
       (API, backend, database, architecture, implementation)
    3. Decision traceability: requirements/decision-log.md exists and is non-empty

    IF issues found:
        LOG quality_warnings in state file
        NOTIFY user before proceeding to Stage 6:
            "Quality note: {issues}. Review PRD.md before finalizing."
```

**Design rationale:** These checks are non-blocking to avoid halting the workflow for minor issues.
The user is notified and can address issues after completion. Critical issues (RED validation, missing PRD)
are already caught by Stage 5's validation logic.

---

## Iteration Loop Logic

The iteration loop is between Stages 3, 4, and 5. The orchestrator controls it.

### After Stage 4 Summary

Read `flags.next_action` from Stage 4 summary:

```
IF next_action == "loop_questions":
    INCREMENT state.current_round
    Ask user for analysis mode for new round (via AskUserQuestion)
    DISPATCH Stage 3 (new round)

IF next_action == "loop_research":
    DISPATCH Stage 2 (focused on gap areas)

IF next_action == "proceed":
    DISPATCH Stage 5
```

### After Stage 5 Summary

If Stage 5 validation result is RED (score < config -> `scoring.prd_readiness.conditional`):

```
IF flags.validation_decision == "NOT_READY":
    INCREMENT state.current_round

    ## REFLEXION STEP — generate reflection before re-dispatching Stage 3
    READ Stage 4 summary (gaps found, completion rate)
    READ Stage 5 summary (validation score, weak dimensions)
    READ prior round's Stage 3 summary (questions count, analysis mode)

    GENERATE REFLECTION_CONTEXT:
    """
    ## Round {previous_round} Reflection

    ### What We Tried
    - Analysis mode: {previous_analysis_mode}
    - Questions generated: {previous_questions_count}
    - Questions answered: {completion_rate}%

    ### Why It Wasn't Enough
    - Validation score: {Stage5.flags.validation_score}/20 (needed >= {conditional_threshold})
    - Weakest dimensions: {Stage5.flags.weak_dimensions}
    - Per-dimension scores: {Stage5.flags.dimension_scores}
    - Gaps identified: {Stage4.flags.gap_descriptions}
    - Persistent gaps (appeared in previous rounds too): {cross-round gap intersection}

    ### What To Do Differently
    - Focus question generation on these weak dimensions: {Stage5.flags.weak_dimensions}
    - These sub-problems remain unresolved: {unresolved from decomposition}
    - Avoid re-asking well-answered areas: {Stage5.flags.strong_dimensions}
    - Consider deeper options for: {areas where user chose "Other" or gave vague answers}
    """

    PERSIST REFLECTION_CONTEXT to: requirements/.stage-summaries/reflection-round-{N}.md
    (Enables crash recovery — if orchestrator crashes after generating reflection but
     before dispatching Stage 3, the reflection is recovered from this file on re-invocation)

    Notify user: "PRD not ready. Score: {score}/20. Generating more questions with reflection on gaps."
    Ask user for analysis mode for new round (via AskUserQuestion)
    DISPATCH Stage 3 (new round, with REFLECTION_CONTEXT in coordinator prompt)

IF flags.validation_decision in ["READY", "CONDITIONAL"]:
    PRD was generated successfully
    DISPATCH Stage 6
```

### Round Counter

Track in state file:
```yaml
current_round: {N}
rounds:
  - round_number: 1
    analysis_mode: "complete"
    questions_count: 15
    stage_3_completed: true
    stage_4_completed: true
  - round_number: 2
    analysis_mode: "standard"
    ...
```

### Prior Round Compaction

From config: `token_budgets.compaction.*`

```
IF current_round > compaction.rounds_before_compaction (default: 3):
    GENERATE rounds digest:
        READ all stage summaries from rounds 1 to (current_round - 1)
        SYNTHESIZE into structured digest:
            - Per-round: round_number, analysis_mode, questions_count, key_decisions
            - Cumulative: total_questions, total_gaps_found, modes_used
            - Key decisions: list of user_decisions across all prior rounds
        WRITE to: requirements/.stage-summaries/rounds-digest.md
        LIMIT: config -> token_budgets.compaction.digest_max_lines (default: 100)

    In coordinator dispatch, use digest + current round summaries
    instead of all individual stage summaries
```

**Why:** Without compaction, accumulated summaries grow linearly (~150 lines per round). By round 5, prior summaries alone consume ~750 lines of coordinator context. Compaction keeps this under 100 lines regardless of round count.

### Circuit Breaker

From config: `limits.max_rounds: 100`

```
IF current_round > max_rounds:
    Notify user: "Circuit breaker: {max_rounds} rounds reached."
    Ask: "Force PRD generation with current information?" or "Continue?"
```

---

## User Pause Handling

Two EXIT pause points exist in this workflow:

### Research Pause (Stage 2)
- User exits to conduct offline research
- State: `waiting_for_user: true`, `pause_stage: 2`
- On re-invocation: orchestrator routes to Stage 2
- Stage 2 coordinator checks for research reports in `requirements/research/reports/`

### Question Response Pause (Stage 4)
- User exits to fill in QUESTIONS-{NNN}.md file
- State: `waiting_for_user: true`, `pause_stage: 4`
- On re-invocation: orchestrator routes to Stage 4
- Stage 4 coordinator checks for filled answers in the QUESTIONS file

### Resume Routing

```
ON REINVOCATION:
    READ state file
    IF waiting_for_user == true:
        stage = state.pause_stage
        CLEAR waiting_for_user
        DISPATCH stage coordinator (it will detect the user's input)
    ELSE IF current_stage < 6 AND phase_status != "completed":
        # Check for persisted reflection context (crash recovery for RED loop)
        IF current_stage == 3 AND file exists requirements/.stage-summaries/reflection-round-{current_round}.md:
            LOAD REFLECTION_CONTEXT from that file
            DISPATCH Stage 3 with REFLECTION_CONTEXT
        ELSE:
            RESUME from current_stage
    ELSE:
        START fresh (Stage 1)
```

---

## Crash Recovery

If a coordinator produces no summary file (crash, timeout, context exhaustion):

```
IF summary file missing for stage N:
    CHECK for artifacts that stage N should have written
    (from artifacts_written in the stage reference frontmatter)

    IF artifacts found:
        RECONSTRUCT minimal summary:
        ---
        stage: "{stage_name}"
        stage_number: {N}
        status: completed
        checkpoint: "{CHECKPOINT}"
        artifacts_written: [{found artifacts}]
        summary: "Reconstructed from artifacts (coordinator crashed)"
        flags:
          recovered: true
        ---

    IF no artifacts found:
        MARK stage as failed
        Notify user: "Stage {N} failed. No output produced."
        Ask: "Retry stage?" or "Skip and continue?"
```

---

## State Migration (v1 to v2)

When resuming a workflow started under the command-era (schema_version: 1),
migrate to skill-era (schema_version: 2):

### Phase-to-Stage Mapping

```
v1 current_phase        -> v2 current_stage
─────────────────────────────────────────────
INITIALIZATION          -> 1
WORKSPACE_INIT          -> 1
ANALYSIS_MODE_SELECTION -> 1
RESEARCH_DISCOVERY      -> 2
RESEARCH_ANALYSIS       -> 2
DEEP_ANALYSIS           -> 3
QUESTION_GENERATION     -> 3
USER_RESPONSE           -> 4
RESPONSE_ANALYSIS       -> 4
VALIDATION              -> 5
PRD_GENERATION          -> 5
COMPLETE                -> 6
```

### Migration Procedure

```
IF state.schema_version == 1 OR state.schema_version is missing:
    MAP current_phase to current_stage (table above)
    SET schema_version: 2
    SET orchestrator.delegation_model: "lean_orchestrator"
    PRESERVE all existing fields (user_decisions, rounds, phases)
    ADD current_stage field
    WRITE updated state file
```

All existing `user_decisions` and round data are preserved unchanged.
